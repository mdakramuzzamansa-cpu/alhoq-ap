import Foundation

// MARK: - Standard API envelope
// Build-plan Section 1.2 বলছে প্রতিটা API response-এ থাকতে হবে:
// success / message / data / validation errors / pagination / authorization result / status.
//
// ⚠️ ASSUMPTION (দয়া করে যাচাই করুন):
// Android চ্যাটে যে Sanctum + /api/v1/auth/... বানানো হয়েছে, তার আসল JSON shape আমি দেখিনি।
// নিচের কাঠামোটা Laravel-এ সবচেয়ে প্রচলিত প্যাটার্ন অনুযায়ী ধরে নেওয়া হয়েছে।
// আসল response এর সাথে key-এর নাম না মিললে শুধু এই ফাইলের CodingKeys বদলালেই চলবে —
// বাকি পুরো অ্যাপের কোনো জায়গায় হাত দিতে হবে না।

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let message: String?
    let data: T?
    let errors: [String: [String]]?      // Laravel validation error bag: { "field": ["message"] }
    let pagination: Pagination?
    let status: String?

    struct Pagination: Decodable {
        let currentPage: Int?
        let lastPage: Int?
        let perPage: Int?
        let total: Int?

        enum CodingKeys: String, CodingKey {
            case currentPage = "current_page"
            case lastPage = "last_page"
            case perPage = "per_page"
            case total
        }
    }
}

// MARK: - Empty payload helper (for endpoints that return only success/message, e.g. logout)
struct EmptyData: Decodable {}

// MARK: - App-level error type surfaced to ViewModels/Views
enum APIError: LocalizedError {
    case validation([String: [String]])
    case unauthorized
    case forbidden
    case notFound
    case sessionExpired
    case server(String)
    case network(URLError)
    case decoding
    case unknown

    var errorDescription: String? {
        switch self {
        case .validation(let errors):
            return errors.values.first?.first ?? "ইনপুট সঠিক নয়়।"
        case .unauthorized:
            return "ইমেইল/ফোন অথবা পাসওয়ার্ড সঠিক নয়।"
        case .forbidden:
            return "এই কাজের অনুমতি আপনার নেই।"
        case .notFound:
            return "তথ্য খুঁজে পাওয়া যায়নি।"
        case .sessionExpired:
            return "সেশনের মেয়াদ শেষ — আবার লগইন করুন।"
        case .server(let message):
            return message
        case .network:
            return "ইন্টারনেট সংযোগ পাওয়া যাচ্ছে না।"
        case .decoding:
            return "সার্ভার থেকে অপ্রত্যাশিত রেসপন্স এসেছে।"
        case .unknown:
            return "কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।"
        }
    }

    /// লগইন স্ক্রিনে field-ভিত্তিক এরর দেখানোর জন্য (Section 4.2/4.3 parity: প্রতিটা field-এর নিচে ভুল দেখাতে হবে)
    var fieldErrors: [String: [String]] {
        if case .validation(let errors) = self { return errors }
        return [:]
    }
}
