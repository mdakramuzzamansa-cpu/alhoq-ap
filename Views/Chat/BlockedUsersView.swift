import SwiftUI

@MainActor
final class BlockedUsersViewModel: ObservableObject {
    @Published var blockedUsers: [BlockedUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: BlockAPIProtocol
    init(api: BlockAPIProtocol = BlockAPI()) { self.api = api }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { blockedUsers = try await api.blockedUsers() }
        catch { errorMessage = "লোড করা যায়নি।" }
    }

    func unblock(_ user: BlockedUser) async {
        do {
            try await api.unblock(userId: user.id)
            blockedUsers.removeAll { $0.id == user.id }
        } catch {
            errorMessage = "আনব্লক করা যায়নি।"
        }
    }
}

struct BlockedUsersView: View {
    @StateObject private var viewModel = BlockedUsersViewModel()

    var body: some View {
        List {
            ForEach(viewModel.blockedUsers) { user in
                HStack {
                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 36, height: 36)
                    Text(user.name)
                    Spacer()
                    Button("আনব্লক") { Task { await viewModel.unblock(user) } }
                        .buttonStyle(.bordered)
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.blockedUsers.isEmpty {
                Text("কাউকে ব্লক করা নেই").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("ব্লক করা ইউজার")
        .task { await viewModel.load() }
    }
}
