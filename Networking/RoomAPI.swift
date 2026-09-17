import Foundation

/// ⚠️ ASSUMPTION (আগের সব Phase-এর মতোই): path গুলো অনুমানভিত্তিক।
protocol RoomAPIProtocol {
    // PrivateRoomController
    func myRooms() async throws -> MyRoomsResponse
    func createRoom(name: String) async throws -> CreateRoomResponse
    func joinInfo(token: String) async throws -> RoomJoinInfoResponse
    func verifyPin(token: String, pin: String) async throws
    func roomDetail(token: String) async throws -> (room: PrivateRoom, me: RoomParticipant, plainPin: String?)
    func deleteRoom(token: String) async throws
    func messages(token: String) async throws -> [RoomMessage]
    func sendMessage(token: String, _ request: SendRoomMessageRequest) async throws -> RoomMessage
    func editMessage(token: String, messageId: Int, body: String) async throws -> RoomMessage
    func deleteMessage(token: String, messageId: Int) async throws -> RoomMessage
    func searchMessages(token: String, query: String) async throws -> [RoomMessage]

    // RoomPinnedMessageController
    func pinnedMessages(token: String) async throws -> [RoomMessage]
    func pinMessage(token: String, messageId: Int, silent: Bool) async throws
    func unpinMessage(token: String, messageId: Int) async throws

    // RoomPollController
    func createPoll(token: String, _ request: CreatePollRequest) async throws -> RoomMessage
    func votePoll(token: String, pollId: Int, optionIds: [Int]) async throws -> RoomPoll

    // RoomParticipantController
    func participants(token: String) async throws -> RoomParticipantsResponse
    func kick(token: String, userId: Int) async throws
    func block(token: String, userId: Int) async throws
    func unblock(token: String, userId: Int) async throws
    func promote(token: String, userId: Int) async throws
    func demote(token: String, userId: Int) async throws

    // RoomJoinRequestController
    func requestToJoin(token: String) async throws -> String   // status message
    func joinRequests(token: String) async throws -> [RoomJoinRequestItem]
    func acceptJoinRequest(token: String, userId: Int) async throws
    func rejectJoinRequest(token: String, userId: Int) async throws

    // RoomSettingsController
    func updateSettings(token: String, _ request: RoomSettingsUpdate) async throws

    // RoomSearchController
    func searchRooms(query: String) async throws -> [PrivateRoom]
}

final class RoomAPI: RoomAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func myRooms() async throws -> MyRoomsResponse {
        let envelope: APIEnvelope<MyRoomsResponse> = try await client.request("rooms")
        guard let data = envelope.data else { return MyRoomsResponse(created: [], joined: []) }
        return data
    }

    func createRoom(name: String) async throws -> CreateRoomResponse {
        struct Body: Encodable { let name: String }
        let envelope: APIEnvelope<CreateRoomResponse> = try await client.request(
            "rooms", method: .post, body: Body(name: name)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func joinInfo(token: String) async throws -> RoomJoinInfoResponse {
        let envelope: APIEnvelope<RoomJoinInfoResponse> = try await client.request("rooms/\(token)/join")
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func verifyPin(token: String, pin: String) async throws {
        struct Body: Encodable { let pin: String }
        let _: APIEnvelope<EmptyData> = try await client.request(
            "rooms/\(token)/verify-pin", method: .post, body: Body(pin: pin)
        )
    }

    func roomDetail(token: String) async throws -> (room: PrivateRoom, me: RoomParticipant, plainPin: String?) {
        struct Response: Decodable { let room: PrivateRoom; let me: RoomParticipant; let plainPin: String?
            enum CodingKeys: String, CodingKey { case room, me; case plainPin = "plain_pin" }
        }
        let envelope: APIEnvelope<Response> = try await client.request("rooms/\(token)")
        guard let data = envelope.data else { throw APIError.notFound }
        return (data.room, data.me, data.plainPin)
    }

    func deleteRoom(token: String) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("rooms/\(token)", method: .delete)
    }

    func messages(token: String) async throws -> [RoomMessage] {
        let envelope: APIEnvelope<[RoomMessage]> = try await client.request("rooms/\(token)/messages")
        return envelope.data ?? []
    }

    func sendMessage(token: String, _ request: SendRoomMessageRequest) async throws -> RoomMessage {
        let envelope: APIEnvelope<RoomMessage> = try await client.request(
            "rooms/\(token)/messages", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func editMessage(token: String, messageId: Int, body: String) async throws -> RoomMessage {
        struct Body: Encodable { let body: String }
        let envelope: APIEnvelope<RoomMessage> = try await client.request(
            "rooms/\(token)/messages/\(messageId)", method: .put, body: Body(body: body)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func deleteMessage(token: String, messageId: Int) async throws -> RoomMessage {
        let envelope: APIEnvelope<RoomMessage> = try await client.request(
            "rooms/\(token)/messages/\(messageId)", method: .delete
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func searchMessages(token: String, query: String) async throws -> [RoomMessage] {
        let envelope: APIEnvelope<[RoomMessage]> = try await client.request(
            "rooms/\(token)/search", query: ["q": query]
        )
        return envelope.data ?? []
    }

    func pinnedMessages(token: String) async throws -> [RoomMessage] {
        let envelope: APIEnvelope<[RoomMessage]> = try await client.request("rooms/\(token)/pinned")
        return envelope.data ?? []
    }

    func pinMessage(token: String, messageId: Int, silent: Bool) async throws {
        struct Body: Encodable { let silent: Bool }
        let _: APIEnvelope<EmptyData> = try await client.request(
            "rooms/\(token)/pinned/\(messageId)", method: .post, body: Body(silent: silent)
        )
    }

    func unpinMessage(token: String, messageId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "rooms/\(token)/pinned/\(messageId)", method: .delete
        )
    }

    func createPoll(token: String, _ request: CreatePollRequest) async throws -> RoomMessage {
        let envelope: APIEnvelope<RoomMessage> = try await client.request(
            "rooms/\(token)/polls", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func votePoll(token: String, pollId: Int, optionIds: [Int]) async throws -> RoomPoll {
        let envelope: APIEnvelope<RoomPoll> = try await client.request(
            "rooms/\(token)/polls/\(pollId)/vote", method: .post, body: VotePollRequest(optionIds: optionIds)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func participants(token: String) async throws -> RoomParticipantsResponse {
        let envelope: APIEnvelope<RoomParticipantsResponse> = try await client.request("rooms/\(token)/participants")
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func kick(token: String, userId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "rooms/\(token)/participants/\(userId)/kick", method: .post
        )
    }

    func block(token: String, userId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "rooms/\(token)/participants/\(userId)/block", method: .post
        )
    }

    func unblock(token: String, userId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "rooms/\(token)/participants/\(userId)/unblock", method: .post
        )
    }

    func promote(token: String, userId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "rooms/\(token)/participants/\(userId)/promote", method: .post
        )
    }

    func demote(token: String, userId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "rooms/\(token)/participants/\(userId)/demote", method: .post
        )
    }

    func requestToJoin(token: String) async throws -> String {
        struct Response: Decodable { let status: String; let message: String }
        let envelope: APIEnvelope<Response> = try await client.request(
            "rooms/\(token)/join-requests", method: .post
        )
        return envelope.data?.message ?? envelope.message ?? ""
    }

    func joinRequests(token: String) async throws -> [RoomJoinRequestItem] {
        let envelope: APIEnvelope<[RoomJoinRequestItem]> = try await client.request("rooms/\(token)/join-requests")
        return envelope.data ?? []
    }

    func acceptJoinRequest(token: String, userId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "rooms/\(token)/join-requests/\(userId)/accept", method: .post
        )
    }

    func rejectJoinRequest(token: String, userId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "rooms/\(token)/join-requests/\(userId)/reject", method: .post
        )
    }

    func updateSettings(token: String, _ request: RoomSettingsUpdate) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "rooms/\(token)/settings", method: .put, body: request
        )
    }

    func searchRooms(query: String) async throws -> [PrivateRoom] {
        guard !query.isEmpty else { return [] }
        let envelope: APIEnvelope<[PrivateRoom]> = try await client.request("rooms/search", query: ["q": query])
        return envelope.data ?? []
    }
}
