import Foundation

@MainActor
final class ListingFeedViewModel: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var categories: [Category] = []
    @Published var filter = ListingFeedFilter()
    @Published var isLoadingInitial = false
    @Published var isLoadingMore = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var hasReachedEnd = false

    private var currentPage = 1
    private let api: ListingAPIProtocol

    init(api: ListingAPIProtocol = ListingAPI()) {
        self.api = api
    }

    var isEmpty: Bool { listings.isEmpty && !isLoadingInitial }

    func loadInitial() async {
        guard listings.isEmpty else { return }
        isLoadingInitial = true
        errorMessage = nil
        defer { isLoadingInitial = false }
        async let categoriesTask: () = loadCategories()
        await categoriesTask
        await fetchPage(reset: true)
    }

    func refresh() async {
        isRefreshing = true
        await fetchPage(reset: true)
        isRefreshing = false
    }

    /// Section 5.1: pagination/infinite scroll — শেষ আইটেমের কাছাকাছি এলে কল হবে
    func loadMoreIfNeeded(currentItem item: Listing) async {
        guard let last = listings.last, last.id == item.id else { return }
        guard !isLoadingMore, !hasReachedEnd else { return }
        await fetchPage(reset: false)
    }

    /// Section 5.3: filter apply/reset
    func applyFilter() async {
        await fetchPage(reset: true)
    }

    func resetFilter() async {
        filter = ListingFeedFilter()
        await fetchPage(reset: true)
    }

    private func loadCategories() async {
        categories = (try? await api.categories()) ?? []
    }

    private func fetchPage(reset: Bool) async {
        if reset {
            currentPage = 1
            hasReachedEnd = false
        } else {
            isLoadingMore = true
        }
        defer { isLoadingMore = false }

        do {
            let envelope = try await api.feed(filter: filter, page: currentPage)
            let newItems = envelope.data ?? []
            listings = reset ? newItems : listings + newItems

            if let pagination = envelope.pagination,
               let last = pagination.lastPage, let current = pagination.currentPage {
                hasReachedEnd = current >= last
            } else {
                hasReachedEnd = newItems.isEmpty
            }
            currentPage += 1
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "লিস্টিং লোড করা যায়নি।"
        }
    }
}
