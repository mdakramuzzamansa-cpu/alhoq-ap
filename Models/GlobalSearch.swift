import Foundation

/// zip: SearchController@index — type ৩টার একটা, default "user"
enum GlobalSearchType: String, CaseIterable {
    case user, ads, video

    var label: String {
        switch self {
        case .user: return "মানুষ"
        case .ads: return "বিজ্ঞাপন"
        case .video: return "ভিডিও"
        }
    }
}

/// zip: usernameSuggest() — এই একটামাত্র endpoint **সত্যিই JSON**, বাকি সব gap না,
/// তাই এটা অনুমান ছাড়াই হুবহু বানানো গেছে
struct UsernameSuggestion: Decodable, Identifiable {
    var id: String { username }
    let username: String
    let handle: String?
    let name: String
    let avatar: String?
    let url: String?   // web route URL — deep-link parsing দিয়ে handle করা যাবে (Phase 16-এর router)
}

/// ⚠️ backend gap (index() Blade-only, usernameSuggest()-এর মতো JSON না) — assumed shape।
/// web-এ @username মোড হলে users/ads/videos-এর বদলে usernameUser+usernamePosts আসে —
/// দুটো মোডই একটা response struct-এ রাখা হলো, কোনটা populated তা দিয়ে UI ঠিক করবে কোন state দেখাবে।
struct GlobalSearchResponse: Decodable {
    let q: String
    let type: String
    let users: [ListingPoster]?
    let ads: [Listing]?
    let videos: [FeedPost]?
    let usernameUser: ListingPoster?
    let usernamePosts: [FeedPost]?

    enum CodingKeys: String, CodingKey {
        case q, type, users, ads, videos
        case usernameUser = "username_user"
        case usernamePosts = "username_posts"
    }
}
