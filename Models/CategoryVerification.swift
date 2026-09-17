import Foundation

/// zip: config/verification_fields.php — এটাই master list, কোনো ক্যাটাগরিতে হার্ডকোড করা নেই।
/// backend প্রতিটা ক্যাটাগরির জন্য শুধু `required_fields` (key-এর array) পাঠায়, ফর্ম পুরোপুরি
/// dynamic ভাবে বানাতে হবে — Rule অনুযায়ী কোনো ফিল্ড iOS-এ হার্ডকোড করা যাবে না।
struct VerificationFieldDefinition: Codable, Identifiable, Equatable {
    var key: String
    var label: String
    var type: FieldType

    var id: String { key }

    enum FieldType: String, Codable {
        case text, textarea, url, file, video
    }
}

/// zip: app/Models/Verification.php + migration create_verifications_tables
struct CategoryVerification: Codable, Identifiable, Equatable {
    let id: Int
    var categoryId: Int
    var accountType: AlhoqUser.AccountType
    var businessType: String?
    var status: Status
    var adminNote: String?

    enum Status: String, Codable {
        case pending, approved, rejected
    }

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case accountType = "account_type"
        case businessType = "business_type"
        case status
        case adminNote = "admin_note"
    }
}

/// web VerificationController@create — category detail + dynamic field defs + existing request (থাকলে)
struct CategoryVerificationRequirements: Decodable {
    let category: Category
    let fields: [VerificationFieldDefinition]
    let existing: CategoryVerification?
}

/// web VerificationController@store validation — হুবহু:
///   account_type required|in:personal,business
///   business_type nullable|required_if:account_type,business
///   প্রতিটা dynamic field: file/video/url টাইপ হলে required|url (Cloudinary secure_url),
///   textarea হলে required|string|max:3000, বাকি সব required|string|max:255
struct CategoryVerificationSubmission: Encodable {
    let accountType: AlhoqUser.AccountType
    let businessType: String?
    let values: [String: String]     // field_key -> value (text) অথবা Cloudinary secure_url (file/video/url)

    enum CodingKeys: String, CodingKey {
        case accountType = "account_type"
        case businessType = "business_type"
        case values
    }

    // web প্রতিটা dynamic field সরাসরি top-level key হিসেবে আশা করে (values.* নয়),
    // তাই encode() override করে values dictionary-কে flatten করে পাঠানো হচ্ছে।
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(accountType.rawValue, forKey: DynamicKey(stringValue: "account_type")!)
        if let businessType {
            try container.encode(businessType, forKey: DynamicKey(stringValue: "business_type")!)
        }
        for (key, value) in values {
            try container.encode(value, forKey: DynamicKey(stringValue: key)!)
        }
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}
