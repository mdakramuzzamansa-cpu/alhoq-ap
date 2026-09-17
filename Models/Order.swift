import Foundation

/// zip: app/Models/Alhoq/Order.php — একটা "master lifecycle" স্ট্যাটাস, ২০টা state (কমেন্টেই লেখা
/// "payment_status/delivery_status/dispute_status শুধু রিপোর্টিং, মূল state অনুমান করতে ব্যবহার
/// করা যাবে না") — তাই iOS-ও `status` কেই একমাত্র সত্যের উৎস ধরবে, UI-তে আলাদা করে অনুমান করবে না।
struct AlhoqOrder: Codable, Identifiable, Equatable {
    let id: Int
    var orderNumber: String
    var buyerId: Int
    var sellerId: Int
    var listingId: Int?
    var listing: Listing?
    var buyer: ListingPoster?
    var seller: ListingPoster?
    var title: String
    var price: Double
    var currency: String
    var platformFeeAmount: Double?
    var sellerReceivesAmount: Double?
    var deliveryDeadlineAt: Date?
    var deliveredAt: Date?
    var autoReleaseAt: Date?
    var revisionCount: Int
    var maxRevisions: Int
    var status: Status
    var cancellationReason: String?

    enum Status: String, Codable, CaseIterable {
        case created
        case paymentPending = "payment_pending"
        case paymentSubmitted = "payment_submitted"
        case underReview = "under_review"
        case paymentVerified = "payment_verified"
        case fundsHeld = "funds_held"
        case sellerWorking = "seller_working"
        case sellerDelivered = "seller_delivered"
        case revisionRequested = "revision_requested"
        case disputed
        case buyerAccepted = "buyer_accepted"
        case autoCompleted = "auto_completed"
        case completed
        case payoutPending = "payout_pending"
        case paidOut = "paid_out"
        case paymentRejected = "payment_rejected"
        case sellerMissedDeadline = "seller_missed_deadline"
        case cancelled
        case refunded
        case partiallyRefunded = "partially_refunded"

        /// zip: Order::TERMINAL_STATUSES — এই ৩টার পর কোনো সাধারণ ইউজার অ্যাকশন state বদলাতে পারবে না
        var isTerminal: Bool {
            self == .paidOut || self == .cancelled || self == .refunded
        }

        var label: String {
            switch self {
            case .created: return "তৈরি হয়েছে"
            case .paymentPending: return "পেমেন্টের অপেক্ষায়"
            case .paymentSubmitted: return "পেমেন্ট জমা দেওয়া হয়েছে"
            case .underReview: return "রিভিউ চলছে"
            case .paymentVerified: return "পেমেন্ট যাচাই হয়েছে"
            case .fundsHeld: return "টাকা Escrow-এ জমা আছে"
            case .sellerWorking: return "বিক্রেতা কাজ করছেন"
            case .sellerDelivered: return "ডেলিভারি সম্পন্ন হয়েছে"
            case .revisionRequested: return "রিভিশন চাওয়া হয়েছে"
            case .disputed: return "বিরোধ চলছে"
            case .buyerAccepted: return "ক্রেতা গ্রহণ করেছেন"
            case .autoCompleted: return "স্বয়ংক্রিয়ভাবে সম্পন্ন"
            case .completed: return "সম্পন্ন"
            case .payoutPending: return "পেআউট প্রক্রিয়াধীন"
            case .paidOut: return "পেআউট সম্পন্ন"
            case .paymentRejected: return "পেমেন্ট প্রত্যাখ্যাত"
            case .sellerMissedDeadline: return "বিক্রেতা সময়সীমা মিস করেছেন"
            case .cancelled: return "বাতিল"
            case .refunded: return "টাকা ফেরত দেওয়া হয়েছে"
            case .partiallyRefunded: return "আংশিক ফেরত দেওয়া হয়েছে"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case orderNumber = "order_number"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case listingId = "listing_id"
        case listing, buyer, seller, title, price, currency
        case platformFeeAmount = "platform_fee_amount"
        case sellerReceivesAmount = "seller_receives_amount"
        case deliveryDeadlineAt = "delivery_deadline_at"
        case deliveredAt = "delivered_at"
        case autoReleaseAt = "auto_release_at"
        case revisionCount = "revision_count"
        case maxRevisions = "max_revisions"
        case status
        case cancellationReason = "cancellation_reason"
    }
}

struct OrderStatusHistoryEntry: Codable, Identifiable, Equatable {
    var id: Int { createdAt.hashValue }
    var status: AlhoqOrder.Status
    var note: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case status, note
        case createdAt = "created_at"
    }
}

struct OrderDelivery: Codable, Identifiable, Equatable {
    let id: Int
    var note: String?
    var fileUrls: [String]
    var deliveredAt: String

    enum CodingKeys: String, CodingKey {
        case id, note
        case fileUrls = "file_urls"
        case deliveredAt = "delivered_at"
    }
}

struct OrderRevisionRequest: Codable, Identifiable, Equatable {
    let id: Int
    var reason: String
    var requestedAt: String

    enum CodingKeys: String, CodingKey {
        case id, reason
        case requestedAt = "requested_at"
    }
}

struct OrderDetailResponse: Decodable {
    let order: AlhoqOrder
    let deliveries: [OrderDelivery]
    let statusHistory: [OrderStatusHistoryEntry]
    let revisionRequests: [OrderRevisionRequest]
    let activeDispute: Dispute?
    let payoutMethods: [PayoutMethod]

    enum CodingKeys: String, CodingKey {
        case order, deliveries
        case statusHistory = "status_history"
        case revisionRequests = "revision_requests"
        case activeDispute = "active_dispute"
        case payoutMethods = "payout_methods"
    }
}

struct PayoutMethod: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var name: String
}

// MARK: - Requests (zip validate() rules হুবহু)

struct CreateOrderRequest: Encodable {
    let buyerNotes: String
    let formAnswers: [String: String]?
    enum CodingKeys: String, CodingKey {
        case buyerNotes = "buyer_notes"
        case formAnswers = "form_answers"
    }
}

struct SetPayoutDestinationRequest: Encodable {
    let payoutMethodId: Int
    let payoutAccount: String
    enum CodingKeys: String, CodingKey {
        case payoutMethodId = "payout_method_id"
        case payoutAccount = "payout_account"
    }
}

/// zip: proof_file_url — required|url|starts_with:https://res.cloudinary.com/
struct SubmitPaymentRequest: Encodable {
    let method: String
    let referenceNumber: String?
    let senderInfo: String?
    let proofFileUrl: String
    enum CodingKeys: String, CodingKey {
        case method
        case referenceNumber = "reference_number"
        case senderInfo = "sender_info"
        case proofFileUrl = "proof_file_url"
    }
}

struct DeliverOrderRequest: Encodable {
    let note: String?
    let fileUrls: [String]
    enum CodingKeys: String, CodingKey {
        case note
        case fileUrls = "file_urls"
    }
}

struct RequestRevisionRequest: Encodable { let reason: String }
struct CancelOrderRequest: Encodable { let reason: String? }

// MARK: - Dispute (zip: app/Models/Alhoq/Dispute.php)

struct Dispute: Codable, Identifiable, Equatable {
    let id: Int
    var orderId: Int
    var reason: String
    var status: Status
    var decision: Decision?
    var openedBy: Int   // zip: DisputePolicy::withdraw() — শুধু যিনি dispute খুলেছেন তিনিই withdraw করতে পারবেন

    enum Status: String, Codable {
        case open
        case underReview = "under_review"
        case pendingSeniorApproval = "pending_senior_approval"
        case decided
        case appealed
        case closed

        var label: String {
            switch self {
            case .open: return "খোলা হয়েছে"
            case .underReview: return "রিভিউ চলছে"
            case .pendingSeniorApproval: return "সিনিয়র অনুমোদনের অপেক্ষায়"
            case .decided: return "সিদ্ধান্ত হয়েছে"
            case .appealed: return "আপিল করা হয়েছে"
            case .closed: return "বন্ধ"
            }
        }
    }

    enum Decision: String, Codable {
        case refund
        case partialRefund = "partial_refund"
        case releaseToSeller = "release_to_seller"
        case requestMoreEvidence = "request_more_evidence"
        case cancelled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case reason, status, decision
        case openedBy = "opened_by"
    }
}

struct DisputeEvidence: Codable, Identifiable, Equatable {
    let id: Int
    var fileUrl: String
    var fileType: String
    var description: String?
    var uploadedByName: String

    enum CodingKeys: String, CodingKey {
        case id
        case fileUrl = "file_url"
        case fileType = "file_type"
        case description
        case uploadedByName = "uploaded_by_name"
    }
}

struct OpenDisputeRequest: Encodable { let reason: String }
struct AddEvidenceRequest: Encodable {
    let fileUrl: String
    let fileType: String
    let fileSizeBytes: Int
    let description: String?
    enum CodingKeys: String, CodingKey {
        case fileUrl = "file_url"
        case fileType = "file_type"
        case fileSizeBytes = "file_size_bytes"
        case description
    }
}
struct AppealDisputeRequest: Encodable { let reason: String }
