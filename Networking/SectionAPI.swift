import Foundation

/// ⚠️ backend gap: `SectionController@show` Blade view রিটার্ন করে। assumed JSON endpoint —
/// query params হুবহু web-এর মতো (search, page), শুধু response JSON আকারে চাওয়া হচ্ছে।
protocol SectionAPIProtocol {
    func browse(section: AppSection, search: String, page: Int) async throws -> SectionBrowseResponse
}

final class SectionAPI: SectionAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func browse(section: AppSection, search: String, page: Int) async throws -> SectionBrowseResponse {
        var query = ["page": String(page)]
        if !search.isEmpty { query["search"] = search }
        let envelope: APIEnvelope<SectionBrowseResponse> = try await client.request(
            "sections/\(section.rawValue)", query: query, authenticated: false
        )
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }
}

/// ⚠️ backend gap: root `PostController@show` Blade permalink page রিটার্ন করে —
/// Share বাটন এই URL-এ পয়েন্ট করে (EngagementController-এর share() count বাড়ানোর পর)
protocol PostDetailAPIProtocol {
    func post(id: Int) async throws -> FeedPost
}

final class PostDetailAPI: PostDetailAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func post(id: Int) async throws -> FeedPost {
        let envelope: APIEnvelope<FeedPost> = try await client.request("posts/\(id)", authenticated: false)
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }
}
