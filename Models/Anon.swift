import Foundation

/// zip: app/Models/AnonIdentity.php $fillable — pseudonym/avatar_color/avatar_initials
/// র‍্যান্ডম জেনারেট হয়, ইউজার নিজে বসাতে পারবে না — শুধু regenerate করতে পারবে
struct AnonIdentity: Codable, Equatable {
    var pseudonym: String
    var avatarColor: String
    var avatarInitials: String

    enum CodingKeys: String, CodingKey {
        case pseudonym
        case avatarColor = "avatar_color"
        case avatarInitials = "avatar_initials"
    }
}

/// zip: AnonymousController@index/store — নোট: এখানে কমেন্ট **সত্যিই ২-লেভেল nested**
/// (comments -> replies), Feed মডিউলের মতো flatten করা না — সেই পার্থক্যটা মডেলে রাখা হয়েছে
struct AnonPost: Codable, Identifiable, Equatable {
    let id: Int
    var identity: AnonIdentity
    var body: String?
    var type: MessageType
    var attachmentUrl: String?
    var attachmentName: String?
    var attachmentSize: String?
    var duration: String?
    var likeCount: Int
    var likedByMe: Bool
    var commentCount: Int
    var comments: [AnonComment]
    var createdAt: String
    var isDeletableByMe: Bool

    enum MessageType: String, Codable { case text, image, video, file, voice }

    enum CodingKeys: String, CodingKey {
        case id, identity, body, type
        case attachmentUrl = "attachment_url"
        case attachmentName = "attachment_name"
        case attachmentSize = "attachment_size"
        case duration
        case likeCount = "like_count"
        case likedByMe = "liked_by_me"
        case commentCount = "comment_count"
        case comments
        case createdAt = "created_at"
        case isDeletableByMe = "is_deletable_by_me"
    }
}

struct AnonComment: Codable, Identifiable, Equatable {
    let id: Int
    var identity: AnonIdentity
    var body: String
    var parentId: Int?
    var likeCount: Int
    var likedByMe: Bool
    var replies: [AnonComment]
    var createdAt: String
    var isDeletableByMe: Bool

    enum CodingKeys: String, CodingKey {
        case id, identity, body
        case parentId = "parent_id"
        case likeCount = "like_count"
        case likedByMe = "liked_by_me"
        case replies
        case createdAt = "created_at"
        case isDeletableByMe = "is_deletable_by_me"
    }
}

struct CreateAnonPostRequest: Encodable {
    var body: String?
    var type: AnonPost.MessageType?
    var attachmentUrl: String?
    var attachmentName: String?
    var attachmentMime: String?
    var attachmentSize: Int?
    var durationSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case body, type
        case attachmentUrl = "attachment_url"
        case attachmentName = "attachment_name"
        case attachmentMime = "attachment_mime"
        case attachmentSize = "attachment_size"
        case durationSeconds = "duration_seconds"
    }
}
