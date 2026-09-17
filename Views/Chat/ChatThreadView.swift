import SwiftUI
import PhotosUI
import CoreLocation

struct ChatThreadView: View {
    @StateObject private var viewModel: ChatThreadViewModel
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var editingMessage: ChatMessage?
    @State private var editText: String = ""
    @State private var reportingMessage: ChatMessage?
    @State private var reportReason: String = ""

    init(conversationId: Int) {
        _viewModel = StateObject(wrappedValue: ChatThreadViewModel(conversationId: conversationId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.hasMoreOlder {
                        Button {
                            Task { await viewModel.loadOlder() }
                        } label: {
                            if viewModel.isLoadingOlder { ProgressView() } else { Text("আরও পুরনো মেসেজ") }
                        }
                        .padding()
                    }

                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                                .contextMenu {
                                    if message.isMine && message.type == .text && !message.isDeleted {
                                        Button("এডিট করুন") {
                                            editingMessage = message
                                            editText = message.body
                                        }
                                    }
                                    Button(message.pinnedAt == nil ? "পিন করুন" : "আনপিন করুন") {
                                        Task { await viewModel.togglePin(message) }
                                    }
                                    if !message.isMine {
                                        Button("রিপোর্ট করুন", role: .destructive) {
                                            reportingMessage = message
                                        }
                                    }
                                    if message.isMine && !message.isDeleted {
                                        Button("সবার জন্য ডিলিট", role: .destructive) {
                                            Task { await viewModel.deleteMessage(message, scope: .everyone) }
                                        }
                                    }
                                    Button("আমার জন্য ডিলিট", role: .destructive) {
                                        Task { await viewModel.deleteMessage(message, scope: .me) }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if viewModel.otherTyping {
                Text("\(viewModel.otherName) লিখছে…").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            }

            if viewModel.isBlocked {
                Text("এই ইউজারকে ব্লক করা আছে — মেসেজ পাঠানো যাবে না।")
                    .font(.caption).foregroundStyle(.red).padding()
            } else {
                composer
            }
        }
        .navigationTitle(viewModel.otherName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.otherCallsEnabled {
                toolbarItemGroup(placement: .topBarTrailing) {
                    Button { Task { await CallManager.shared.startCall(userId: viewModel.otherId, type: .voice) } } label: {
                        Image(systemName: "phone")
                    }
                    Button { Task { await CallManager.shared.startCall(userId: viewModel.otherId, type: .video) } } label: {
                        Image(systemName: "video")
                    }
                }
            }
        }
        .task { await viewModel.loadInitial() }
        .alert("মেসেজ এডিট করুন", isPresented: Binding(get: { editingMessage != nil }, set: { if !$0 { editingMessage = nil } })) {
            TextField("মেসেজ", text: $editText)
            Button("সেভ") {
                if let message = editingMessage {
                    Task { await viewModel.editMessage(message, newBody: editText) }
                }
            }
            Button("বাতিল", role: .cancel) {}
        }
        .alert("মেসেজ রিপোর্ট করুন", isPresented: Binding(get: { reportingMessage != nil }, set: { if !$0 { reportingMessage = nil } })) {
            TextField("কারণ (ঐচ্ছিক)", text: $reportReason)
            Button("রিপোর্ট করুন", role: .destructive) {
                if let message = reportingMessage {
                    Task { await viewModel.report(message, reason: reportReason.isEmpty ? nil : reportReason) }
                }
                reportReason = ""
            }
            Button("বাতিল", role: .cancel) {}
        }
    }

    private var composer: some View {
        VStack(spacing: 4) {
            if let error = viewModel.errorMessage {
                Text(error).font(.caption2).foregroundStyle(.red)
            }
            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedImageItem, matching: .images) {
                    Image(systemName: "photo")
                }
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
                    .onChange(of: viewModel.composerText) { _, _ in viewModel.notifyTyping() }

                if viewModel.isUploadingAttachment {
                    ProgressView()
                } else {
                    Button {
                        Task { await viewModel.sendText() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(viewModel.composerText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
                }
            }
            .padding()
        }
        .background(.thinMaterial)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: 40) }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                if message.isForwarded, let name = message.forwardedFromName {
                    Text("Forwarded from \(name)").font(.caption2).foregroundStyle(.secondary)
                }
                if message.pinnedAt != nil {
                    Label("পিন করা", systemImage: "pin.fill").font(.caption2).foregroundStyle(.secondary)
                }

                Group {
                    if message.isDeleted {
                        Text("এই মেসেজটি মুছে ফেলা হয়েছে").italic().foregroundStyle(.secondary)
                    } else {
                        content
                    }
                }
                .padding(10)
                .background(message.isMine ? Color.accentColor : Color.gray.opacity(0.15))
                .foregroundStyle(message.isMine ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 4) {
                    if message.isEdited { Text("edited").font(.caption2).foregroundStyle(.secondary) }
                    Text(message.createdAt).font(.caption2).foregroundStyle(.secondary)
                    if message.isMine {
                        Image(systemName: message.read ? "checkmark.circle.fill" : (message.delivered ? "checkmark.circle" : "clock"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !message.isMine { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch message.type {
        case .text:
            Text(message.body)
        case .image:
            // TODO: AsyncImage(url: URL(string: message.attachmentUrl ?? ""))
            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3)).frame(width: 160, height: 120)
        case .file:
            Label(message.attachmentName ?? "File", systemImage: "doc")
        case .voice:
            Label(message.duration ?? "Voice", systemImage: "waveform")
        case .location:
            // TODO: message.mapPreviewUrl / mapLink দিয়ে MapKit snapshot বসানো
            Label("Location shared", systemImage: "mappin.and.ellipse")
        }
    }
}
