import Foundation

/// zip: app/Models/CustomForm.php — TYPES/CHOICE_TYPES const হুবহু
enum CustomFieldType: String, Codable, CaseIterable {
    case shortAnswer = "short_answer"
    case paragraph
    case multipleChoice = "multiple_choice"
    case checkboxes
    case dropdown
    case fileUpload = "file_upload"

    var isChoiceType: Bool {
        self == .multipleChoice || self == .checkboxes || self == .dropdown
    }

    var label: String {
        switch self {
        case .shortAnswer: return "ছোট উত্তর"
        case .paragraph: return "প্যারাগ্রাফ"
        case .multipleChoice: return "মাল্টিপল চয়েস (একটা বাছাই)"
        case .checkboxes: return "চেকবক্স (একাধিক বাছাই)"
        case .dropdown: return "ড্রপডাউন"
        case .fileUpload: return "ফাইল আপলোড"
        }
    }
}

struct CustomFormField: Codable, Identifiable, Equatable {
    var id: String
    var type: CustomFieldType
    var label: String
    var required: Bool
    var options: [String]?   // শুধু choice types-এ থাকে
}

struct CustomForm: Codable, Identifiable, Equatable {
    let id: Int
    var listingId: Int
    var formTitle: String
    var buttonLabel: String
    var description: String?
    var fields: [CustomFormField]

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case formTitle = "form_title"
        case buttonLabel = "button_label"
        case description, fields
    }
}

/// zip: CustomFormController@validateForm() — builder পুরো `fields` JSON string আকারে পাঠায়
struct UpdateCustomFormRequest: Encodable {
    let formTitle: String
    let buttonLabel: String
    let description: String?
    let fields: [CustomFormField]

    enum CodingKeys: String, CodingKey {
        case formTitle = "form_title"
        case buttonLabel = "button_label"
        case description, fields
    }
}

// MARK: - Responses

/// zip: FormResponseController — file_upload উত্তর `{path, original_name, size}` — বাকি সব
/// আনসার plain string/array। iOS-এ একটা flexible enum দিয়ে দুটোই represent করা হচ্ছে।
enum FormAnswerValue: Codable, Equatable {
    case text(String)
    case choices([String])
    case file(originalName: String, size: Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let choices = try? container.decode([String].self) {
            self = .choices(choices)
        } else if let file = try? container.decode(FileAnswerPayload.self) {
            self = .file(originalName: file.originalName, size: file.size)
        } else {
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .choices(let values): try container.encode(values)
        case .file(let name, let size): try container.encode(FileAnswerPayload(originalName: name, size: size))
        }
    }

    private struct FileAnswerPayload: Codable {
        let originalName: String
        let size: Int
        enum CodingKeys: String, CodingKey { case originalName = "original_name"; case size }
    }
}

struct FormResponse: Codable, Identifiable, Equatable {
    let id: Int
    var respondentName: String?   // nil হলে "Guest" (web: respondent_id nullable)
    var createdAt: String
    var answers: [String: FormAnswerValue]

    enum CodingKeys: String, CodingKey {
        case id
        case respondentName = "respondent_name"
        case createdAt = "created_at"
        case answers
    }
}

/// zip: buildAnalytics() — choice type-এ প্রতিটা অপশনের count, বাকি সবে শুধু কতজন উত্তর দিয়েছে
struct FormFieldAnalytics: Decodable {
    let label: String
    let type: CustomFieldType
    let counts: [String: Int]?
    let answeredCount: Int?
    enum CodingKeys: String, CodingKey {
        case label, type, counts
        case answeredCount = "answered_count"
    }
}

struct FormResponsesDashboard: Decodable {
    let form: CustomForm
    let responses: [FormResponse]
    let analytics: [String: FormFieldAnalytics]   // key = field id
}
