import Foundation

/// zip: Category::SECTION_LABELS — Category.Section enum-এ ইতিমধ্যে আছে (Phase 4),
/// এখানে শুধু সেই একই enum reuse করা হচ্ছে
typealias AppSection = Category.Section

struct CategoryWithCount: Codable, Identifiable, Equatable {
    var category: Category
    var listingsCount: Int

    var id: Int { category.id }

    enum CodingKeys: String, CodingKey {
        case category
        case listingsCount = "listings_count"
    }

    // zip response সম্ভবত category ফিল্ডগুলো flat করে পাঠাবে (listings_count সহ একই object-এ),
    // Category-এর নিজস্ব decoder দিয়ে category অংশ বের করে নেওয়া হচ্ছে
    init(from decoder: Decoder) throws {
        category = try Category(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        listingsCount = try container.decodeIfPresent(Int.self, forKey: .listingsCount) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        try category.encode(to: encoder)
    }
}

/// zip: SectionController@show — Response shape assumed (index() Blade-only, পরিচিত গ্যাপ)
struct SectionBrowseResponse: Decodable {
    let section: String
    let sectionLabel: String
    let categories: [CategoryWithCount]
    let listings: [Listing]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case section
        case sectionLabel = "section_label"
        case categories, listings
        case hasMore = "has_more"
    }
}
