import Foundation

/// zip: SellerProfileController@show — is_anonymous listing কখনো এখানে দেখানো হয় না
/// (নিজেই anonymity leak করবে), তাই সার্ভার-সাইড ফিল্টার — iOS শুধু যা আসে তাই দেখায়
struct SellerProfile: Decodable {
    let user: AlhoqUser
    let listings: [Listing]        // published, non-anonymous, ৯টা প্রতি পেজ
    let posts: [FeedPost]          // ৯টা প্রতি পেজ
    let memberSince: String        // "২ বছর" জাতীয় human-readable diff
    let totalListings: Int
    let trustedBadges: [TrustedBadge]
}

/// zip: User::trustedVerifications() — শুধু approved category verification
struct TrustedBadge: Codable, Identifiable {
    let id: Int
    var category: Category
}

/// zip: Panel/DashboardController@index — নিজের ড্যাশবোর্ড সামারি
struct DashboardStats: Decodable {
    let stats: Counts
    let feedItems: [CombinedFeedEntry]
    let activePackage: UserPackage?
    let listingLimit: Int
    let listingsRemaining: Int
    let needsAvailabilityListingIds: [Int]   // bookable কিন্তু কোনো active schedule নেই এমন লিস্টিং
    let handshakePendingCount: Int
    let handshakeConnections: [ListingPoster]
    let bookingsCount: Int

    struct Counts: Decodable {
        let total: Int
        let published: Int
        let pending: Int
        let views: Int
    }

    enum CodingKeys: String, CodingKey {
        case stats
        case feedItems = "feed_items"
        case activePackage = "active_package"
        case listingLimit = "listing_limit"
        case listingsRemaining = "listings_remaining"
        case needsAvailabilityListingIds = "needs_availability_listing_ids"
        case handshakePendingCount = "handshake_pending_count"
        case handshakeConnections = "handshake_connections"
        case bookingsCount = "bookings_count"
    }
}
