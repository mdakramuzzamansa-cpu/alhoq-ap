import Foundation

/// ⚠️ backend gap (Checkout/Push/Home-feed-এর মতোই): `AnonymousController@index` এখনো
/// Blade view রিটার্ন করে (paginated, JSON না)। নিচের `feed()` তাই assumed নতুন endpoint
/// (`GET /anonymous/posts`) ধরে লেখা — backend-এ একই query (with identity/likes/comments+replies,
/// withCount comments, paginate 15) JSON আকারে এক্সপোজ করতে হবে।
protocol AnonymousAPIProtocol {
    func myIdentity() async throws -> AnonIdentity
    func feed(page: Int) async throws -> APIEnvelope<[AnonPost]>
    func createPost(_ request: CreateAnonPostRequest) async throws -> Int
    func deletePost(id: Int) async throws
    func storeComment(postId: Int, body: String, parentId: Int?) async throws -> AnonComment
    func deleteComment(id: Int) async throws
    func togglePostLike(postId: Int) async throws -> ToggleLikeResponse
    func toggleCommentLike(commentId: Int) async throws -> ToggleLikeResponse
    func regenerateIdentity() async throws -> AnonIdentity
}

final class AnonymousAPI: AnonymousAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func myIdentity() async throws -> AnonIdentity {
        let envelope: APIEnvelope<AnonIdentity> = try await client.request("anonymous/identity")
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func feed(page: Int) async throws -> APIEnvelope<[AnonPost]> {
        try await client.request("anonymous/posts", query: ["page": String(page)])
    }

    func createPost(_ request: CreateAnonPostRequest) async throws -> Int {
        struct Response: Decodable { let postId: Int
            enum CodingKeys: String, CodingKey { case postId = "post_id" }
        }
        let envelope: APIEnvelope<Response> = try await client.request(
            "anonymous/posts", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data.postId
    }

    func deletePost(id: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("anonymous/posts/\(id)", method: .delete)
    }

    func storeComment(postId: Int, body: String, parentId: Int?) async throws -> AnonComment {
        struct Body: Encodable { let body: String; let parentId: Int?
            enum CodingKeys: String, CodingKey { case body; case parentId = "parent_id" }
        }
        let envelope: APIEnvelope<AnonComment> = try await client.request(
            "anonymous/posts/\(postId)/comments", method: .post, body: Body(body: body, parentId: parentId)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func deleteComment(id: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("anonymous/comments/\(id)", method: .delete)
    }

    func togglePostLike(postId: Int) async throws -> ToggleLikeResponse {
        let envelope: APIEnvelope<ToggleLikeResponse> = try await client.request(
            "anonymous/posts/\(postId)/like", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func toggleCommentLike(commentId: Int) async throws -> ToggleLikeResponse {
        let envelope: APIEnvelope<ToggleLikeResponse> = try await client.request(
            "anonymous/comments/\(commentId)/like", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func regenerateIdentity() async throws -> AnonIdentity {
        let envelope: APIEnvelope<AnonIdentity> = try await client.request(
            "anonymous/identity/regenerate", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }
}
