import Foundation

/// zip: app/Models/Review.php — submit-only থেকে reviews তালিকা আলাদা কোনো endpoint নেই;
/// listing detail-এর averageRating/reviewCount ইতিমধ্যে ListingDetailViewModel-এ আছে (Phase 4)
struct CreateReviewRequest: Encodable {
    let rating: Int
    let comment: String?
}

protocol ReviewAPIProtocol {
    func submitReview(listingId: Int, _ request: CreateReviewRequest) async throws
}

final class ReviewAPI: ReviewAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func submitReview(listingId: Int, _ request: CreateReviewRequest) async throws {
        // web: duplicate review → 403 ("You already reviewed this listing"),
        // নিজের listing → 403 ("You can't review your own listing") — দুটোই .forbidden এ ধরা পড়বে
        let _: APIEnvelope<EmptyData> = try await client.request(
            "listings/\(listingId)/reviews", method: .post, body: request
        )
    }
}
