import Foundation

@MainActor
final class ListingDetailViewModel: ObservableObject {
    @Published var listing: Listing?
    @Published var relatedListings: [Listing] = []
    @Published var averageRating: Double = 0
    @Published var reviewCount: Int = 0
    @Published var userHasReviewed = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let slug: String
    private let api: ListingAPIProtocol

    init(slug: String, api: ListingAPIProtocol = ListingAPI()) {
        self.slug = slug
        self.api = api
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.detail(slug: slug)
            listing = response.listing
            relatedListings = response.relatedListings
            averageRating = response.averageRating
            reviewCount = response.reviewCount
            userHasReviewed = response.userHasReviewed
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "লিস্টিং লোড করা যায়নি।"
        }
    }
}
