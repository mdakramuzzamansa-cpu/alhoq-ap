import Foundation

/// zip: app/Models/Listing.php $fillable + migrations (create_listings_table,
/// add_escrow_fields..., add_target_scope_and_location_setting) — কোনো ফিল্ড বাদ দেওয়া হয়নি।
struct Listing: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var userId: Int
    var categoryId: Int
    var category: Category?
    var user: ListingPoster?          // web: is_anonymous হলে backend থেকেই null/hidden আসা উচিত
    var title: String
    var slug: String
    var description: String?
    var metaTitle: String?
    var metaDescription: String?
    var price: Double?
    var priceType: PriceType
    var requiresPayment: Bool
    var alhoqDeliveryHours: Int?      // Direct-Deal Order-এর ডেলিভারি সময়সীমা
    var alhoqMaxRevisions: Int?
    var location: String?
    var targetScope: TargetScope
    var latitude: Double?
    var longitude: Double?
    var contactPhone: String?
    var contactEmail: String?
    var status: Status
    var isAnonymous: Bool
    var isFeatured: Bool
    var views: Int
    var featuredUntil: Date?
    var expiresAt: Date?
    var images: [ListingImage]
    var averageRating: Double?
    var reviewCount: Int?
    var createdAt: Date?

    enum PriceType: String, Codable, CaseIterable {
        case fixed, negotiable, free
        case onRequest = "on_request"

        var label: String {
            switch self {
            case .fixed: return "নির্দিষ্ট মূল্য"
            case .negotiable: return "আলোচনা সাপেক্ষ"
            case .free: return "ফ্রি"
            case .onRequest: return "জিজ্ঞাসা করুন"
            }
        }
    }

    enum TargetScope: String, Codable, CaseIterable {
        case localOnly = "local_only"
        case everywhere

        var label: String {
            self == .localOnly ? "শুধু নিজ এলাকায়" : "সব জায়গায়"
        }
    }

    enum Status: String, Codable {
        case draft, pending, published, rejected, expired

        var label: String {
            switch self {
            case .draft: return "খসড়া"
            case .pending: return "অনুমোদনের অপেক্ষায়"
            case .published: return "প্রকাশিত"
            case .rejected: return "প্রত্যাখ্যাত"
            case .expired: return "মেয়াদোত্তীর্ণ"
            }
        }
    }

    /// web posterName()/canShowPosterProfile() — anonymous হলে আসল ইউজার তথ্য কখনো দেখানো যাবে না
    var posterDisplayName: String {
        isAnonymous ? "Anonymous User" : (user?.name ?? "Unknown Seller")
    }

    var canShowPosterProfile: Bool {
        !isAnonymous && user != nil
    }

    var visibleContactPhone: String? { isAnonymous ? nil : contactPhone }
    var visibleContactEmail: String? { isAnonymous ? nil : contactEmail }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case categoryId = "category_id"
        case category, user, title, slug, description
        case metaTitle = "meta_title"
        case metaDescription = "meta_description"
        case price
        case priceType = "price_type"
        case requiresPayment = "requires_payment"
        case alhoqDeliveryHours = "alhoq_delivery_hours"
        case alhoqMaxRevisions = "alhoq_max_revisions"
        case location
        case targetScope = "target_scope"
        case latitude, longitude
        case contactPhone = "contact_phone"
        case contactEmail = "contact_email"
        case status
        case isAnonymous = "is_anonymous"
        case isFeatured = "is_featured"
        case views
        case featuredUntil = "featured_until"
        case expiresAt = "expires_at"
        case images
        case averageRating = "average_rating"
        case reviewCount = "review_count"
        case createdAt = "created_at"
    }
}

struct ListingImage: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var path: String        // পূর্ণ URL — Universal Media Upload endpoint থেকে আসা
    var isPrimary: Bool
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, path
        case isPrimary = "is_primary"
        case sortOrder = "sort_order"
    }
}

/// listing.user — শুধু listing card/detail-এ যতটুকু দরকার (পুরো AlhoqUser না, কারণ
/// anonymous listing-এ backend এই অবজেক্টটাই null পাঠাবে)
struct ListingPoster: Codable, Equatable, Hashable {
    let id: Int
    var name: String
    var username: String?
    var avatar: String?
    var isTrusted: Bool?    // seller trust badge — Section 5.1 "trust information"
}
