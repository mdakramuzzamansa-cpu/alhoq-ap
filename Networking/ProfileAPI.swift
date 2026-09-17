import Foundation

/// zip: এই ফাইল Phase 24 audit-এর সময় `Panel/ProfileController@update`-এর সাথে সরাসরি মিলিয়ে
/// সংশোধন করা হয়েছে — আগে যে ফিল্ড সেট অনুমান করা হয়েছিল তার সাথে আসল validation-এর পার্থক্য ছিল:
///   ✅ যোগ হলো: email, phone (দুটোরই একটা লাগবে — required_without একে অপরের), account_type
///   ❌ বাদ হলো: city, upazila — এই controller-এ এগুলো আদৌ validate/আপডেট হয় না
///      (Register-এর সময় বসে, কিন্তু profile-edit endpoint দিয়ে বদলানো যায় না — এটা web-এর
///      নিজস্ব ডিজাইন সিদ্ধান্ত, iOS-এ আলাদা কিছু বানানো ঠিক হবে না)
///
/// path (`profile`) তবু অনুমানভিত্তিক — Android API-তে আসল route নাম কনফার্ম হলে বদলাতে হবে।
protocol ProfileAPIProtocol {
    func updateProfile(_ request: UpdateProfileRequest) async throws -> AlhoqUser
    func checkUsernameAvailability(_ username: String) async throws -> Bool
}

struct UpdateProfileRequest: Encodable {
    let name: String
    let username: String?
    let email: String?
    let phone: String?
    let accountType: AlhoqUser.AccountType
    let companyName: String?     // required_if account_type == business
    let occupation: String
    let bio: String?
    let address: String?
    let website: String?
    let avatar: String?          // universal-upload/Cloudinary থেকে পাওয়া URL
    let coverPhoto: String?

    enum CodingKeys: String, CodingKey {
        case name, username, email, phone
        case accountType = "account_type"
        case companyName = "company_name"
        case occupation, bio, address, website, avatar
        case coverPhoto = "cover_photo"
    }
}

final class ProfileAPI: ProfileAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func updateProfile(_ request: UpdateProfileRequest) async throws -> AlhoqUser {
        let envelope: APIEnvelope<AlhoqUser> = try await client.request("profile", method: .put, body: request)
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        struct Availability: Decodable { let available: Bool }
        let envelope: APIEnvelope<Availability> = try await client.request(
            "profile/username/check", query: ["username": username]
        )
        return envelope.data?.available ?? false
    }
}
