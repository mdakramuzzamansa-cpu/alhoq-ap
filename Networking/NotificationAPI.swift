import Foundation

/// ⚠️ ASSUMPTION (আগের সব Phase-এর মতোই): path গুলো অনুমানভিত্তিক।
protocol NotificationAPIProtocol {
    func list(page: Int) async throws -> APIEnvelope<[AppNotification]>
    func unreadCount() async throws -> Int
    func bellItems() async throws -> [AppNotification]
    func open(id: String) async throws -> String?   // ফেরত: notification.url, নেভিগেট করার জন্য
    func markAllRead() async throws
    func delete(id: String) async throws
    func deleteAll() async throws
}

final class NotificationAPI: NotificationAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func list(page: Int) async throws -> APIEnvelope<[AppNotification]> {
        try await client.request("notifications", query: ["page": String(page)])
    }

    func unreadCount() async throws -> Int {
        struct Response: Decodable { let count: Int }
        let envelope: APIEnvelope<Response> = try await client.request("notifications/unread-count")
        return envelope.data?.count ?? 0
    }

    func bellItems() async throws -> [AppNotification] {
        let envelope: APIEnvelope<[AppNotification]> = try await client.request("notifications/bell-items")
        return envelope.data ?? []
    }

    func open(id: String) async throws -> String? {
        struct Response: Decodable { let url: String? }
        let envelope: APIEnvelope<Response> = try await client.request("notifications/\(id)/open", method: .post)
        return envelope.data?.url
    }

    func markAllRead() async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("notifications/mark-all-read", method: .post)
    }

    func delete(id: String) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("notifications/\(id)", method: .delete)
    }

    func deleteAll() async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("notifications", method: .delete)
    }
}

/// ❌ web-এর `PushSubscriptionController` আসলে **Web Push (VAPID, endpoint+p256dh+auth key)** —
/// এটা শুধু ব্রাউজারের জন্য, iOS-এর কোনো কাজে লাগবে না। iOS-এর জন্য লাগে APNs device token,
/// যেটার জন্য backend-এ সম্পূর্ণ নতুন endpoint লাগবে (Android team-এর সাথে আগে যেমন Checkout-এর
/// জন্য একটা নতুন endpoint দরকার হয়েছিল, এখানেও তাই)।
///
/// ⚠️ ASSUMPTION: নিচের path ধরে নেওয়া হয়েছে backend-এ APNs-নির্দিষ্ট endpoint যোগ হবে ধরে।
protocol PushTokenAPIProtocol {
    func registerDeviceToken(_ token: String) async throws
    func unregisterDeviceToken(_ token: String) async throws
}

final class PushTokenAPI: PushTokenAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func registerDeviceToken(_ token: String) async throws {
        struct Body: Encodable { let deviceToken: String; let platform = "ios"
            enum CodingKeys: String, CodingKey { case deviceToken = "device_token"; case platform }
        }
        let _: APIEnvelope<EmptyData> = try await client.request(
            "push/apns-token", method: .post, body: Body(deviceToken: token)
        )
    }

    func unregisterDeviceToken(_ token: String) async throws {
        struct Body: Encodable { let deviceToken: String
            enum CodingKeys: String, CodingKey { case deviceToken = "device_token" }
        }
        let _: APIEnvelope<EmptyData> = try await client.request(
            "push/apns-token", method: .delete, body: Body(deviceToken: token)
        )
    }
}
