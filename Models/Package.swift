import Foundation

/// zip: app/Models/Package.php
struct SubscriptionPackage: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var name: String
    var description: String?
    var price: Double
    var durationDays: Int
    var listingLimit: Int
    var featuredCount: Int?
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description, price
        case durationDays = "duration_days"
        case listingLimit = "listing_limit"
        case featuredCount = "featured_count"
        case isActive = "is_active"
    }
}

/// zip: app/Models/UserPackage.php — CheckoutController::fulfillPackage() যা তৈরি করে
struct UserPackage: Codable, Identifiable, Equatable {
    let id: Int
    var packageId: Int
    var package: SubscriptionPackage?
    var listingsUsed: Int
    var featuredUsed: Int
    var startsAt: Date
    var expiresAt: Date
    var status: String   // "active" ইত্যাদি
    var amountPaid: Double

    enum CodingKeys: String, CodingKey {
        case id
        case packageId = "package_id"
        case package
        case listingsUsed = "listings_used"
        case featuredUsed = "featured_used"
        case startsAt = "starts_at"
        case expiresAt = "expires_at"
        case status
        case amountPaid = "amount_paid"
    }
}

/// zip: routes/web.php-এ কনফার্ম হওয়া আসল পাথ — CheckoutController Stripe Checkout Session
/// তৈরি করে redirect() করে, যেটা session-cookie-ভিত্তিক web route (API না)। তাই iOS-এর জন্য
/// একটা API endpoint লাগবে যেটা একই Stripe session তৈরি করে JSON-এ checkout_url ফেরত দেয়।
///
/// ⚠️ ASSUMPTION: এরকম একটা API endpoint এখনো backend-এ নেই ধরে নিচ্ছি (web শুধু redirect করে) —
/// Android team-কে backend-এ POST /api/v1/checkout/packages/{id} (ও bookings সংস্করণ) যোগ
/// করতে হবে যা `{checkout_url, session_id}` ফেরত দেয়। যতক্ষণ না এটা কনফার্ম হয়, path নাম
/// অনুমানভিত্তিক রাখা হলো (নিচের CheckoutAPI.swift-এ)।
struct CheckoutSessionResponse: Decodable {
    let checkoutUrl: String
    let sessionId: String
    enum CodingKeys: String, CodingKey {
        case checkoutUrl = "checkout_url"
        case sessionId = "session_id"
    }
}

/// zip: routes/web.php কনফার্ম করা path গুলো — WKWebView navigation-এ এগুলোর সাথে মিলিয়ে
/// success/cancel শনাক্ত করা হয় (এগুলো ওয়েব ডোমেইনেই, /api/v1-এর বাইরে)
enum CheckoutWebRoutes {
    static let packageSuccessPath = "/checkout/success"
    static let packageCancelPath = "/checkout/cancel"
    static func bookingSuccessPath(bookingId: Int) -> String { "/checkout/booking/\(bookingId)/success" }
    static func bookingCancelPath(bookingId: Int) -> String { "/checkout/booking/\(bookingId)/cancel" }
}
