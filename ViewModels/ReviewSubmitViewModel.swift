import Foundation

@MainActor
final class ReviewSubmitViewModel: ObservableObject {
    let listingId: Int
    @Published var rating: Int = 5
    @Published var comment: String = ""
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var didSubmit = false

    private let api: ReviewAPIProtocol
    init(listingId: Int, api: ReviewAPIProtocol = ReviewAPI()) {
        self.listingId = listingId
        self.api = api
    }

    func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await api.submitReview(
                listingId: listingId,
                CreateReviewRequest(rating: rating, comment: comment.isEmpty ? nil : comment)
            )
            didSubmit = true
        } catch let error as APIError {
            switch error {
            case .forbidden:
                // web-এর দুই ধরনের 403 এখানেই একসাথে ধরা পড়ে (নিজের লিস্টিং / আগেই রিভিউ দেওয়া)
                errorMessage = "আপনি এই লিস্টিংয়ে রিভিউ দিতে পারবেন না — নিজের লিস্টিং অথবা আগেই রিভিউ দিয়েছেন।"
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "রিভিউ জমা দেওয়া যায়নি।"
        }
    }
}
