import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var combinedFeed: [FeedItem] = []
    @Published var videoFeed: [FeedPost] = []
    @Published var featuredListings: [Listing] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: FeedAPIProtocol
    init(api: FeedAPIProtocol = FeedAPI()) { self.api = api }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.homeFeed()
            featuredListings = response.featuredListings
            combinedFeed = response.combinedFeed.compactMap(\.asFeedItem)
            videoFeed = response.videoFeed
        } catch {
            errorMessage = "ফিড লোড করা যায়নি।"
        }
    }

    /// নিজে পোস্ট করার পর (web-এর মতোই) সাথে সাথে ফিডের উপরে বসিয়ে দেওয়া
    func prependPost(_ post: FeedPost) {
        combinedFeed.insert(.post(post), at: 0)
    }

    func removePost(id: Int) {
        combinedFeed.removeAll { if case .post(let p) = $0 { return p.id == id }; return false }
    }
}

@MainActor
final class PostComposerViewModel: ObservableObject {
    @Published var bodyText = ""
    @Published var mediaFileURL: URL?
    @Published var isUploadingMedia = false
    @Published var isPosting = false
    @Published var errorMessage: String?
    @Published var didPost = false
    @Published var createdPost: FeedPost?

    private let api: FeedAPIProtocol
    private let uploader = MediaUploader()

    init(api: FeedAPIProtocol = FeedAPI()) { self.api = api }

    var canPost: Bool {
        (!bodyText.trimmingCharacters(in: .whitespaces).isEmpty || mediaFileURL != nil) && !isPosting
    }

    func attachMedia(fileURL: URL) {
        mediaFileURL = fileURL
    }

    func submit() async {
        guard canPost else { return }
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        var mediaURL: String?
        if let mediaFileURL {
            isUploadingMedia = true
            mediaURL = try? await uploader.upload(fileURL: mediaFileURL)
            isUploadingMedia = false
            if mediaURL == nil {
                errorMessage = "মিডিয়া আপলোড ব্যর্থ হয়েছে।"
                return
            }
        }

        do {
            _ = try await api.createPost(CreatePostRequest(body: bodyText.isEmpty ? nil : bodyText, media: mediaURL))
            didPost = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "পোস্ট করা যায়নি।"
        }
    }
}

/// প্রতিটা ফিড কার্ডের like/comment/share স্টেট এখান থেকে ড্রাইভ হয় — Post/Listing দুটোতেই একই ভিউমডেল
@MainActor
final class EngagementViewModel: ObservableObject {
    let type: EngagementContentType
    let id: Int
    @Published var liked: Bool
    @Published var likeCount: Int
    @Published var commentCount: Int
    @Published var shareCount: Int
    @Published var comments: [FeedComment] = []
    @Published var isLoadingComments = false

    private let api: EngagementAPIProtocol
    init(type: EngagementContentType, id: Int, liked: Bool, likeCount: Int, commentCount: Int, shareCount: Int, api: EngagementAPIProtocol = EngagementAPI()) {
        self.type = type
        self.id = id
        self.liked = liked
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.shareCount = shareCount
        self.api = api
    }

    func toggleLike() async {
        // optimistic UI — সাথে সাথে বদলে দেখিয়ে, ব্যর্থ হলে ফিরিয়ে নেওয়া
        liked.toggle()
        likeCount += liked ? 1 : -1
        do {
            let response = try await api.toggleLike(type: type, id: id)
            liked = response.liked
            likeCount = response.count
        } catch {
            liked.toggle()
            likeCount += liked ? 1 : -1
        }
    }

    func loadComments() async {
        isLoadingComments = true
        defer { isLoadingComments = false }
        comments = (try? await api.comments(type: type, id: id)) ?? []
    }

    func postComment(body: String, parentId: Int? = nil) async {
        guard let response = try? await api.storeComment(type: type, id: id, body: body, parentId: parentId) else { return }
        commentCount = response.count
        if parentId == nil {
            comments.insert(response.comment, at: 0)
        } else {
            await loadComments()   // reply হলে ট্রি আবার rebuild করে আনাই সহজ
        }
    }

    func deleteComment(_ comment: FeedComment) async {
        guard let response = try? await api.deleteComment(id: comment.id) else { return }
        commentCount = response.count
        if response.wasTopLevel {
            comments.removeAll { $0.id == comment.id }
        } else {
            await loadComments()
        }
    }

    func share() async {
        shareCount = (try? await api.share(type: type, id: id)) ?? shareCount
    }
}
