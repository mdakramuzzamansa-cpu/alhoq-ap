import Foundation

/// zip: app/Models/Post.php — Panel/PostController@store থেকে যা তৈরি হয়
struct FeedPost: Codable, Identifiable, Equatable {
    let id: Int
    var user: ListingPoster
    var body: String?
    var mediaType: MediaType?
    var mediaPath: String?
    var likesCount: Int
    var commentsCount: Int
    var sharesCount: Int
    var likedByMe: Bool
    var createdAt: Date

    enum MediaType: String, Codable { case photo, video }

    enum CodingKeys: String, CodingKey {
        case id, user, body
        case mediaType = "media_type"
        case mediaPath = "media_path"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case sharesCount = "shares_count"
        case likedByMe = "liked_by_me"
        case createdAt = "created_at"
    }
}

/// zip: HomeController@index — combinedFeed = published listings + text/photo posts, sorted by created_at desc.
/// এখানে দুই ধরনের কার্ডকে একটা enum-এ মুড়ে রাখা হলো যাতে UI একটামাত্র লিস্টে ইটারেট করতে পারে।
enum FeedItem: Identifiable, Equatable {
    case listing(Listing)
    case post(FeedPost)

    var id: String {
        switch self {
        case .listing(let listing): return "listing-\(listing.id)"
        case .post(let post): return "post-\(post.id)"
        }
    }

    var createdSortKey: Date {
        switch self {
        case .listing(let listing): return listing.createdAt ?? .distantPast
        case .post(let post): return post.createdAt
        }
    }
}

/// zip: HomeController-এর raw response — ⚠️ ASSUMPTION shape, কারণ এই তথ্য এখন Blade view-তে
/// যায় (JSON API নেই, নিচে বিস্তারিত নোট)
struct HomeFeedResponse: Decodable {
    let featuredListings: [Listing]
    let combinedFeed: [CombinedFeedEntry]
    let videoFeed: [FeedPost]
    let categories: [Category]

    enum CodingKeys: String, CodingKey {
        case featuredListings = "featured_listings"
        case combinedFeed = "combined_feed"
        case videoFeed = "video_feed"
        case categories
    }
}

struct CombinedFeedEntry: Decodable {
    let type: String   // "listing" | "post"
    let listing: Listing?
    let post: FeedPost?

    var asFeedItem: FeedItem? {
        if type == "listing", let listing { return .listing(listing) }
        if type == "post", let post { return .post(post) }
        return nil
    }
}

// MARK: - Post create/delete

struct CreatePostRequest: Encodable {
    let body: String?
    let media: String?   // Cloudinary secure_url — web নিজেই extension দেখে photo/video ঠিক করে
}

// MARK: - Engagement (zip: EngagementController — Post ও Listing দুটোতেই এক controller দিয়ে কাজ চলে)

enum EngagementContentType: String { case post, listing }

struct ToggleLikeResponse: Decodable { let liked: Bool; let count: Int }
struct ShareResponse: Decodable { let count: Int }

/// zip: buildCommentTree() — সার্ভার-সাইড সব রিপ্লাই ফ্ল্যাট করে টপ-লেভেল প্যারেন্টের নিচে বসায়,
/// তাই ছোট স্ক্রিনে ইনডেন্টেশন দুই লেভেলের বেশি বাড়ে না
struct FeedComment: Codable, Identifiable, Equatable {
    let id: Int
    var body: String
    var userName: String
    var userAvatar: String?
    var createdAt: String
    var canDelete: Bool
    var parentId: Int?
    var topId: Int
    var replyToName: String?
    var replies: [FeedComment]

    enum CodingKeys: String, CodingKey {
        case id, body
        case userName = "user_name"
        case userAvatar = "user_avatar"
        case createdAt = "created_at"
        case canDelete = "can_delete"
        case parentId = "parent_id"
        case topId = "top_id"
        case replyToName = "reply_to_name"
        case replies
    }
}

struct CommentsListResponse: Decodable { let comments: [FeedComment] }
struct StoreCommentResponse: Decodable { let count: Int; let comment: FeedComment }
struct DestroyCommentResponse: Decodable { let count: Int; let topId: Int; let wasTopLevel: Bool
    enum CodingKeys: String, CodingKey { case count; case topId = "top_id"; case wasTopLevel = "was_top_level" }
}
