import Foundation

/// zip: app/Http/Controllers/BlockController.php — খুবই সাধারণ, ৩টা অ্যাকশন
struct BlockedUser: Decodable, Identifiable {
    let id: Int          // blocked user-এর id
    let name: String
    let avatar: String?
    let blockedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, avatar
        case blockedAt = "blocked_at"
    }
}

protocol BlockAPIProtocol {
    func blockedUsers() async throws -> [BlockedUser]
    func block(userId: Int) async throws
    func unblock(userId: Int) async throws
}

final class BlockAPI: BlockAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func blockedUsers() async throws -> [BlockedUser] {
        let envelope: APIEnvelope<[BlockedUser]> = try await client.request("users/blocked")
        return envelope.data ?? []
    }

    func block(userId: Int) async throws {
        // web: "You can't block yourself" — সার্ভার-সাইড validate হবে, 422 এলে APIError.validation-এ ধরা পড়বে
        let _: APIEnvelope<EmptyData> = try await client.request("users/\(userId)/block", method: .post)
    }

    func unblock(userId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("users/\(userId)/block", method: .delete)
    }
}
