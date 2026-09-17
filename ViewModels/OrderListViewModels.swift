import Foundation

@MainActor
final class OrderCreateViewModel: ObservableObject {
    let listing: Listing
    @Published var buyerNotes: String = ""
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var createdOrder: AlhoqOrder?

    private let api: OrderAPIProtocol
    init(listing: Listing, api: OrderAPIProtocol = OrderAPI()) {
        self.listing = listing
        self.api = api
    }

    var canSubmit: Bool {
        !buyerNotes.trimmingCharacters(in: .whitespaces).isEmpty && !isSubmitting
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            createdOrder = try await api.createOrder(
                listingId: listing.id,
                CreateOrderRequest(buyerNotes: buyerNotes, formAnswers: nil)
                // NOTE: listing.customForm dynamic answers (custom_forms/form_responses) —
                // Phase 20 (Custom Forms) বসলে এখানে formAnswers পপুলেট হবে
            )
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "অর্ডার তৈরি করা যায়নি।"
        }
    }
}

@MainActor
final class OrderListViewModel: ObservableObject {
    @Published var buying: [AlhoqOrder] = []
    @Published var selling: [AlhoqOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: OrderAPIProtocol
    init(api: OrderAPIProtocol = OrderAPI()) { self.api = api }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let buyingResult = api.buyingOrders(page: 1)
        async let sellingResult = api.sellingOrders(page: 1)
        do {
            let (b, s) = try await (buyingResult, sellingResult)
            buying = b.data ?? []
            selling = s.data ?? []
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }
}
