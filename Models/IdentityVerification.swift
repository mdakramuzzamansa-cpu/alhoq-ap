import Foundation

/// zip: app/Models/IdentityVerification.php + migration `create_identity_verifications_table`
/// এটা category-based "Get Trusted" (Verification.swift) থেকে সম্পূর্ণ আলাদা সিস্টেম —
/// একবারই, পুরো অ্যাকাউন্টের জন্য, NID + live face video — escrow ব্যবহারের শর্ত।
struct IdentityVerification: Codable, Identifiable, Equatable {
    let id: Int
    var status: Status
    var rejectionReason: String?
    var verifiedAt: Date?
    var createdAt: Date?

    enum Status: String, Codable {
        case pending, approved, rejected
    }

    enum CodingKeys: String, CodingKey {
        case id, status
        case rejectionReason = "rejection_reason"
        case verifiedAt = "verified_at"
        case createdAt = "created_at"
    }
}

/// web KycVerificationController@store — শুধু ৩টা Cloudinary URL, ফাইল বাইট কখনো Laravel সার্ভারে যায় না
struct IdentityVerificationSubmission: Encodable {
    let nidFrontUrl: String
    let nidBackUrl: String
    let faceVideoUrl: String

    enum CodingKeys: String, CodingKey {
        case nidFrontUrl = "nid_front_url"
        case nidBackUrl = "nid_back_url"
        case faceVideoUrl = "face_video_url"
    }
}
