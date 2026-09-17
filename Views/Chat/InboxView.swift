import SwiftUI

struct InboxView: View {
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var showNewChatSearch = false
    @State private var openConversationId: Int?
    @State private var showArchived = false

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.archivedConversations.isEmpty {
                    Button {
                        showArchived = true
                    } label: {
                        Label("আর্কাইভ করা চ্যাট (\(viewModel.archivedConversations.count))", systemImage: "archivebox")
                    }
                }

                ForEach(viewModel.visibleConversations) { conversation in
                    row(conversation)
                        .onTapGesture { openConversationId = conversation.id }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.conversations.isEmpty {
                    Text("এখনো কোনো চ্যাট নেই").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("চ্যাট")
            .toolbar {
                toolbarItem(placement: .topBarTrailing) {
                    Button { showNewChatSearch = true } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $showNewChatSearch) {
                NewChatSearchView(viewModel: viewModel, openConversationId: $openConversationId)
            }
            .sheet(isPresented: $showArchived) {
                ArchivedConversationsView(viewModel: viewModel, openConversationId: $openConversationId)
            }
            .navigationDestination(item: $openConversationId) { conversationId in
                ChatThreadView(conversationId: conversationId)
            }
        }
    }

    private func row(_ conversation: ChatConversation) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 48, height: 48)
                if conversation.otherOnline {
                    Circle().fill(.green).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(conversation.otherName).font(.subheadline.bold())
                    if conversation.pinned {
                        Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                    if conversation.muted {
                        Image(systemName: "bell.slash.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if let listingTitle = conversation.listingTitle {
                    Text(listingTitle).font(.caption2).foregroundStyle(.blue)
                }
                Text(conversation.lastMessage ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if conversation.unread > 0 {
                Text("\(conversation.unread)")
                    .font(.caption2.bold())
                    .padding(6)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.deleteConversation(conversation) }
            } label: { Label("ডিলিট", systemImage: "trash") }

            Button {
                Task { await viewModel.toggleArchive(conversation) }
            } label: { Label("আর্কাইভ", systemImage: "archivebox") }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await viewModel.togglePin(conversation) }
            } label: { Label(conversation.pinned ? "আনপিন" : "পিন", systemImage: "pin") }
            .tint(.blue)

            Button {
                Task { await viewModel.toggleMute(conversation) }
            } label: { Label(conversation.muted ? "আনমিউট" : "মিউট", systemImage: "bell.slash") }
            .tint(.gray)
        }
    }
}

private struct NewChatSearchView: View {
    @ObservedObject var viewModel: ConversationListViewModel
    @Binding var openConversationId: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(viewModel.userSearchResults) { user in
                Button {
                    Task {
                        if let id = await viewModel.startConversation(withUserId: user.id) {
                            dismiss()
                            openConversationId = id
                        }
                    }
                } label: {
                    HStack {
                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 40)
                        VStack(alignment: .leading) {
                            Text(user.name)
                            if let company = user.companyName { Text(company).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "নাম দিয়ে খুঁজুন")
            .onChange(of: query) { _, newValue in viewModel.searchUsersChanged(newValue) }
            .navigationTitle("নতুন চ্যাট")
            .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
        }
    }
}

private struct ArchivedConversationsView: View {
    @ObservedObject var viewModel: ConversationListViewModel
    @Binding var openConversationId: Int?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewModel.archivedConversations) { conversation in
                Button {
                    dismiss()
                    openConversationId = conversation.id
                } label: {
                    VStack(alignment: .leading) {
                        Text(conversation.otherName)
                        Text(conversation.lastMessage ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("আনআর্কাইভ") { Task { await viewModel.toggleArchive(conversation) } }
                }
            }
            .navigationTitle("আর্কাইভ")
            .toolbar { cancelToolbarItem("বন্ধ করুন") { dismiss() } }
        }
    }
}
