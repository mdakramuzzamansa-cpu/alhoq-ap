import Foundation

/// zip: app/Models/Category.php — SECTIONS/RISK_LEVELS constants ও $fillable হুবহু।
struct Category: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var name: String
    var slug: String
    var description: String?
    var icon: String?
    var parentId: Int?
    var sortOrder: Int
    var isActive: Bool
    var isBookable: Bool
    var isEscrowEnabled: Bool          // Alhoq Direct-Deal escrow eligibility
    var bookingLabel: String?
    var section: Section
    var isVerificationRequired: Bool   // true হলে "Get Trusted" verification ছাড়া পোস্ট করা যাবে না
    var requiredFields: [String]?      // dynamic verification fields — API-driven, hardcode করা যাবে না (Section 7)
    var allowAnonymous: Bool
    var riskLevel: RiskLevel?
    var marketplaceEscrowEnabled: Bool // Marketplace Escrow eligibility — Direct-Deal escrow থেকে আলাদা সিস্টেম

    enum Section: String, Codable, CaseIterable {
        case services = "SERVICES"
        case professionals = "Professionals"
        case alerts = "Alerts"
        case marketplace = "MARKETPLACE"

        var label: String {
            switch self {
            case .services: return "সার্ভিস"
            case .professionals: return "প্রফেশনাল"
            case .alerts: return "এলার্ট"
            case .marketplace: return "মার্কেটপ্লেস"
            }
        }
    }

    enum RiskLevel: String, Codable {
        case lowRisk = "low_risk"
        case mediumRisk = "medium_risk"
        case highRisk = "high_risk"      // Marketplace Escrow স্থায়ীভাবে বন্ধ থাকবে, marketplaceEscrowEnabled যাই হোক না কেন
    }

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, icon
        case parentId = "parent_id"
        case sortOrder = "sort_order"
        case isActive = "is_active"
        case isBookable = "is_bookable"
        case isEscrowEnabled = "is_escrow_enabled"
        case bookingLabel = "booking_label"
        case section
        case isVerificationRequired = "is_verification_required"
        case requiredFields = "required_fields"
        case allowAnonymous = "allow_anonymous"
        case riskLevel = "risk_level"
        case marketplaceEscrowEnabled = "marketplace_escrow_enabled"
    }
}
