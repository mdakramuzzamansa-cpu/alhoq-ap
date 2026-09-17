import Foundation

@MainActor
final class SectionBrowseViewModel: ObservableObject {
    let section: AppSection
    @Published var sectionLabel: String = ""
    @Published var categories: [CategoryWithCount] = []
    @Published var listings: [Listing] = []
    @Published var selectedCategorySlug: String?
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = false
    @Published var errorMessage: String?

    private let api: SectionAPIProtocol = SectionAPI()
    private var currentPage = 1

    init(section: AppSection) { self.section = section }

    func load() async {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        defer { isLoading = false }
        do {
            let response = try await api.browse(section: section, search: searchQuery, page: 1)
            sectionLabel = response.sectionLabel
            categories = response.categories
            listings = response.listings
            hasMore = response.hasMore
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        currentPage += 1
        do {
            let response = try await api.browse(section: section, search: searchQuery, page: currentPage)
            listings += response.listings
            hasMore = response.hasMore
        } catch {
            currentPage -= 1
        }
    }

    /// zip: "Strict scope isolation" — category filter শুধু client-side আলাদা করে দেখানো,
    /// আসল filtering listings array-র মধ্যেই (backend থেকে ইতিমধ্যে section-scoped এসেছে)
    var filteredListings: [Listing] {
        guard let selectedCategorySlug else { return listings }
        return listings.filter { $0.category?.slug == selectedCategorySlug }
    }

    private var searchQuery: String { searchText.trimmingCharacters(in: .whitespaces) }
}

@MainActor
final class PostDetailViewModel: ObservableObject {
    let postId: Int
    @Published var post: FeedPost?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: PostDetailAPIProtocol = PostDetailAPI()
    init(postId: Int) { self.postId = postId }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { post = try await api.post(id: postId) }
        catch let error as APIError {
            if case .notFound = error { errorMessage = "এই পোস্টটি খুঁজে পাওয়া যায়নি অথবা মুছে ফেলা হয়েছে।" }
            else { errorMessage = error.localizedDescription }
        } catch { errorMessage = "লোড করা যায়নি।" }
    }
}
