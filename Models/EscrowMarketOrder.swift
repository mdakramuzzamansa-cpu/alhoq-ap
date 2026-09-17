import Foundation

/// zip: app/Models/Escrow/EscrowOrder.php — `EscrowOrder::STATUSES` zip-এ চেক করে দেখা গেছে
/// Alhoq\Order-এর ২০-state lifecycle-এর সাথে হুবহু মিলে যায়, তাই AlhoqOrder.Status reuse করা
/// হচ্ছে — কিন্তু এটা **সম্পূর্ণ আলাদা সিস্টেম/টেবিল** (কমেন্টেই লেখা: "escrow is its own
/// destination, not a per-listing feature" বনাম marketplace-এর "any published listing from
/// ANY seller"), তাই মডেল/API/স্ক্রিন আলাদা রাখা হলো যাতে দুটো সিস্টেম গুলিয়ে না যায়।
struct EscrowMarketOrder: Codable, Identifiable, Equatable {
    let id: Int
    var orderNumber: String
    var buyerId: Int
    var sellerId: Int
    var listingId: Int
    var listing: Listing?
    var buyer: ListingPoster?
    var seller: ListingPoster?
    var title: String
    var price: Double
    var platformFeeAmount: Double?
    var sellerReceivesAmount: Double?
    var deliveryDeadlineAt: Date?
    var revisionCount: Int
    var maxRevisions: Int
    var status: AlhoqOrder.Status   // zip-এ ভ্যালু সেট অভিন্ন — একই enum reuse

    enum CodingKeys: String, CodingKey {
        case id
        case orderNumber = "order_number"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case listingId = "listing_id"
        case listing, buyer, seller, title, price
        case platformFeeAmount = "platform_fee_amount"
        case sellerReceivesAmount = "seller_receives_amount"
        case deliveryDeadlineAt = "delivery_deadline_at"
        case revisionCount = "revision_count"
        case maxRevisions = "max_revisions"
        case status
    }

    /// zip: EscrowOrder::CANCELLABLE_STATUSES — Direct-Deal থেকে আলাদা রাখা হয়েছে (এখানে ২টাই)
    var isCancellable: Bool {
        status == .created || status == .paymentPending
    }
}

/// zip: EscrowOrderController@store validation
struct CreateEscrowOrderRequest: Encodable {
    let requirements: String?
    let deliveryDays: Int?
    let agreeTerms: Bool
    enum CodingKeys: String, CodingKey {
        case requirements
        case deliveryDays = "delivery_days"
        case agreeTerms = "agree_terms"
    }
}

/// zip: submitPayment() — Direct-Deal-এর মতোই Cloudinary-only proof
struct SubmitEscrowPaymentRequest: Encodable {
    let method: String
    let referenceNumber: String?
    let senderInfo: String?
    let proofUrl: String
    enum CodingKeys: String, CodingKey {
        case method
        case referenceNumber = "reference_number"
        case senderInfo = "sender_info"
        case proofUrl = "proof_url"
    }
}

/// zip: deliver() — Direct-Deal থেকে পার্থক্য: এখানে single file_url (array না), note required
struct DeliverEscrowOrderRequest: Encodable {
    let note: String
    let fileUrl: String?
    enum CodingKeys: String, CodingKey {
        case note
        case fileUrl = "file_url"
    }
}

struct RequestEscrowRevisionRequest: Encodable { let notes: String }

struct EscrowFeeBreakdown: Decodable {
    let price: Double
    let platformFeeAmount: Double
    let sellerReceivesAmount: Double
    enum CodingKeys: String, CodingKey {
        case price
        case platformFeeAmount = "platform_fee_amount"
        case sellerReceivesAmount = "seller_receives_amount"
    }
}

// MARK: - Dispute (zip: app/Models/Escrow/EscrowDispute.php + EscrowDisputeMessage.php)
// Direct-Deal Dispute থেকে পার্থক্য: এখানে একটা মেসেজ থ্রেড (moderator-এর সাথে চ্যাটের মতো) আছে

struct EscrowDispute: Codable, Identifiable, Equatable {
    let id: Int
    var orderId: Int
    var reason: String
    var status: Dispute.Status       // zip: একই status set — Dispute enum reuse

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case reason, status
    }
}

struct EscrowDisputeMessage: Codable, Identifiable, Equatable {
    let id: Int
    var body: String
    var authorName: String
    var isMine: Bool
    var createdAt: String
    enum CodingKeys: String, CodingKey {
        case id, body
        case authorName = "author_name"
        case isMine = "is_mine"
        case createdAt = "created_at"
    }
}

struct OpenEscrowDisputeRequest: Encodable { let reason: String }
struct AddEscrowEvidenceRequest: Encodable {
    let fileUrl: String
    let fileType: String?
    let description: String?
    enum CodingKeys: String, CodingKey {
        case fileUrl = "file_url"
        case fileType = "file_type"
        case description
    }
}
struct SendEscrowDisputeMessageRequest: Encodable { let body: String }
