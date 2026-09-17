import Foundation

/// zip: `AlhoqSetting::availablePaymentMethods()` — শুধু নাম না, প্রতিটা মাধ্যমের আসল
/// রিসিভিং নম্বর/QR/ব্যাংক ডিটেইলও থাকে, যেটা ছাড়া ইউজার টাকা কোথায় পাঠাবে তা জানতেই পারবে না।
/// এটা zip আরও গভীরে চেক করে ধরা পড়েছে — আগে শুধু method নাম হার্ডকোড করা ছিল, রিসিভিং তথ্য ছিল না।
struct PaymentMethodInfo: Decodable, Identifiable, Hashable {
    let key: String              // "bkash" | "nagad" | "rocket" | "bank_transfer"
    let label: String
    let number: String?
    let qrPath: String?
    let bankName: String?
    let accountName: String?
    let routingNumber: String?

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, label, number
        case qrPath = "qr_path"
        case bankName = "bank_name"
        case accountName = "account_name"
        case routingNumber = "routing_number"
    }
}
