import Foundation

/// ⚠️ গুরুত্বপূর্ণ ব্যাকএন্ড গ্যাপ (Checkout/Push-এর মতোই): `HomeController@index` এখনো
/// Blade view রিটার্ন করে (JSON API নেই)। এই ফাইলের `homeFeed()` তাই একটা assumed নতুন
/// endpoint (`GET /home-feed`) ধরে নিয়ে লেখা হয়েছে যেটা backend-এ বানাতে হবে —
/// featuredListings + combinedFeed (listing+post, created_at দিয়ে sort করা) + videoFeed +
/// categories, ঠিক HomeController-এর মতোই assemble করে JSON-এ পাঠাবে।
protocol FeedAPIProtocol {
    func homeFeed() async throws -> HomeFeedResponse
    func createPost(_ request: CreatePostRequest) async throws -> Int?   // ফেরত: post_id (combined feed-এ থাকলে)
    func deletePost(id: Int) async throws
}

final class FeedAPI: FeedAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func homeFeed() async throws -> HomeFeedResponse {
        let envelope: APIEnvelope<HomeFeedResponse> = try await client.request("home-feed", authenticated: false)
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func createPost(_ request: CreatePostRequest) async throws -> Int? {
        struct Response: Decodable { let postId: Int?
            enum CodingKeys: String, CodingKey { case postId = "post_id" }
        }
        let envelope: APIEnvelope<Response> = try await client.request("posts", method: .post, body: request)
        return envelope.data?.postId
    }

    func deletePost(id: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("posts/\(id)", method: .delete)
    }
}

/// zip: EngagementController — একই endpoint post+listing দুটোতেই কাজ করে, body-তে type+id পাঠানো হয়
protocol EngagementAPIProtocol {
    func toggleLike(type: EngagementContentType, id: Int) async throws -> ToggleLikeResponse
    func comments(type: EngagementContentType, id: Int) async throws -> [FeedComment]
    func storeComment(type: EngagementContentType, id: Int, body: String, parentId: Int?) async throws -> StoreCommentResponse
    func deleteComment(id: Int) async throws -> DestroyCommentResponse
    func share(type: EngagementContentType, id: Int) async throws -> Int
}

final class EngagementAPI: EngagementAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func toggleLike(type: EngagementContentType, id: Int) async throws -> ToggleLikeResponse {
        struct Body: Encodable { let type: String; let id: Int }
        let envelope: APIEnvelope<ToggleLikeResponse> = try await client.request(
            "engagement/like", method: .post, body: Body(type: type.rawValue, id: id)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func comments(type: EngagementContentType, id: Int) async throws -> [FeedComment] {
        let envelope: APIEnvelope<CommentsListResponse> = try await client.request(
            "engagement/comments", query: ["type": type.rawValue, "id": String(id)]
        )
        return envelope.data?.comments ?? []
    }

    func storeComment(type: EngagementContentType, id: Int, body: String, parentId: Int?) async throws -> StoreCommentResponse {
        struct Body: Encodable { let type: String; let id: Int; let body: String; let parentId: Int?
            enum CodingKeys: String, CodingKey { case type, id, body; case parentId = "parent_id" }
        }
        let envelope: APIEnvelope<StoreCommentResponse> = try await client.request(
            "engagement/comments", method: .post, body: Body(type: type.rawValue, id: id, body: body, parentId: parentId)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func deleteComment(id: Int) async throws -> DestroyCommentResponse {
        let envelope: APIEnvelope<DestroyCommentResponse> = try await client.request(
            "engagement/comments/\(id)", method: .delete
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func share(type: EngagementContentType, id: Int) async throws -> Int {
        struct Body: Encodable { let type: String; let id: Int }
        let envelope: APIEnvelope<ShareResponse> = try await client.request(
            "engagement/shares", method: .post, body: Body(type: type.rawValue, id: id)
        )
        return envelope.data?.count ?? 0
    }
}
