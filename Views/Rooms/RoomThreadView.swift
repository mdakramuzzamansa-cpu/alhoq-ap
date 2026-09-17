import SwiftUI
import PhotosUI

struct RoomThreadView: View {
    @StateObject private var viewModel: RoomThreadViewModel
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var showPollCreate = false
    @State private var showAnnouncementCreate = false
    @State private var showPinnedSheet = false
    @State private var showParticipants = false
    @State private var showSearch = false
    @State private var editingMessage: RoomMessage?
    @State private var editText = ""

    init(token: String) {
        _viewModel = StateObject(wrappedValue: RoomThreadViewModel(token: token))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let pin = viewModel.plainPin {
                Text("এই রুমের PIN: \(pin) (শুধু আপনি এটা দেখছেন, একবারই)")
                    .font(.caption).padding(8).background(Color.yellow.opacity(0.2))
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            RoomMessageBubble(message: message, onVote: { optionIds in
                                Task { await viewModel.vote(pollId: message.poll?.id ?? 0, optionIds: optionIds) }
                            })
                            .id(message.id)
                            .contextMenu {
                                if message.editable {
                                    Button("এডিট করুন") { editingMessage = message; editText = message.body ?? "" }
                                }
                                if viewModel.me?.isAdmin == true || message.isMine {
                                    Button("সবার জন্য ডিলিট", role: .destructive) {
                                        Task { await viewModel.deleteMessage(message) }
                                    }
                                }
                                Button("পিন করুন") { Task { await viewModel.pinMessage(message, silent: false) } }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error).font(.caption2).foregroundStyle(.red)
            }

            composer
        }
        .navigationTitle(viewModel.room?.name ?? "রুম")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarItemGroup(placement: .topBarTrailing) {
                Button { showPinnedSheet = true } label: { Image(systemName: "pin") }
                Button { showSearch = true } label: { Image(systemName: "magnifyingglass") }
                Menu {
                    Button("পোল তৈরি করুন", systemImage: "chart.bar") { showPollCreate = true }
                    if viewModel.me?.isAdmin == true {
                        Button("ঘোষণা পাঠান", systemImage: "megaphone") { showAnnouncementCreate = true }
                    }
                    Button("সদস্যরা", systemImage: "person.2") { showParticipants = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showPollCreate) { PollCreateSheet(viewModel: viewModel) }
        .sheet(isPresented: $showAnnouncementCreate) { AnnouncementCreateSheet(viewModel: viewModel) }
        .sheet(isPresented: $showPinnedSheet) { PinnedMessagesSheet(token: viewModel.token) }
        .sheet(isPresented: $showSearch) { RoomMessageSearchSheet(token: viewModel.token) }
        .sheet(isPresented: $showParticipants) { RoomParticipantsSheet(token: viewModel.token, initialRoom: viewModel.room) }
        .alert("মেসেজ এডিট করুন", isPresented: Binding(get: { editingMessage != nil }, set: { if !$0 { editingMessage = nil } })) {
            TextField("মেসেজ", text: $editText)
            Button("সেভ") { if let m = editingMessage { Task { await viewModel.editMessage(m, newBody: editText) } } }
            Button("বাতিল", role: .cancel) {}
        }
    }

    private var composer: some View {
        HStack {
            PhotosPicker(selection: $selectedImageItem, matching: .images) { Image(systemName: "photo") }
                .onChange(of: selectedImageItem) { _, item in
                    guard let item else { return }
                    Task {
                        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                        try? data.write(to: tempURL)
                        await viewModel.sendImage(fileURL: tempURL)
                        selectedImageItem = nil
                    }
                }
            TextField("মেসেজ লিখুন", text: $viewModel.composerText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await viewModel.sendText() }
            } label: { Image(systemName: "paperplane.fill") }
                .disabled(viewModel.composerText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(.thinMaterial)
    }
}

private struct RoomMessageBubble: View {
    let message: RoomMessage
    let onVote: ([Int]) -> Void
    @State private var selectedOptions: Set<Int> = []

    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: 40) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                if message.isAnnouncement {
                    Label("ঘোষণা", systemImage: "megaphone.fill").font(.caption2).foregroundStyle(.orange)
                }
                Text(message.senderName).font(.caption2).foregroundStyle(.secondary)

                if message.isDeleted {
                    Text("এই মেসেজটি মুছে ফেলা হয়েছে").italic().foregroundStyle(.secondary)
                } else if let poll = message.poll {
                    pollView(poll)
                } else if message.type == .image {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3)).frame(width: 160, height: 120)
                } else {
                    Text(message.body ?? "")
                        .padding(10)
                        .background(message.isMine ? Color.accentColor : Color.gray.opacity(0.15))
                        .foregroundStyle(message.isMine ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                HStack(spacing: 4) {
                    if message.isEdited { Text("edited").font(.caption2).foregroundStyle(.secondary) }
                    Text(message.createdAt).font(.caption2).foregroundStyle(.secondary)
                }
            }
            if !message.isMine { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private func pollView(_ poll: RoomPoll) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(poll.question).font(.subheadline.bold())
            ForEach(poll.options) { option in
                Button {
                    if poll.allowMultiple {
                        if selectedOptions.contains(option.id) { selectedOptions.remove(option.id) }
                        else { selectedOptions.insert(option.id) }
                        onVote(Array(selectedOptions))
                    } else {
                        onVote([option.id])
                    }
                } label: {
                    HStack {
                        Image(systemName: option.isMine ? "checkmark.circle.fill" : "circle")
                        Text(option.label)
                        Spacer()
                        Text("\(option.voteCount)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .disabled(poll.closed)
            }
            Text("মোট ভোট: \(poll.totalVotes)").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct PollCreateSheet: View {
    @ObservedObject var viewModel: RoomThreadViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var options: [String] = ["", ""]
    @State private var allowMultiple = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("প্রশ্ন", text: $question)
                ForEach(options.indices, id: \.self) { i in
                    TextField("অপশন \(i + 1)", text: $options[i])
                }
                if options.count < 10 {
                    Button("অপশন যোগ করুন") { options.append("") }
                }
                Toggle("একাধিক অপশন বাছা যাবে", isOn: $allowMultiple)
                Button("পোল পাঠান") {
                    Task {
                        await viewModel.createPoll(
                            question: question, options: options.filter { !$0.isEmpty },
                            allowMultiple: allowMultiple, silent: false
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(question.isEmpty || options.filter { !$0.isEmpty }.count < 2)
            }
            .navigationTitle("নতুন পোল")
            .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
        }
    }
}

private struct AnnouncementCreateSheet: View {
    @ObservedObject var viewModel: RoomThreadViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var silent = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("ঘোষণার লেখা", text: $text, axis: .vertical)
                Toggle("সাইলেন্ট (নোটিফিকেশন ছাড়া)", isOn: $silent)
                Button("পাঠান") {
                    Task { await viewModel.sendAnnouncement(text: text, silent: silent); dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.isEmpty)
            }
            .navigationTitle("ঘোষণা")
            .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
        }
    }
}

private struct PinnedMessagesSheet: View {
    let token: String
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [RoomMessage] = []
    private let api: RoomAPIProtocol = RoomAPI()

    var body: some View {
        NavigationStack {
            List(messages) { message in
                VStack(alignment: .leading) {
                    Text(message.senderName).font(.caption.bold())
                    Text(message.body ?? "").font(.caption)
                }
            }
            .overlay { if messages.isEmpty { Text("কোনো পিন করা মেসেজ নেই").foregroundStyle(.secondary) } }
            .navigationTitle("পিন করা মেসেজ")
            .toolbar { cancelToolbarItem("বন্ধ করুন") { dismiss() } }
            .task { messages = (try? await api.pinnedMessages(token: token)) ?? [] }
        }
    }
}

private struct RoomMessageSearchSheet: View {
    let token: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [RoomMessage] = []
    private let api: RoomAPIProtocol = RoomAPI()

    var body: some View {
        NavigationStack {
            List(results) { message in
                VStack(alignment: .leading) {
                    Text(message.senderName).font(.caption.bold())
                    Text(message.body ?? "").font(.caption)
                }
            }
            .searchable(text: $query)
            .onSubmit(of: .search) {
                Task { results = (try? await api.searchMessages(token: token, query: query)) ?? [] }
            }
            .navigationTitle("মেসেজ খুঁজুন")
            .toolbar { cancelToolbarItem("বন্ধ করুন") { dismiss() } }
        }
    }
}
