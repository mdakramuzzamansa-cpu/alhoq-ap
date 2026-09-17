import Foundation

/// zip: app/Models/PrivateRoom.php — PIN-protected rooms, PrivateRoomController@store/show
struct PrivateRoom: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var name: String
    var token: String
    var handle: String?
    var expiresAt: Date?
    var hideMemberList: Bool
    var showHistoryToNewMembers: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, token, handle
        case expiresAt = "expires_at"
        case hideMemberList = "hide_member_list"
        case showHistoryToNewMembers = "show_history_to_new_members"
    }
}

struct MyRoomsResponse: Decodable {
    let created: [PrivateRoom]
    let joined: [PrivateRoom]
}

/// web: PrivateRoomController@store রেসপন্সে plain PIN একবারই দেখা যায় (cache-এ ১০ মিনিট থাকে)
struct CreateRoomResponse: Decodable {
    let room: PrivateRoom
    let plainPin: String?
    enum CodingKeys: String, CodingKey { case room; case plainPin = "plain_pin" }
}

struct RoomJoinInfoResponse: Decodable {
    let room: PrivateRoom
    let pendingRequest: Bool
    enum CodingKeys: String, CodingKey { case room; case pendingRequest = "pending_request" }
}

/// zip: RoomParticipantController — role: owner/admin/member
struct RoomParticipant: Codable, Identifiable, Equatable {
    var id: Int { userId }
    var userId: Int
    var name: String
    var avatar: String?
    var role: Role
    var isBlocked: Bool

    enum Role: String, Codable {
        case owner, admin, member

        var label: String {
            switch self {
            case .owner: return "মালিক"
            case .admin: return "অ্যাডমিন"
            case .member: return "সদস্য"
            }
        }
    }

    var isAdmin: Bool { role == .owner || role == .admin }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name, avatar, role
        case isBlocked = "is_blocked"
    }
}

struct RoomParticipantsResponse: Decodable {
    let participants: [RoomParticipant]
    let adminSeatsUsed: Int
    let adminSeatsMax: Int
    let myRole: RoomParticipant.Role
    enum CodingKeys: String, CodingKey {
        case participants
        case adminSeatsUsed = "admin_seats_used"
        case adminSeatsMax = "admin_seats_max"
        case myRole = "my_role"
    }
}

struct RoomJoinRequestItem: Codable, Identifiable, Equatable {
    var id: Int { userId }
    var userId: Int
    var name: String
    var avatar: String?
    var requestedAt: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name, avatar
        case requestedAt = "requested_at"
    }
}

/// zip: PrivateRoomController@present() — একই shape RoomPollController-এও ব্যবহৃত হয়
struct RoomMessage: Codable, Identifiable, Equatable {
    let id: Int
    var type: MessageType
    var body: String?
    var isDeleted: Bool
    var isEdited: Bool
    var isAnnouncement: Bool
    var silent: Bool
    var isMine: Bool
    var senderId: Int
    var senderName: String
    var createdAt: String
    var editable: Bool
    var attachmentUrl: String?
    var attachmentName: String?
    var attachmentSize: String?
    var duration: String?
    var poll: RoomPoll?

    enum MessageType: String, Codable {
        case text, image, video, file, voice, poll
    }

    enum CodingKeys: String, CodingKey {
        case id, type, body
        case isDeleted = "is_deleted"
        case isEdited = "is_edited"
        case isAnnouncement = "is_announcement"
        case silent
        case isMine = "is_mine"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case createdAt = "created_at"
        case editable
        case attachmentUrl = "attachment_url"
        case attachmentName = "attachment_name"
        case attachmentSize = "attachment_size"
        case duration, poll
    }
}

/// zip: RoomPoll::present() — ⚠️ ASSUMPTION shape (exact present() body দেখা হয়নি,
/// কিন্তু controller-এর ব্যবহার থেকে এই ফিল্ডগুলো নিশ্চিতভাবে দরকার)
struct RoomPoll: Codable, Identifiable, Equatable {
    let id: Int
    var question: String
    var allowMultiple: Bool
    var closed: Bool
    var options: [RoomPollOption]
    var totalVotes: Int

    enum CodingKeys: String, CodingKey {
        case id, question
        case allowMultiple = "allow_multiple"
        case closed, options
        case totalVotes = "total_votes"
    }
}

struct RoomPollOption: Codable, Identifiable, Equatable {
    let id: Int
    var label: String
    var voteCount: Int
    var isMine: Bool
    enum CodingKeys: String, CodingKey {
        case id, label
        case voteCount = "vote_count"
        case isMine = "is_mine"
    }
}

// MARK: - Requests

struct SendRoomMessageRequest: Encodable {
    var body: String?
    var type: RoomMessage.MessageType?
    var attachmentUrl: String?
    var attachmentName: String?
    var attachmentSize: Int?
    var attachmentMime: String?
    var durationSeconds: Int?
    var isAnnouncement: Bool?
    var silent: Bool?
    var clientId: String?

    enum CodingKeys: String, CodingKey {
        case body, type
        case attachmentUrl = "attachment_url"
        case attachmentName = "attachment_name"
        case attachmentSize = "attachment_size"
        case attachmentMime = "attachment_mime"
        case durationSeconds = "duration_seconds"
        case isAnnouncement = "is_announcement"
        case silent
        case clientId = "client_id"
    }
}

struct CreatePollRequest: Encodable {
    let question: String
    let options: [String]
    let allowMultiple: Bool
    let silent: Bool
    enum CodingKeys: String, CodingKey {
        case question, options
        case allowMultiple = "allow_multiple"
        case silent
    }
}

struct VotePollRequest: Encodable { let optionIds: [Int]
    enum CodingKeys: String, CodingKey { case optionIds = "option_ids" }
}

struct RoomSettingsUpdate: Encodable {
    var hideMemberList: Bool?
    var showHistoryToNewMembers: Bool?
    enum CodingKeys: String, CodingKey {
        case hideMemberList = "hide_member_list"
        case showHistoryToNewMembers = "show_history_to_new_members"
    }
}
