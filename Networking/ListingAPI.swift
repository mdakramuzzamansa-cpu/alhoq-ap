import Foundation

/// ⚠️ ASSUMPTION (Phase 1-এর মতোই): path গুলো অনুমানভিত্তিক। Android-side আসল
/// `/api/v1/...` route কনফার্ম হলে এই ফাইলেই path বদলালে চলবে।
///
/// web: ListingController@index এর filter params হুবহু query তে ম্যাপ করা হয়েছে —
/// category, search, min_price, max_price, sort (latest/price_low/price_high/popular),
/// plus location resolution (city/lat/lng) সার্ভার-সাইড "Smart Location Engine" হ্যান্ডল করে।
protocol ListingAPIProtocol {
    func categories() async throws -> [Category]
    func feed(filter: ListingFeedFilter, page: Int) async throws -> APIEnvelope<[Listing]>
    func detail(slug: String) async throws -> ListingDetailResponse
    func myListings(page: Int) async throws -> APIEnvelope<[Listing]>
    func create(_ request: ListingFormRequest) async throws -> Listing
    func update(id: Int, _ request: ListingFormRequest) async throws -> Listing
    func delete(id: Int) async throws
}

struct ListingFeedFilter {
    var categorySlug: String?
    var search: String?
    var minPrice: Double?
    var maxPrice: Double?
    var sort: Sort = .latest

    enum Sort: String {
        case latest, priceLow = "price_low", priceHigh = "price_high", popular
    }

    func toQuery() -> [String: String] {
        var query: [String: String] = ["sort": sort.rawValue]
        if let categorySlug { query["category"] = categorySlug }
        if let search, !search.isEmpty { query["search"] = search }
        if let minPrice { query["min_price"] = String(minPrice) }
        if let maxPrice { query["max_price"] = String(maxPrice) }
        return query
    }
}

/// web: ListingController@show — listing + relatedListings + reviews + averageRating + userHasReviewed
struct ListingDetailResponse: Decodable {
    let listing: Listing
    let relatedListings: [Listing]
    let averageRating: Double
    let reviewCount: Int
    let userHasReviewed: Bool

    enum CodingKeys: String, CodingKey {
        case listing
        case relatedListings = "related_listings"
        case averageRating = "average_rating"
        case reviewCount = "review_count"
        case userHasReviewed = "user_has_reviewed"
    }
}

final class ListingAPI: ListingAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func categories() async throws -> [Category] {
        let envelope: APIEnvelope<[Category]> = try await client.request("categories", authenticated: false)
        return envelope.data ?? []
    }

    func feed(filter: ListingFeedFilter, page: Int) async throws -> APIEnvelope<[Listing]> {
        var query = filter.toQuery()
        query["page"] = String(page)
        return try await client.request("listings", query: query, authenticated: false)
    }

    func detail(slug: String) async throws -> ListingDetailResponse {
        let envelope: APIEnvelope<ListingDetailResponse> = try await client.request(
            "listings/\(slug)", authenticated: false
        )
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func myListings(page: Int) async throws -> APIEnvelope<[Listing]> {
        try await client.request("panel/listings", query: ["page": String(page)])
    }

    func create(_ request: ListingFormRequest) async throws -> Listing {
        let envelope: APIEnvelope<Listing> = try await client.request(
            "panel/listings", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func update(id: Int, _ request: ListingFormRequest) async throws -> Listing {
        let envelope: APIEnvelope<Listing> = try await client.request(
            "panel/listings/\(id)", method: .put, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func delete(id: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("panel/listings/\(id)", method: .delete)
    }
}
