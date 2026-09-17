import Foundation

@MainActor
final class RoomListViewModel: ObservableObject {
    @Published var created: [PrivateRoom] = []
    @Published var joined: [PrivateRoom] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let api: RoomAPIProtocol = RoomAPI()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.myRooms()
            created = response.created
            joined = response.joined
        } catch { errorMessage = "লোড করা যায়নি।" }
    }
}

@MainActor
final class RoomCreateViewModel: ObservableObject {
    @Published var name = ""
    @Published var isCreating = false
    @Published var errorMessage: String?
    @Published var createdRoom: CreateRoomResponse?
    private let api: RoomAPIProtocol = RoomAPI()

    func create() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isCreating = true
        defer { isCreating = false }
        do { createdRoom = try await api.createRoom(name: name) }
        catch { errorMessage = "রুম তৈরি করা যায়নি।" }
    }
}

/// zip: PIN দিয়ে join করা অথবা admin-এর অনুমোদনের জন্য request পাঠানো
@MainActor
final class RoomJoinViewModel: ObservableObject {
    let token: String
    @Published var room: PrivateRoom?
    @Published var pendingRequest = false
    @Published var pin = ""
    @Published var isVerifying = false
    @Published var errorMessage: String?
    @Published var didUnlock = false
    private let api: RoomAPIProtocol = RoomAPI()

    init(token: String) { self.token = token }

    func loadInfo() async {
        do {
            let info = try await api.joinInfo(token: token)
            room = info.room
            pendingRequest = info.pendingRequest
        } catch let error as APIError {
            if case .notFound = error { errorMessage = "রুম খুঁজে পাওয়া যায়নি অথবা মেয়াদ শেষ হয়ে গেছে।" }
            else { errorMessage = error.localizedDescription }
        } catch { errorMessage = "লোড করা যায়নি।" }
    }

    func verifyPin() async {
        isVerifying = true
        errorMessage = nil
        defer { isVerifying = false }
        do {
            try await api.verifyPin(token: token, pin: pin)
            didUnlock = true
        } catch let error as APIError {
            switch error {
            case .validation: errorMessage = "ভুল PIN। আবার চেষ্টা করুন।"
            default: errorMessage = error.localizedDescription
            }
        } catch { errorMessage = "যাচাই করা যায়নি।" }
    }

    func requestToJoin() async {
        do {
            _ = try await api.requestToJoin(token: token)
            pendingRequest = true
        } catch {
            errorMessage = "রিকোয়েস্ট পাঠানো যায়নি।"
        }
    }
}

/// রুম থ্রেড — chat + poll + pin একসাথে, ChatThreadViewModel-এর প্যাটার্ন অনুসরণ করে
@MainActor
final class RoomThreadViewModel: ObservableObject {
    let token: String
    @Published var room: PrivateRoom?
    @Published var me: RoomParticipant?
    @Published var plainPin: String?
    @Published var messages: [RoomMessage] = []
    @Published var composerText = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?

    private let api: RoomAPIProtocol = RoomAPI()
    private let uploader = MediaUploader()

    init(token: String) { self.token = token }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let detail = try await api.roomDetail(token: token)
            room = detail.room
            me = detail.me
            plainPin = detail.plainPin
            messages = try await api.messages(token: token)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }

    func sendText() async {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        composerText = ""
        await send(SendRoomMessageRequest(body: text, type: .text))
    }

    func sendImage(fileURL: URL) async {
        guard let url = try? await uploader.upload(fileURL: fileURL) else { return }
        await send(SendRoomMessageRequest(type: .image, attachmentUrl: url, attachmentName: fileURL.lastPathComponent))
    }

    func sendAnnouncement(text: String, silent: Bool) async {
        await send(SendRoomMessageRequest(body: text, type: .text, isAnnouncement: true, silent: silent))
    }

    private func send(_ request: SendRoomMessageRequest) async {
        isSending = true
        defer { isSending = false }
        do {
            let message = try await api.sendMessage(token: token, request)
            messages.append(message)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "মেসেজ পাঠানো যায়নি।"
        }
    }

    func editMessage(_ message: RoomMessage, newBody: String) async {
        guard let updated = try? await api.editMessage(token: token, messageId: message.id, body: newBody) else { return }
        replace(updated)
    }

    /// zip: "Delete for Everyone" — ৪৮ ঘণ্টার মধ্যে sender অথবা admin
    func deleteMessage(_ message: RoomMessage) async {
        guard let updated = try? await api.deleteMessage(token: token, messageId: message.id) else { return }
        replace(updated)
    }

    func pinMessage(_ message: RoomMessage, silent: Bool) async {
        try? await api.pinMessage(token: token, messageId: message.id, silent: silent)
    }

    func createPoll(question: String, options: [String], allowMultiple: Bool, silent: Bool) async {
        guard let message = try? await api.createPoll(
            token: token, CreatePollRequest(question: question, options: options, allowMultiple: allowMultiple, silent: silent)
        ) else { return }
        messages.append(message)
    }

    func vote(pollId: Int, optionIds: [Int]) async {
        guard let updatedPoll = try? await api.votePoll(token: token, pollId: pollId, optionIds: optionIds) else { return }
        if let index = messages.firstIndex(where: { $0.poll?.id == pollId }) {
            messages[index].poll = updatedPoll
        }
    }

    private func replace(_ updated: RoomMessage) {
        guard let index = messages.firstIndex(where: { $0.id == updated.id }) else { return }
        messages[index] = updated
    }
}

@MainActor
final class RoomParticipantsViewModel: ObservableObject {
    let token: String
    @Published var participants: [RoomParticipant] = []
    @Published var adminSeatsUsed = 0
    @Published var adminSeatsMax = 0
    @Published var myRole: RoomParticipant.Role = .member
    @Published var errorMessage: String?
    private let api: RoomAPIProtocol = RoomAPI()

    init(token: String) { self.token = token }

    var isAdmin: Bool { myRole == .owner || myRole == .admin }

    func load() async {
        do {
            let response = try await api.participants(token: token)
            participants = response.participants
            adminSeatsUsed = response.adminSeatsUsed
            adminSeatsMax = response.adminSeatsMax
            myRole = response.myRole
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }

    func kick(_ p: RoomParticipant) async { try? await api.kick(token: token, userId: p.userId); await load() }
    func block(_ p: RoomParticipant) async { try? await api.block(token: token, userId: p.userId); await load() }
    func unblock(_ p: RoomParticipant) async { try? await api.unblock(token: token, userId: p.userId); await load() }
    func promote(_ p: RoomParticipant) async {
        do { try await api.promote(token: token, userId: p.userId); await load() }
        catch let error as APIError { errorMessage = error.localizedDescription } // web: MAX_ADMINS ছাড়ালে 422/403
        catch {}
    }
    func demote(_ p: RoomParticipant) async { try? await api.demote(token: token, userId: p.userId); await load() }
}

@MainActor
final class RoomJoinRequestsViewModel: ObservableObject {
    let token: String
    @Published var requests: [RoomJoinRequestItem] = []
    private let api: RoomAPIProtocol = RoomAPI()
    init(token: String) { self.token = token }

    func load() async { requests = (try? await api.joinRequests(token: token)) ?? [] }
    func accept(_ r: RoomJoinRequestItem) async {
        try? await api.acceptJoinRequest(token: token, userId: r.userId)
        requests.removeAll { $0.userId == r.userId }
    }
    func reject(_ r: RoomJoinRequestItem) async {
        try? await api.rejectJoinRequest(token: token, userId: r.userId)
        requests.removeAll { $0.userId == r.userId }
    }
}

@MainActor
final class RoomSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [PrivateRoom] = []
    private let api: RoomAPIProtocol = RoomAPI()
    private var task: Task<Void, Never>?

    func queryChanged() {
        task?.cancel()
        guard !query.isEmpty else { results = []; return }
        task = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            results = (try? await api.searchRooms(query: query)) ?? []
        }
    }

    func requestToJoin(_ room: PrivateRoom) async {
        _ = try? await api.requestToJoin(token: room.token)
    }
}
