import Foundation

/// zip: app/Http/Controllers/ChatController.php@list() — conversation row shape, হুবহু
struct ChatConversation: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var otherId: Int
    var otherName: String
    var otherAvatar: String?
    var otherOnline: Bool
    var listingTitle: String?
    var lastMessage: String?
    var unread: Int
    var muted: Bool
    var archived: Bool
    var pinned: Bool
    var blocked: Bool
    var lastMessageAt: Double?   // unix timestamp — web `optional($c->last_message_at)->timestamp`

    enum CodingKeys: String, CodingKey {
        case id
        case otherId = "other_id"
        case otherName = "other_name"
        case otherAvatar = "other_avatar"
        case otherOnline = "other_online"
        case listingTitle = "listing_title"
        case lastMessage = "last_message"
        case unread, muted, archived, pinned, blocked
        case lastMessageAt = "last_message_at"
    }
}

/// zip: ChatController@messages() থ্রেড মেটাডেটা
struct ChatThreadInfo: Decodable {
    let otherId: Int
    let otherName: String
    let otherAvatar: String?
    let otherOnline: Bool
    let otherStatusLabel: String?
    let otherCallsEnabled: Bool
    let otherTyping: Bool
    let blocked: Bool
    let messages: [ChatMessage]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case otherId = "other_id"
        case otherName = "other_name"
        case otherAvatar = "other_avatar"
        case otherOnline = "other_online"
        case otherStatusLabel = "other_status_label"
        case otherCallsEnabled = "other_calls_enabled"
        case otherTyping = "other_typing"
        case blocked, messages
        case hasMore = "has_more"
    }
}

struct OlderMessagesResponse: Decodable {
    let messages: [ChatMessage]
    let hasMore: Bool
    enum CodingKeys: String, CodingKey { case messages; case hasMore = "has_more" }
}

/// zip: ChatController@presentMessage() — প্রতিটা ফিল্ড হুবহু
struct ChatMessage: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var type: MessageType
    var body: String
    var isMine: Bool
    var senderName: String
    var createdAt: String        // web আগে থেকেই "g:i A" ফরম্যাট করে পাঠায়
    var delivered: Bool
    var read: Bool
    var attachmentUrl: String?
    var attachmentName: String?
    var attachmentSize: String?   // web formattedSize() — pre-formatted string ("2.3 MB")
    var duration: String?         // web formattedDuration() — pre-formatted ("0:45")
    var mapPreviewUrl: String?
    var mapLink: String?
    var isDeleted: Bool
    var isEdited: Bool
    var pinnedAt: String?
    var pinnedByMe: Bool
    var isForwarded: Bool
    var forwardedFromName: String?

    enum MessageType: String, Codable {
        case text, image, file, voice, location
    }

    enum CodingKeys: String, CodingKey {
        case id, type, body
        case isMine = "is_mine"
        case senderName = "sender_name"
        case createdAt = "created_at"
        case delivered, read
        case attachmentUrl = "attachment_url"
        case attachmentName = "attachment_name"
        case attachmentSize = "attachment_size"
        case duration
        case mapPreviewUrl = "map_preview_url"
        case mapLink = "map_link"
        case isDeleted = "is_deleted"
        case isEdited = "is_edited"
        case pinnedAt = "pinned_at"
        case pinnedByMe = "pinned_by_me"
        case isForwarded = "is_forwarded"
        case forwardedFromName = "forwarded_from_name"
    }
}

/// zip: ChatController@send() validation হুবহু
struct SendMessageRequest: Encodable {
    var body: String?
    var type: ChatMessage.MessageType?
    var attachmentUrl: String?     // Cloudinary secure_url (image/file), অথবা voice রেকর্ডিং-এর URL
    var attachmentName: String?
    var attachmentSize: Int?
    var attachmentMime: String?
    var durationSeconds: Int?
    var latitude: Double?
    var longitude: Double?

    enum CodingKeys: String, CodingKey {
        case body, type
        case attachmentUrl = "attachment_url"
        case attachmentName = "attachment_name"
        case attachmentSize = "attachment_size"
        case attachmentMime = "attachment_mime"
        case durationSeconds = "duration_seconds"
        case latitude, longitude
    }
}

/// web searchUsers() — "নতুন চ্যাট শুরু করুন" পিল সার্চের রেজাল্ট শেপ
struct ChatUserSearchResult: Decodable, Identifiable {
    let id: Int
    let name: String
    let avatarUrl: String?
    let online: Bool
    let companyName: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case avatarUrl = "avatar_url"
        case online
        case companyName = "company_name"
    }
}

/// web ChatController@search() — মেসেজ সার্চ রেজাল্ট
struct MessageSearchResult: Decodable, Identifiable {
    let messageId: Int
    let conversationId: Int
    let otherId: Int
    let otherName: String
    let otherAvatar: String?
    let type: ChatMessage.MessageType
    let snippet: String
    let createdAt: String

    var id: Int { messageId }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case otherId = "other_id"
        case otherName = "other_name"
        case otherAvatar = "other_avatar"
        case type, snippet
        case createdAt = "created_at"
    }
}
