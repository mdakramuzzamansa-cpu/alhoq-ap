import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    @State private var openURLString: String?
    let currentUserId: Int

    var body: some View {
        List {
            ForEach(viewModel.notifications) { notification in
                Button {
                    Task {
                        if let url = await viewModel.open(notification) {
                            DeepLinkRouter.shared.pendingURL = url
                        }
                    }
                } label: {
                    HStack(alignment: .top) {
                        if notification.unread {
                            Circle().fill(Color.accentColor).frame(width: 8, height: 8).padding(.top, 6)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notification.title).font(.subheadline.bold())
                            Text(notification.body).font(.caption).foregroundStyle(.secondary)
                            Text(notification.timeLabel).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .foregroundStyle(.primary)
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(notification) }
                    } label: { Label("ডিলিট", systemImage: "trash") }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.notifications.isEmpty {
                Text("কোনো নোটিফিকেশন নেই").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("নোটিফিকেশন")
        .toolbar {
            toolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("সব পঠিত করুন") { Task { await viewModel.markAllRead() } }
                    Button("সব মুছুন", role: .destructive) { Task { await viewModel.deleteAll() } }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await viewModel.loadFullList() }
        .refreshable { await viewModel.loadFullList() }
    }
}
