import SwiftUI
import PhotosUI

struct FeedView: View {
    let currentUserId: Int
    @StateObject private var viewModel = FeedViewModel()
    @State private var tab = 0
    @State private var showComposer = false

    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $tab) {
                    Text("পোস্ট/লিস্টিং").tag(0)
                    Text("ভিডিও").tag(1)
                }
                .pickerStyle(.segmented).padding(.horizontal)

                if tab == 0 {
                    combinedList
                } else {
                    VideoFeedView(posts: viewModel.videoFeed)
                }
            }
            .navigationTitle("ফিড")
            .toolbar {
                toolbarItem(placement: .topBarTrailing) {
                    Button { showComposer = true } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .task { await viewModel.load() }
            .sheet(isPresented: $showComposer) {
                PostComposerView { post in viewModel.prependPost(post) }
            }
        }
    }

    private var combinedList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.combinedFeed) { item in
                    FeedCardView(item: item, currentUserId: currentUserId, onDeletePost: { id in viewModel.removePost(id: id) })
                }
            }
            .padding(.horizontal)
        }
        .overlay { if viewModel.isLoading { ProgressView() } }
        .refreshable { await viewModel.load() }
    }
}

struct FeedCardView: View {
    let item: FeedItem
    let currentUserId: Int
    let onDeletePost: (Int) -> Void
    @StateObject private var engagement: EngagementViewModel
    @State private var showComments = false
    @State private var showDeleteConfirm = false
    @State private var shareURL: URL?

    init(item: FeedItem, currentUserId: Int, onDeletePost: @escaping (Int) -> Void) {
        self.item = item
        self.currentUserId = currentUserId
        self.onDeletePost = onDeletePost
        switch item {
        case .listing(let listing):
            _engagement = StateObject(wrappedValue: EngagementViewModel(
                type: .listing, id: listing.id, liked: false, likeCount: 0, commentCount: 0, shareCount: 0
            ))
        case .post(let post):
            _engagement = StateObject(wrappedValue: EngagementViewModel(
                type: .post, id: post.id, liked: post.likedByMe, likeCount: post.likesCount,
                commentCount: post.commentsCount, shareCount: post.sharesCount
            ))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch item {
            case .listing(let listing):
                NavigationLink {
                    ListingDetailView(slug: listing.slug)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(listing.title).font(.subheadline.bold())
                        if let price = listing.price { Text("৳\(Int(price))").foregroundStyle(.green) }
                    }
                }
                .foregroundStyle(.primary)

            case .post(let post):
                HStack {
                    NavigationLink {
                        SellerProfileView(userId: post.user.id)
                    } label: {
                        HStack {
                            Circle().fill(Color.gray.opacity(0.3)).frame(width: 36, height: 36)
                            VStack(alignment: .leading) {
                                Text(post.user.name).font(.subheadline.bold())
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    Spacer()
                    if post.user.id == currentUserId {
                        Menu {
                            Button("ডিলিট করুন", role: .destructive) { showDeleteConfirm = true }
                        } label: { Image(systemName: "ellipsis") }
                    }
                }
                if let body = post.body { Text(body) }
                if post.mediaType == .photo {
                    RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.15)).frame(height: 200)
                }
            }

            HStack(spacing: 20) {
                Button {
                    Task { await engagement.toggleLike() }
                } label: {
                    Label("\(engagement.likeCount)", systemImage: engagement.liked ? "heart.fill" : "heart")
                        .foregroundStyle(engagement.liked ? .red : .primary)
                }
                Button { showComments = true } label: {
                    Label("\(engagement.commentCount)", systemImage: "bubble.right")
                }
                Button {
                    Task {
                        await engagement.share()
                        // zip: root PostController@show হলো এই permalink-এর টার্গেট, listing-এর
                        // জন্য listings/{slug}
                        switch item {
                        case .post(let post):
                            shareURL = APIConfig.webBaseURL.appendingPathComponent("posts/\(post.id)")
                        case .listing(let listing):
                            shareURL = APIConfig.webBaseURL.appendingPathComponent("listings/\(listing.slug)")
                        }
                    }
                } label: {
                    Label("\(engagement.shareCount)", systemImage: "arrowshape.turn.up.right")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showComments) { CommentsSheet(engagement: engagement) }
        .sheet(item: Binding(get: { shareURL.map { IdentifiableURL(url: $0) } }, set: { shareURL = $0?.url })) { item in
            ShareSheet(items: [item.url])
        }
        .confirmationDialog("পোস্ট ডিলিট করবেন?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("ডিলিট করুন", role: .destructive) {
                if case .post(let post) = item {
                    Task { try? await FeedAPI().deletePost(id: post.id); onDeletePost(post.id) }
                }
            }
        }
    }
}

struct VideoFeedView: View {
    let posts: [FeedPost]

    var body: some View {
        TabView {
            ForEach(posts) { post in
                ZStack(alignment: .bottom) {
                    // TODO: AVPlayer দিয়ে post.mediaPath থেকে ভিডিও অটোপ্লে বসাতে হবে
                    Color.black
                    VStack(alignment: .leading, spacing: 8) {
                        Text(post.user.name).font(.subheadline.bold()).foregroundStyle(.white)
                        if let body = post.body { Text(body).foregroundStyle(.white) }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .rotationEffect(.degrees(0))
        .ignoresSafeArea(edges: .bottom)
    }
}

struct PostComposerView: View {
    @StateObject private var viewModel = PostComposerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var mediaItem: PhotosPickerItem?
    let onPosted: (FeedPost) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("কী মনে হচ্ছে?", text: $viewModel.bodyText, axis: .vertical)
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
                        viewModel.attachMedia(fileURL: tempURL)
                    }
                }
                if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
                Button {
                    Task { await viewModel.submit(); if viewModel.didPost { dismiss() } }
                } label: {
                    if viewModel.isPosting || viewModel.isUploadingMedia { ProgressView().frame(maxWidth: .infinity) } else { Text("পোস্ট করুন").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canPost)
            }
            .navigationTitle("নতুন পোস্ট")
            .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
        }
    }
}

struct CommentsSheet: View {
    @ObservedObject var engagement: EngagementViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newComment = ""
    @State private var replyingTo: FeedComment?

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(engagement.comments) { comment in
                        commentRow(comment, isReply: false)
                        ForEach(comment.replies) { reply in
                            commentRow(reply, isReply: true)
                        }
                    }
                }
                .overlay { if engagement.isLoadingComments { ProgressView() } }

                HStack {
                    if let replyingTo {
                        Text("@\(replyingTo.userName)-কে রিপ্লাই").font(.caption).foregroundStyle(.secondary)
                        Button("✕") { self.replyingTo = nil }.font(.caption)
                    }
                    TextField("কমেন্ট লিখুন", text: $newComment)
                        .textFieldStyle(.roundedBorder)
                    Button("পাঠান") {
                        Task {
                            await engagement.postComment(body: newComment, parentId: replyingTo?.topId)
                            newComment = ""
                            replyingTo = nil
                        }
                    }
                    .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }
            .navigationTitle("কমেন্ট")
            .toolbar { cancelToolbarItem("বন্ধ করুন") { dismiss() } }
            .task { await engagement.loadComments() }
        }
    }

    private func commentRow(_ comment: FeedComment, isReply: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(comment.userName).font(.caption.bold())
                    if let replyTo = comment.replyToName {
                        Text("→ \(replyTo)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text(comment.body).font(.caption)
                HStack {
                    Text(comment.createdAt).font(.caption2).foregroundStyle(.secondary)
                    Button("রিপ্লাই") { replyingTo = comment }.font(.caption2)
                    if comment.canDelete {
                        Button("ডিলিট") { Task { await engagement.deleteComment(comment) } }.font(.caption2).foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.leading, isReply ? 24 : 0)
    }
}
