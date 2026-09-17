import SwiftUI
import PhotosUI

struct AnonymousBoardView: View {
    @StateObject private var viewModel = AnonymousBoardViewModel()
    @State private var showComposer = false

    var body: some View {
        ScrollView {
            if let identity = viewModel.identity {
                identityCard(identity)
            }
            LazyVStack(spacing: 12) {
                ForEach(viewModel.posts) { post in
                    AnonPostCard(post: post, viewModel: viewModel)
                }
            }
            .padding(.horizontal)
        }
        .overlay { if viewModel.isLoading { ProgressView() } }
        .navigationTitle("Anonymous")
        .toolbar {
            toolbarItem(placement: .topBarTrailing) {
                Button { showComposer = true } label: { Image(systemName: "square.and.pencil") }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showComposer, onDismiss: { Task { await viewModel.load() } }) {
            AnonPostComposerView()
        }
    }

    private func identityCard(_ identity: AnonIdentity) -> some View {
        HStack {
            Circle().fill(Color(hex: identity.avatarColor)).frame(width: 40, height: 40)
                .overlay(Text(identity.avatarInitials).font(.caption.bold()).foregroundStyle(.white))
            VStack(alignment: .leading) {
                Text(identity.pseudonym).font(.subheadline.bold())
                Text("এটাই আপনার Anonymous পরিচয় — শুধু আপনি জানেন এটা আপনার").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("রিসেট করুন") { Task { await viewModel.regenerateIdentity() } }.font(.caption)
        }
        .padding()
    }
}

private struct AnonPostCard: View {
    let post: AnonPost
    @ObservedObject var viewModel: AnonymousBoardViewModel
    @State private var showComments = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(Color(hex: post.identity.avatarColor)).frame(width: 32, height: 32)
                    .overlay(Text(post.identity.avatarInitials).font(.caption2.bold()).foregroundStyle(.white))
                VStack(alignment: .leading) {
                    Text(post.identity.pseudonym).font(.caption.bold())
                    Text(post.createdAt).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if post.isDeletableByMe {
                    Menu {
                        Button("ডিলিট করুন", role: .destructive) { showDeleteConfirm = true }
                    } label: { Image(systemName: "ellipsis") }
                }
            }
            if let body = post.body, !body.isEmpty { Text(body) }
            if post.type == .image {
                RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.15)).frame(height: 180)
            }
            HStack(spacing: 20) {
                Button { Task { await viewModel.toggleLike(post) } } label: {
                    Label("\(post.likeCount)", systemImage: post.likedByMe ? "heart.fill" : "heart")
                        .foregroundStyle(post.likedByMe ? .red : .primary)
                }
                Button { showComments = true } label: {
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showComments) { AnonCommentsSheet(post: post, viewModel: viewModel) }
        .confirmationDialog("পোস্ট ডিলিট করবেন?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("ডিলিট করুন", role: .destructive) { Task { await viewModel.deletePost(post) } }
        }
    }
}

private struct AnonCommentsSheet: View {
    let post: AnonPost
    @ObservedObject var viewModel: AnonymousBoardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newComment = ""
    @State private var replyingTo: AnonComment?

    private var currentPost: AnonPost {
        viewModel.posts.first { $0.id == post.id } ?? post
    }

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(currentPost.comments) { comment in
                        commentRow(comment, isReply: false)
                        ForEach(comment.replies) { reply in
                            commentRow(reply, isReply: true)
                        }
                    }
                }
                HStack {
                    if let replyingTo {
                        Text("@\(replyingTo.identity.pseudonym)-কে রিপ্লাই").font(.caption)
                        Button("✕") { self.replyingTo = nil }
                    }
                    TextField("কমেন্ট লিখুন", text: $newComment).textFieldStyle(.roundedBorder)
                    Button("পাঠান") {
                        Task {
                            await viewModel.addComment(to: post, body: newComment, parentId: replyingTo?.id)
                            newComment = ""; replyingTo = nil
                        }
                    }
                    .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }
            .navigationTitle("কমেন্ট")
            .toolbar { cancelToolbarItem("বন্ধ করুন") { dismiss() } }
        }
    }

    private func commentRow(_ comment: AnonComment, isReply: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(comment.identity.pseudonym).font(.caption.bold())
                Text(comment.body).font(.caption)
                HStack {
                    Button {
                        Task { await viewModel.toggleCommentLike(comment, in: post) }
                    } label: {
                        Label("\(comment.likeCount)", systemImage: comment.likedByMe ? "heart.fill" : "heart")
                    }
                    .font(.caption2)
                    if !isReply {
                        Button("রিপ্লাই") { replyingTo = comment }.font(.caption2)
                    }
                    if comment.isDeletableByMe {
                        Button("ডিলিট") { Task { await viewModel.deleteComment(comment, from: post) } }
                            .font(.caption2).foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.leading, isReply ? 24 : 0)
    }
}

struct AnonPostComposerView: View {
    @StateObject private var viewModel = AnonPostComposerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var mediaItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                TextField("সম্পূর্ণ Anonymous ভাবে কিছু লিখুন…", text: $viewModel.bodyText, axis: .vertical)
                    .lineLimit(4...10)
                PhotosPicker(selection: $mediaItem, matching: .any(of: [.images, .videos])) {
                    Text(viewModel.mediaFileURL == nil ? "ছবি/ভিডিও যোগ করুন" : "মিডিয়া যোগ হয়েছে ✅")
                }
                .onChange(of: mediaItem) { _, item in
                    guard let item else { return }
                    Task {
                        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                        try? data.write(to: tempURL)
                        viewModel.mediaFileURL = tempURL
                    }
                }
                if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
                Button {
                    Task { await viewModel.submit(); if viewModel.didPost { dismiss() } }
                } label: {
                    if viewModel.isPosting { ProgressView().frame(maxWidth: .infinity) } else { Text("Anonymous পোস্ট করুন").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canPost)
            }
            .navigationTitle("নতুন Anonymous পোস্ট")
            .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
        }
    }
}

private extension Color {
    /// zip: avatar_color হেক্স স্ট্রিং হিসেবে আসে ("#RRGGBB")
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
