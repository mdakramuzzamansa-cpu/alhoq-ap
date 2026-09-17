import Foundation

protocol GlobalSearchAPIProtocol {
    /// zip: real JSON endpoint, no assumption needed
    func usernameSuggestions(query: String) async throws -> [UsernameSuggestion]
    /// ⚠️ ASSUMPTION: index() Blade-only — assumed JSON endpoint, একই query params (q, type, page)
    func search(query: String, type: GlobalSearchType, page: Int) async throws -> GlobalSearchResponse
}

final class GlobalSearchAPI: GlobalSearchAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    /// zip: `return response()->json($matches->map(...))` — সরাসরি raw array, স্ট্যান্ডার্ড
    /// APIEnvelope wrapper **না** (এই একটা endpoint-ই ব্যতিক্রম, অনুমান না, সরাসরি কোডে দেখা)
    func usernameSuggestions(query: String) async throws -> [UsernameSuggestion] {
        guard !query.isEmpty else { return [] }
        var components = URLComponents(
            url: APIConfig.baseURL.appendingPathComponent("search/username-suggest"), resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }
        return (try? JSONDecoder.alhoq.decode([UsernameSuggestion].self, from: data)) ?? []
    }

    func search(query: String, type: GlobalSearchType, page: Int) async throws -> GlobalSearchResponse {
        let envelope: APIEnvelope<GlobalSearchResponse> = try await client.request(
            "search", query: ["q": query, "type": type.rawValue, "page": String(page)], authenticated: false
        )
        guard let data = envelope.data else {
            return GlobalSearchResponse(q: query, type: type.rawValue, users: [], ads: [], videos: [], usernameUser: nil, usernamePosts: nil)
        }
        return data
    }
}
