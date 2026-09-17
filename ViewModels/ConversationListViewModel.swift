import Foundation

@MainActor
final class ConversationListViewModel: ObservableObject {
    @Published var conversations: [ChatConversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery: String = ""
    @Published var userSearchResults: [ChatUserSearchResult] = []
    @Published var isSearchingUsers = false

    private let api: ChatAPIProtocol
    private var searchTask: Task<Void, Never>?

    init(api: ChatAPIProtocol = ChatAPI()) {
        self.api = api
    }

    /// web sortByDesc(pinned দিয়ে আগে, তারপর last_message_at) — server-side sorted হয়ে আসে,
    /// কিন্তু archived-কে মূল লিস্ট থেকে আলাদা tab-এ রাখা web-এর behavior অনুযায়ী
    var visibleConversations: [ChatConversation] {
        conversations.filter { !$0.archived }
    }

    var archivedConversations: [ChatConversation] {
        conversations.filter { $0.archived }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            conversations = try await api.conversations()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }

    /// web searchUsers() — "নতুন চ্যাট শুরু করুন" পিল সার্চ, debounce করা
    func searchUsersChanged(_ query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else { userSearchResults = []; return }
        isSearchingUsers = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            userSearchResults = (try? await api.searchUsers(query: query)) ?? []
            isSearchingUsers = false
        }
    }

    func startConversation(withUserId userId: Int) async -> Int? {
        try? await api.startWithUser(userId: userId)
    }

    func toggleMute(_ conversation: ChatConversation) async {
        guard let muted = try? await api.toggleMute(conversationId: conversation.id) else { return }
        updateLocal(conversation.id) { $0.muted = muted }
    }

    func toggleArchive(_ conversation: ChatConversation) async {
        guard let archived = try? await api.toggleArchive(conversationId: conversation.id) else { return }
        updateLocal(conversation.id) { $0.archived = archived }
    }

    func togglePin(_ conversation: ChatConversation) async {
        guard let pinned = try? await api.togglePinConversation(conversationId: conversation.id) else { return }
        updateLocal(conversation.id) { $0.pinned = pinned }
    }

    /// web "Delete chat" — শুধু নিজের লিস্ট থেকে সরে যায়
    func deleteConversation(_ conversation: ChatConversation) async {
        try? await api.deleteConversation(conversationId: conversation.id)
        conversations.removeAll { $0.id == conversation.id }
    }

    private func updateLocal(_ id: Int, mutate: (inout ChatConversation) -> Void) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        mutate(&conversations[index])
    }
}
