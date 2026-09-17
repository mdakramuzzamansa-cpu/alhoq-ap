import Foundation

@MainActor
final class AnonymousBoardViewModel: ObservableObject {
    @Published var identity: AnonIdentity?
    @Published var posts: [AnonPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: AnonymousAPIProtocol = AnonymousAPI()

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let identityResult = api.myIdentity()
            async let feedResult = api.feed(page: 1)
            let (identityValue, feedValue) = try await (identityResult, feedResult)
            identity = identityValue
            posts = feedValue.data ?? []
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }

    func regenerateIdentity() async {
        identity = try? await api.regenerateIdentity()
    }

    func deletePost(_ post: AnonPost) async {
        try? await api.deletePost(id: post.id)
        posts.removeAll { $0.id == post.id }
    }

    func toggleLike(_ post: AnonPost) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        guard let response = try? await api.togglePostLike(postId: post.id) else { return }
        posts[index].likedByMe = response.liked
        posts[index].likeCount = response.count
    }

    func addComment(to post: AnonPost, body: String, parentId: Int?) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        guard let comment = try? await api.storeComment(postId: post.id, body: body, parentId: parentId) else { return }
        if let parentId, let parentIndex = posts[index].comments.firstIndex(where: { $0.id == parentId }) {
            posts[index].comments[parentIndex].replies.append(comment)
        } else {
            posts[index].comments.append(comment)
        }
        posts[index].commentCount += 1
    }

    func deleteComment(_ comment: AnonComment, from post: AnonPost) async {
        try? await api.deleteComment(id: comment.id)
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].comments.removeAll { $0.id == comment.id }
        for i in posts[index].comments.indices {
            posts[index].comments[i].replies.removeAll { $0.id == comment.id }
        }
        posts[index].commentCount = max(0, posts[index].commentCount - 1)
    }

    func toggleCommentLike(_ comment: AnonComment, in post: AnonPost) async {
        guard let response = try? await api.toggleCommentLike(commentId: comment.id) else { return }
        guard let postIndex = posts.firstIndex(where: { $0.id == post.id }) else { return }
        if let ci = posts[postIndex].comments.firstIndex(where: { $0.id == comment.id }) {
            posts[postIndex].comments[ci].likedByMe = response.liked
            posts[postIndex].comments[ci].likeCount = response.count
        } else {
            for ci in posts[postIndex].comments.indices {
                if let ri = posts[postIndex].comments[ci].replies.firstIndex(where: { $0.id == comment.id }) {
                    posts[postIndex].comments[ci].replies[ri].likedByMe = response.liked
                    posts[postIndex].comments[ci].replies[ri].likeCount = response.count
                }
            }
        }
    }
}

@MainActor
final class AnonPostComposerViewModel: ObservableObject {
    @Published var bodyText = ""
    @Published var mediaFileURL: URL?
    @Published var isPosting = false
    @Published var errorMessage: String?
    @Published var didPost = false

    private let api: AnonymousAPIProtocol = AnonymousAPI()
    private let uploader = MediaUploader()

    var canPost: Bool {
        (!bodyText.trimmingCharacters(in: .whitespaces).isEmpty || mediaFileURL != nil) && !isPosting
    }

    func submit() async {
        guard canPost else { return }
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        var mediaURL: String?
        if let mediaFileURL {
            mediaURL = try? await uploader.upload(fileURL: mediaFileURL)
        }

        do {
            _ = try await api.createPost(CreateAnonPostRequest(body: bodyText.isEmpty ? nil : bodyText, attachmentUrl: mediaURL))
            didPost = true
        } catch {
            errorMessage = "পোস্ট করা যায়নি।"
        }
    }
}
