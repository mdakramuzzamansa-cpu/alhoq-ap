import Foundation

/// ⚠️ ASSUMPTION (আগের সব Phase-এর মতোই): path গুলো অনুমানভিত্তিক — Android API কনফার্ম
/// হলে এই একটা ফাইলে বদলালেই চলবে।
///
/// ❌ realtime (broadcast/typing/online status) — web Pusher/Echo দিয়ে সরাসরি push করে;
/// iOS-এ এখনো কোনো socket layer নেই (এটা নিজেই একটা আলাদা cross-cutting Phase হওয়া উচিত,
/// কারণ Chat/Feed/Notifications/Rooms/Live সবগুলোই এটার উপর নির্ভর করবে)। এখন পর্যন্ত
/// থ্রেড/লিস্ট refresh pull-to-refresh + periodic poll দিয়ে হচ্ছে, push দিয়ে না —
/// UI/API contract অভিন্ন রাখা হয়েছে যাতে socket layer বসানোর সময় শুধু "কখন fetch হবে"
/// অংশটুকু বদলালেই চলে, ViewModel/View-তে হাত দিতে হবে না।
protocol ChatAPIProtocol {
    func conversations() async throws -> [ChatConversation]
    func thread(conversationId: Int) async throws -> ChatThreadInfo
    func olderMessages(conversationId: Int, beforeId: Int) async throws -> OlderMessagesResponse
    func send(conversationId: Int, _ request: SendMessageRequest) async throws -> ChatMessage
    func editMessage(conversationId: Int, messageId: Int, body: String) async throws -> ChatMessage
    func deleteMessage(conversationId: Int, messageId: Int, scope: DeleteScope) async throws
    func pinMessage(conversationId: Int, messageId: Int) async throws -> ChatMessage
    func unpinMessage(conversationId: Int, messageId: Int) async throws -> ChatMessage
    func forwardMessage(conversationId: Int, messageId: Int, toConversationIds: [Int]) async throws
    func reportMessage(conversationId: Int, messageId: Int, reason: String?) async throws
    func sendTyping(conversationId: Int) async throws
    func startWithListing(listingId: Int) async throws -> Int
    func startWithUser(userId: Int) async throws -> Int
    func searchUsers(query: String) async throws -> [ChatUserSearchResult]
    func searchMessages(query: String, media: String, person: String) async throws -> [MessageSearchResult]
    func deleteConversation(conversationId: Int) async throws
    func toggleMute(conversationId: Int) async throws -> Bool
    func toggleArchive(conversationId: Int) async throws -> Bool
    func togglePinConversation(conversationId: Int) async throws -> Bool
}

enum DeleteScope: String { case me, everyone }

final class ChatAPI: ChatAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func conversations() async throws -> [ChatConversation] {
        let envelope: APIEnvelope<[ChatConversation]> = try await client.request("chat/conversations")
        return envelope.data ?? []
    }

    func thread(conversationId: Int) async throws -> ChatThreadInfo {
        let envelope: APIEnvelope<ChatThreadInfo> = try await client.request(
            "chat/conversations/\(conversationId)/messages"
        )
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func olderMessages(conversationId: Int, beforeId: Int) async throws -> OlderMessagesResponse {
        let envelope: APIEnvelope<OlderMessagesResponse> = try await client.request(
            "chat/conversations/\(conversationId)/messages/older", query: ["before_id": String(beforeId)]
        )
        guard let data = envelope.data else { return OlderMessagesResponse(messages: [], hasMore: false) }
        return data
    }

    func send(conversationId: Int, _ request: SendMessageRequest) async throws -> ChatMessage {
        let envelope: APIEnvelope<ChatMessage> = try await client.request(
            "chat/conversations/\(conversationId)/messages", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func editMessage(conversationId: Int, messageId: Int, body: String) async throws -> ChatMessage {
        struct Body: Encodable { let body: String }
        let envelope: APIEnvelope<ChatMessage> = try await client.request(
            "chat/conversations/\(conversationId)/messages/\(messageId)", method: .put, body: Body(body: body)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func deleteMessage(conversationId: Int, messageId: Int, scope: DeleteScope) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "chat/conversations/\(conversationId)/messages/\(messageId)",
            method: .delete, query: ["scope": scope.rawValue]
        )
    }

    func pinMessage(conversationId: Int, messageId: Int) async throws -> ChatMessage {
        let envelope: APIEnvelope<ChatMessage> = try await client.request(
            "chat/conversations/\(conversationId)/messages/\(messageId)/pin", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func unpinMessage(conversationId: Int, messageId: Int) async throws -> ChatMessage {
        let envelope: APIEnvelope<ChatMessage> = try await client.request(
            "chat/conversations/\(conversationId)/messages/\(messageId)/unpin", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func forwardMessage(conversationId: Int, messageId: Int, toConversationIds: [Int]) async throws {
        struct Body: Encodable { let conversationIds: [Int]
            enum CodingKeys: String, CodingKey { case conversationIds = "conversation_ids" }
        }
        let _: APIEnvelope<EmptyData> = try await client.request(
            "chat/conversations/\(conversationId)/messages/\(messageId)/forward",
            method: .post, body: Body(conversationIds: toConversationIds)
        )
    }

    func reportMessage(conversationId: Int, messageId: Int, reason: String?) async throws {
        struct Body: Encodable { let reason: String? }
        let _: APIEnvelope<EmptyData> = try await client.request(
            "chat/conversations/\(conversationId)/messages/\(messageId)/report",
            method: .post, body: Body(reason: reason)
        )
    }

    func sendTyping(conversationId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "chat/conversations/\(conversationId)/typing", method: .post
        )
    }

    func startWithListing(listingId: Int) async throws -> Int {
        struct Response: Decodable { let conversationId: Int
            enum CodingKeys: String, CodingKey { case conversationId = "conversation_id" }
        }
        let envelope: APIEnvelope<Response> = try await client.request(
            "chat/start/listing/\(listingId)", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data.conversationId
    }

    func startWithUser(userId: Int) async throws -> Int {
        struct Response: Decodable { let conversationId: Int
            enum CodingKeys: String, CodingKey { case conversationId = "conversation_id" }
        }
        let envelope: APIEnvelope<Response> = try await client.request(
            "chat/start/user/\(userId)", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data.conversationId
    }

    func searchUsers(query: String) async throws -> [ChatUserSearchResult] {
        guard !query.isEmpty else { return [] }
        let envelope: APIEnvelope<[ChatUserSearchResult]> = try await client.request(
            "chat/search-users", query: ["q": query]
        )
        return envelope.data ?? []
    }

    func searchMessages(query: String, media: String, person: String) async throws -> [MessageSearchResult] {
        var q: [String: String] = ["media": media]
        if !query.isEmpty { q["q"] = query }
        if !person.isEmpty { q["person"] = person }
        let envelope: APIEnvelope<[MessageSearchResult]> = try await client.request("chat/search", query: q)
        return envelope.data ?? []
    }

    func deleteConversation(conversationId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("chat/conversations/\(conversationId)", method: .delete)
    }

    func toggleMute(conversationId: Int) async throws -> Bool {
        struct Response: Decodable { let muted: Bool }
        let envelope: APIEnvelope<Response> = try await client.request(
            "chat/conversations/\(conversationId)/toggle-mute", method: .post
        )
        return envelope.data?.muted ?? false
    }

    func toggleArchive(conversationId: Int) async throws -> Bool {
        struct Response: Decodable { let archived: Bool }
        let envelope: APIEnvelope<Response> = try await client.request(
            "chat/conversations/\(conversationId)/toggle-archive", method: .post
        )
        return envelope.data?.archived ?? false
    }

    func togglePinConversation(conversationId: Int) async throws -> Bool {
        struct Response: Decodable { let pinned: Bool }
        let envelope: APIEnvelope<Response> = try await client.request(
            "chat/conversations/\(conversationId)/toggle-pin", method: .post
        )
        return envelope.data?.pinned ?? false
    }
}
