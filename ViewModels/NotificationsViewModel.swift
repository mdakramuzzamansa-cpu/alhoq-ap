import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: NotificationAPIProtocol
    private var pollTask: Task<Void, Never>?

    init(api: NotificationAPIProtocol = NotificationAPI()) {
        self.api = api
    }

    /// zip কমেন্ট নিজেই বলছে: bell badge মূলত Pusher push দিয়ে আপডেট হয়, আর poll করা হয় শুধু
    /// "safety net" হিসেবে যদি কোনো socket event miss হয়ে যায়। যেহেতু iOS-এ এখনো socket layer
    /// নেই (Chat Phase-এও একই নোট দেওয়া হয়েছিল), এখানে poll-ই একমাত্র mechanism —
    /// socket layer বসলে এই ইন্টারভাল কমিয়ে "safety net"-এ নামিয়ে আনতে হবে।
    func startPolling() {
        stopPolling()
        pollTask = Task {
            while !Task.isCancelled {
                await refreshBadge()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // ৩০ সেকেন্ড
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refreshBadge() async {
        unreadCount = (try? await api.unreadCount()) ?? unreadCount
    }

    func loadFullList() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let envelope = try await api.list(page: 1)
            notifications = envelope.data ?? []
            // web: ফুল লিস্ট খোলাটাই "দেখে ফেলেছে" সিগন্যাল — সার্ভার-সাইড mark হয়ে যায়,
            // তাই লোকাল badge-ও সাথে সাথে ০ করে দেওয়া
            unreadCount = 0
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }

    /// ফেরত দেয় deep-link url টা, যাতে caller নেভিগেট করতে পারে
    func open(_ notification: AppNotification) async -> String? {
        let url = try? await api.open(id: notification.id)
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].unread = false
        }
        return url ?? notification.url
    }

    func markAllRead() async {
        try? await api.markAllRead()
        for index in notifications.indices { notifications[index].unread = false }
        unreadCount = 0
    }

    func delete(_ notification: AppNotification) async {
        try? await api.delete(id: notification.id)
        notifications.removeAll { $0.id == notification.id }
    }

    func deleteAll() async {
        try? await api.deleteAll()
        notifications.removeAll()
    }
}
