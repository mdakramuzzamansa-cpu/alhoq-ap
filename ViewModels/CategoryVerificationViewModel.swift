import Foundation

@MainActor
final class CategoryVerificationViewModel: ObservableObject {
    enum ScreenState: Equatable {
        case loading
        case alreadyApproved
        case pending(CategoryVerification)
        case form(fields: [VerificationFieldDefinition], previousRejection: CategoryVerification?)
        case error(String)
    }

    @Published var screenState: ScreenState = .loading
    @Published var accountType: AlhoqUser.AccountType = .personal
    @Published var businessType: String = ""

    /// প্রতিটা dynamic field-এর জন্য: text/textarea/url টাইপে সরাসরি টেক্সট,
    /// file/video টাইপে Cloudinary আপলোডের পর পাওয়া secure_url
    @Published var textValues: [String: String] = [:]
    @Published var uploadedFileValues: [String: String] = [:]
    @Published var uploadingFieldKeys: Set<String> = []
    @Published var fieldErrors: [String: String] = [:]
    @Published var isSubmitting = false
    @Published var generalError: String?

    let categoryId: Int
    private let api: VerificationAPIProtocol
    private let uploader: MediaUploader

    init(categoryId: Int, api: VerificationAPIProtocol = VerificationAPI(), uploader: MediaUploader? = nil) {
        self.categoryId = categoryId
        self.api = api
        self.uploader = uploader ?? MediaUploader()
    }

    func load() async {
        do {
            let requirements = try await api.verificationRequirements(categoryId: categoryId)
            if let existing = requirements.existing {
                switch existing.status {
                case .pending: screenState = .pending(existing)
                case .approved: screenState = .alreadyApproved
                case .rejected: screenState = .form(fields: requirements.fields, previousRejection: existing)
                }
            } else {
                screenState = .form(fields: requirements.fields, previousRejection: nil)
            }
        } catch let error as APIError {
            screenState = .error(error.localizedDescription)
        } catch {
            screenState = .error("লোড করা যায়নি।")
        }
    }

    func uploadFile(fileURL: URL, for field: VerificationFieldDefinition) async {
        uploadingFieldKeys.insert(field.key)
        defer { uploadingFieldKeys.remove(field.key) }
        do {
            uploadedFileValues[field.key] = try await uploader.upload(fileURL: fileURL)
        } catch {
            fieldErrors[field.key] = "আপলোড ব্যর্থ হয়েছে, আবার চেষ্টা করুন।"
        }
    }

    func submit(fields: [VerificationFieldDefinition]) async {
        fieldErrors = [:]
        generalError = nil

        if accountType == .business && businessType.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldErrors["business_type"] = "ব্যবসার ধরন লিখুন।"
        }

        var values: [String: String] = [:]
        for field in fields {
            switch field.type {
            case .file, .video:
                guard let url = uploadedFileValues[field.key] else {
                    fieldErrors[field.key] = "\(field.label) আপলোড করুন।"
                    continue
                }
                values[field.key] = url
            case .text, .url:
                let value = textValues[field.key] ?? ""
                if value.trimmingCharacters(in: .whitespaces).isEmpty {
                    fieldErrors[field.key] = "\(field.label) আবশ্যক।"
                } else {
                    values[field.key] = value
                }
            case .textarea:
                let value = textValues[field.key] ?? ""
                if value.trimmingCharacters(in: .whitespaces).isEmpty {
                    fieldErrors[field.key] = "\(field.label) আবশ্যক।"
                } else if value.count > 3000 {
                    fieldErrors[field.key] = "সর্বোচ্চ ৩০০০ ক্যারেক্টার।"
                } else {
                    values[field.key] = value
                }
            }
        }

        guard fieldErrors.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let submission = CategoryVerificationSubmission(
                accountType: accountType,
                businessType: accountType == .business ? businessType : nil,
                values: values
            )
            let result = try await api.submitCategoryVerification(categoryId: categoryId, submission)
            screenState = .pending(result)
        } catch let error as APIError {
            switch error {
            case .validation(let errors):
                generalError = errors.values.first?.first ?? error.localizedDescription
            default:
                generalError = error.localizedDescription
            }
        } catch {
            generalError = "জমা দেওয়া যায়নি। আবার চেষ্টা করুন।"
        }
    }
}
