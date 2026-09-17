import Foundation

@MainActor
final class ChatThreadViewModel: ObservableObject {
    let conversationId: Int

    @Published var messages: [ChatMessage] = []
    @Published var otherId: Int = 0
    @Published var otherName: String = ""
    @Published var otherAvatar: String?
    @Published var otherOnline = false
    @Published var otherStatusLabel: String?
    @Published var otherCallsEnabled = false
    @Published var otherTyping = false
    @Published var isBlocked = false
    @Published var hasMoreOlder = false
    @Published var isLoadingInitial = false
    @Published var isLoadingOlder = false
    @Published var composerText: String = ""
    @Published var isSending = false
    @Published var isUploadingAttachment = false
    @Published var errorMessage: String?

    private let api: ChatAPIProtocol
    private let uploader: MediaUploader

    init(conversationId: Int, api: ChatAPIProtocol = ChatAPI(), uploader: MediaUploader? = nil) {
        self.conversationId = conversationId
        self.api = api
        self.uploader = uploader ?? MediaUploader()
    }

    func loadInitial() async {
        isLoadingInitial = true
        errorMessage = nil
        defer { isLoadingInitial = false }
        do {
            let thread = try await api.thread(conversationId: conversationId)
            otherId = thread.otherId
            otherName = thread.otherName
            otherAvatar = thread.otherAvatar
            otherOnline = thread.otherOnline
            otherStatusLabel = thread.otherStatusLabel
            otherCallsEnabled = thread.otherCallsEnabled
            otherTyping = thread.otherTyping
            isBlocked = thread.blocked
            messages = thread.messages
            hasMoreOlder = thread.hasMore
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "থ্রেড লোড করা যায়নি।"
        }
    }

    /// Section 8: "Load older messages" — উপরে স্ক্রল করলে কল হবে
    func loadOlder() async {
        guard hasMoreOlder, !isLoadingOlder, let oldestId = messages.first?.id else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let response = try await api.olderMessages(conversationId: conversationId, beforeId: oldestId)
            messages = response.messages + messages
            hasMoreOlder = response.hasMore
        } catch {
            // web: silently just stops offering more — এখানেও একই আচরণ, নতুন এরর ব্যানার দেখানো হচ্ছে না
        }
    }

    func sendText() async {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isBlocked else { return }
        composerText = ""
        await send(SendMessageRequest(body: text, type: .text))
    }

    /// web: attachment_url আসলে Cloudinary secure_url — mime দেখে server নিজেই type ঠিক করে,
    /// কিন্তু image/file স্পষ্টভাবে পাঠানোই ভালো (Rule অনুযায়ী client নিজে থেকে গোপন না রেখে explicit থাকা)
    func sendImage(fileURL: URL) async {
        isUploadingAttachment = true
        defer { isUploadingAttachment = false }
        do {
            let secureURL = try await uploader.upload(fileURL: fileURL)
            let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? nil
            await send(SendMessageRequest(
                type: .image, attachmentUrl: secureURL,
                attachmentName: fileURL.lastPathComponent, attachmentSize: size, attachmentMime: "image/jpeg"
            ))
        } catch {
            errorMessage = "ছবি পাঠানো যায়নি।"
        }
    }

    func sendFile(fileURL: URL) async {
        isUploadingAttachment = true
        defer { isUploadingAttachment = false }
        do {
            let secureURL = try await uploader.upload(fileURL: fileURL)
            let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? nil
            await send(SendMessageRequest(
                type: .file, attachmentUrl: secureURL,
                attachmentName: fileURL.lastPathComponent, attachmentSize: size
            ))
        } catch {
            errorMessage = "ফাইল পাঠানো যায়নি।"
        }
    }

    func sendVoice(fileURL: URL, durationSeconds: Int) async {
        isUploadingAttachment = true
        defer { isUploadingAttachment = false }
        do {
            let secureURL = try await uploader.upload(fileURL: fileURL)
            await send(SendMessageRequest(type: .voice, attachmentUrl: secureURL, durationSeconds: durationSeconds))
        } catch {
            errorMessage = "ভয়েস মেসেজ পাঠানো যায়নি।"
        }
    }

    func sendLocation(latitude: Double, longitude: Double) async {
        await send(SendMessageRequest(type: .location, latitude: latitude, longitude: longitude))
    }

    private func send(_ request: SendMessageRequest) async {
        isSending = true
        defer { isSending = false }
        do {
            let message = try await api.send(conversationId: conversationId, request)
            messages.append(message)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "মেসেজ পাঠানো যায়নি।"
        }
    }

    func editMessage(_ message: ChatMessage, newBody: String) async {
        guard let updated = try? await api.editMessage(conversationId: conversationId, messageId: message.id, body: newBody) else { return }
        replaceMessage(updated)
    }

    func deleteMessage(_ message: ChatMessage, scope: DeleteScope) async {
        try? await api.deleteMessage(conversationId: conversationId, messageId: message.id, scope: scope)
        if scope == .everyone {
            // web: content খালি হয়ে "deleted" placeholder থাকে, মেসেজ সরে যায় না
            var updated = message
            updated.isDeleted = true
            updated.body = ""
            replaceMessage(updated)
        } else {
            messages.removeAll { $0.id == message.id }
        }
    }

    func togglePin(_ message: ChatMessage) async {
        let updated = message.pinnedAt == nil
            ? try? await api.pinMessage(conversationId: conversationId, messageId: message.id)
            : try? await api.unpinMessage(conversationId: conversationId, messageId: message.id)
        if let updated { replaceMessage(updated) }
    }

    func forward(_ message: ChatMessage, toConversationIds: [Int]) async {
        try? await api.forwardMessage(conversationId: conversationId, messageId: message.id, toConversationIds: toConversationIds)
    }

    func report(_ message: ChatMessage, reason: String?) async {
        try? await api.reportMessage(conversationId: conversationId, messageId: message.id, reason: reason)
    }

    func notifyTyping() {
        Task { try? await api.sendTyping(conversationId: conversationId) }
    }

    private func replaceMessage(_ updated: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == updated.id }) else { return }
        messages[index] = updated
    }
}
