import Foundation

/// zip: app/Models/User.php $fillable-এর প্রতিটা ফিল্ড এখানে রাখা হয়েছে।
/// একটা field ও বাদ দেওয়া হয়নি — স্ক্রিনে এখনই দরকার না হলেও মডেলে রাখতে হবে
/// (build-plan Section 52-এর নিয়ম: "iOS models must not discard backend status/state
/// fields simply because a particular screen does not currently display them.")
struct AlhoqUser: Codable, Identifiable, Equatable {
    let id: Int
    var name: String
    var username: String?
    var email: String?
    var phone: String?
    var avatar: String?
    var coverPhoto: String?
    var role: String                 // "user" | admin roles (web: isAdmin())
    var adminRole: String?
    var payoutMethod: String?
    var payoutAccount: String?
    var accountType: AccountType     // personal | business
    var occupation: String?
    var companyName: String?
    var bio: String?
    var address: String?
    var website: String?
    var city: String?
    var upazila: String?
    var latitude: Double?
    var longitude: Double?
    var isActive: Bool
    var callsEnabled: Bool
    var smsEnabled: Bool
    var chatEnabled: Bool
    var identityVerifiedAt: Date?
    var lastSeenAt: Date?

    enum AccountType: String, Codable {
        case personal
        case business
    }

    /// web: `handle` accessor — null (not "@") when username not set yet.
    var handle: String? {
        guard let username, !username.isEmpty else { return nil }
        return "@\(username)"
    }

    var isAdmin: Bool {
        role != "user"
    }
}
