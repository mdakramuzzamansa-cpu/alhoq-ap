import Foundation

protocol CheckoutAPIProtocol {
    func packages() async throws -> [SubscriptionPackage]
    func activePackage() async throws -> UserPackage?
    func startPackageCheckout(packageId: Int) async throws -> CheckoutSessionResponse
    func startBookingCheckout(bookingId: Int) async throws -> CheckoutSessionResponse
    /// web-এর success() হ্যান্ডলার সরাসরি Stripe থেকে ভেরিফাই করে UserPackage/Booking ফেরত দেয় —
    /// WKWebView success পাথে পৌঁছালে sessionId দিয়ে iOS-ও একই fulfillment confirm করবে
    func confirmPackageFulfillment(sessionId: String) async throws -> UserPackage?
    func confirmBookingFulfillment(bookingId: Int, sessionId: String) async throws -> Booking?
}

final class CheckoutAPI: CheckoutAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func packages() async throws -> [SubscriptionPackage] {
        let envelope: APIEnvelope<[SubscriptionPackage]> = try await client.request("packages", authenticated: false)
        return envelope.data ?? []
    }

    func activePackage() async throws -> UserPackage? {
        let envelope: APIEnvelope<UserPackage> = try await client.request("packages/active")
        return envelope.data
    }

    func startPackageCheckout(packageId: Int) async throws -> CheckoutSessionResponse {
        let envelope: APIEnvelope<CheckoutSessionResponse> = try await client.request(
            "checkout/packages/\(packageId)", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func startBookingCheckout(bookingId: Int) async throws -> CheckoutSessionResponse {
        let envelope: APIEnvelope<CheckoutSessionResponse> = try await client.request(
            "checkout/bookings/\(bookingId)", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func confirmPackageFulfillment(sessionId: String) async throws -> UserPackage? {
        let envelope: APIEnvelope<UserPackage> = try await client.request(
            "checkout/confirm", query: ["session_id": sessionId]
        )
        return envelope.data
    }

    func confirmBookingFulfillment(bookingId: Int, sessionId: String) async throws -> Booking? {
        let envelope: APIEnvelope<Booking> = try await client.request(
            "checkout/bookings/\(bookingId)/confirm", query: ["session_id": sessionId]
        )
        return envelope.data
    }
}
