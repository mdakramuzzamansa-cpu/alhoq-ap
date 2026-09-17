import Foundation

/// ⚠️ backend gap (পরিচিত প্যাটার্ন): `PageController@show` এবং `ContactController@store`
/// দুটোই Blade/redirect-ভিত্তিক (JSON না) — assumed endpoint।
protocol StaticPageAPIProtocol {
    func page(slug: String) async throws -> StaticPage
    func sendContactMessage(_ request: ContactMessageRequest) async throws
}

final class StaticPageAPI: StaticPageAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func page(slug: String) async throws -> StaticPage {
        let envelope: APIEnvelope<StaticPage> = try await client.request("pages/\(slug)", authenticated: false)
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func sendContactMessage(_ request: ContactMessageRequest) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "contact", method: .post, body: request, authenticated: false
        )
    }
}
