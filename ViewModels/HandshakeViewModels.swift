import Foundation

@MainActor
final class HandshakesViewModel: ObservableObject {
    @Published var received: [Handshake] = []
    @Published var sent: [Handshake] = []
    @Published var connections: [Handshake] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: HandshakeAPIProtocol = HandshakeAPI()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.myHandshakes()
            received = response.received
            sent = response.sent
            connections = response.connections
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }

    func accept(_ handshake: Handshake) async {
        guard let updated = try? await api.accept(handshakeId: handshake.id) else { return }
        received.removeAll { $0.id == handshake.id }
        connections.insert(updated, at: 0)
    }

    func decline(_ handshake: Handshake) async {
        _ = try? await api.decline(handshakeId: handshake.id)
        received.removeAll { $0.id == handshake.id }
    }

    func disconnect(_ handshake: Handshake) async {
        try? await api.disconnect(handshakeId: handshake.id)
        connections.removeAll { $0.id == handshake.id }
    }
}

/// প্রোফাইল পেজের 🤝 বাটন থেকে কল হয় — টাইপ বেছে পাঠানো
@MainActor
final class SendHandshakeViewModel: ObservableObject {
    let userId: Int
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var sentSuccessfully = false

    private let api: HandshakeAPIProtocol = HandshakeAPI()
    init(userId: Int) { self.userId = userId }

    func send(type: Handshake.HandshakeType) async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            _ = try await api.send(userId: userId, type: type)
            sentSuccessfully = true
        } catch let error as APIError {
            // web: 409 — আগে থেকেই pending/accepted Handshake থাকলে
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Handshake পাঠানো যায়নি।"
        }
    }
}
