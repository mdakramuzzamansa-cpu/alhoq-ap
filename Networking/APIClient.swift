import Foundation

// MARK: - Base configuration
// ⚠️ ASSUMPTION: baseURL এবং version prefix Android build অনুযায়ী বদলাতে হতে পারে।
enum APIConfig {
    static let baseURL = URL(string: "https://alhoq.com/api/v1")!
    /// শুধু শেয়ার লিংক বানানোর জন্য — API prefix ছাড়া আসল web domain
    static let webBaseURL = URL(string: "https://alhoq.com")!
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// একটামাত্র জায়গা থেকে সব API কল যায় — token attach, error mapping, envelope decode সব এখানে হয়।
/// প্রতিটা মডিউলের Repository (Auth, Listing, Chat, ...) এই client-কে reuse করবে,
/// যাতে প্রতিটা Phase-এ networking কোড নতুন করে লিখতে না হয়।
final class APIClient {
    static let shared = APIClient()
    private let session: URLSession
    private let tokenStore: TokenStore

    init(session: URLSession = .shared, tokenStore: TokenStore = KeychainTokenStore.shared) {
        self.session = session
        self.tokenStore = tokenStore
    }

    func request<Response: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        query: [String: String]? = nil,
        authenticated: Bool = true
    ) async throws -> APIEnvelope<Response> {

        var components = URLComponents(url: APIConfig.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if let query {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated, let token = tokenStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.alhoq.encode(AnyEncodable(body))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

        switch http.statusCode {
        case 200...299:
            break
        case 401:
            tokenStore.clear()
            throw APIError.sessionExpired
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 422:
            let decoded = try? JSONDecoder.alhoq.decode(ValidationErrorBody.self, from: data)
            throw APIError.validation(decoded?.errors ?? [:])
        case 500...599:
            let decoded = try? JSONDecoder.alhoq.decode(GenericMessageBody.self, from: data)
            throw APIError.server(decoded?.message ?? "সার্ভার সমস্যা")
        default:
            throw APIError.unknown
        }

        do {
            return try JSONDecoder.alhoq.decode(APIEnvelope<Response>.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}

private struct ValidationErrorBody: Decodable {
    let message: String?
    let errors: [String: [String]]?
}

private struct GenericMessageBody: Decodable {
    let message: String?
}

// MARK: - Encoding helpers
private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { self.encodeClosure = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeClosure(encoder) }
}

extension JSONEncoder {
    static let alhoq: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}

extension JSONDecoder {
    static let alhoq: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
