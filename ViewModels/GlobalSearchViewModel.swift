import Foundation

@MainActor
final class GlobalSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var type: GlobalSearchType = .user
    @Published var suggestions: [UsernameSuggestion] = []
    @Published var response: GlobalSearchResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: GlobalSearchAPIProtocol = GlobalSearchAPI()
    private var suggestTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    /// টাইপ করার সময় @username autocomplete — web-এর মতো প্রতিটা কিস্ট্রোকে
    func queryChanged() {
        suggestTask?.cancel()
        guard !query.isEmpty else { suggestions = []; return }
        suggestTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            suggestions = (try? await api.usernameSuggestions(query: query.trimmingCharacters(in: CharacterSet(charactersIn: "@")))) ?? []
        }
    }

    func submitSearch() {
        suggestions = []
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { response = nil; return }
        isLoading = true
        errorMessage = nil
        searchTask = Task {
            defer { isLoading = false }
            do { response = try await api.search(query: query, type: type, page: 1) }
            catch { errorMessage = "খুঁজে পাওয়া যায়নি।" }
        }
    }

    func typeChanged() {
        submitSearch()
    }
}
