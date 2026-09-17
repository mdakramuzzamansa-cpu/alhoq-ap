import Foundation

@MainActor
final class FormBuilderViewModel: ObservableObject {
    let listingId: Int
    @Published var formTitle = "Apply Now"
    @Published var buttonLabel = "Apply Now"
    @Published var description = ""
    @Published var fields: [CustomFormField] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false

    private let api: CustomFormAPIProtocol = CustomFormAPI()
    init(listingId: Int) { self.listingId = listingId }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        if let form = try? await api.getForm(listingId: listingId) {
            formTitle = form.formTitle
            buttonLabel = form.buttonLabel
            description = form.description ?? ""
            fields = form.fields
        }
    }

    func addField(type: CustomFieldType) {
        fields.append(CustomFormField(
            id: UUID().uuidString, type: type, label: "", required: false,
            options: type.isChoiceType ? [""] : nil
        ))
    }

    func removeField(at offsets: IndexSet) {
        fields.remove(atOffsets: offsets)
    }

    func moveField(from source: IndexSet, to destination: Int) {
        fields.move(fromOffsets: source, toOffset: destination)
    }

    func save() async {
        errorMessage = nil
        guard !fields.isEmpty else {
            errorMessage = "কমপক্ষে ১টা প্রশ্ন যোগ করুন।"
            return
        }
        for field in fields where field.label.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "প্রতিটা প্রশ্নের লেবেল থাকতে হবে।"
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await api.saveForm(
                listingId: listingId,
                UpdateCustomFormRequest(formTitle: formTitle, buttonLabel: buttonLabel, description: description.isEmpty ? nil : description, fields: fields)
            )
            didSave = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "সেভ করা যায়নি।"
        }
    }

    func deleteForm() async {
        try? await api.deleteForm(listingId: listingId)
        didSave = true
    }
}

@MainActor
final class FormFillViewModel: ObservableObject {
    let listingId: Int
    @Published var form: CustomForm?
    @Published var textValues: [String: String] = [:]
    @Published var choiceValues: [String: Set<String>] = [:]
    @Published var fileValues: [String: URL] = [:]
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var fieldErrors: [String: String] = [:]
    @Published var didSubmit = false

    private let api: CustomFormAPIProtocol = CustomFormAPI()
    init(listingId: Int) { self.listingId = listingId }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        form = try? await api.getForm(listingId: listingId)
    }

    func submit() async {
        guard let form else { return }
        fieldErrors = [:]
        for field in form.fields where field.required {
            switch field.type {
            case .fileUpload:
                if fileValues[field.id] == nil { fieldErrors[field.id] = "\(field.label) আবশ্যক।" }
            case .checkboxes:
                if (choiceValues[field.id] ?? []).isEmpty { fieldErrors[field.id] = "\(field.label) আবশ্যক।" }
            default:
                if (textValues[field.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                    fieldErrors[field.id] = "\(field.label) আবশ্যক।"
                }
            }
        }
        guard fieldErrors.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        var textAnswers: [String: FormAnswerValue] = [:]
        for field in form.fields {
            switch field.type {
            case .checkboxes:
                if let choices = choiceValues[field.id], !choices.isEmpty {
                    textAnswers[field.id] = .choices(Array(choices))
                }
            case .fileUpload:
                break
            default:
                if let text = textValues[field.id], !text.isEmpty {
                    textAnswers[field.id] = .text(text)
                }
            }
        }

        do {
            try await api.submitResponse(listingId: listingId, textAnswers: textAnswers, fileAnswers: fileValues)
            didSubmit = true
        } catch let error as APIError {
            switch error {
            case .validation(let errors):
                for (key, messages) in errors { fieldErrors[key] = messages.first }
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "জমা দেওয়া যায়নি।"
        }
    }
}

@MainActor
final class FormResponsesViewModel: ObservableObject {
    let listingId: Int
    @Published var dashboard: FormResponsesDashboard?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: CustomFormAPIProtocol = CustomFormAPI()
    init(listingId: Int) { self.listingId = listingId }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { dashboard = try await api.responsesDashboard(listingId: listingId) }
        catch { errorMessage = "লোড করা যায়নি।" }
    }

    func downloadAttachment(responseId: Int, fieldId: String) async -> URL? {
        guard let data = try? await api.downloadAttachment(listingId: listingId, responseId: responseId, fieldId: fieldId) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? data.write(to: tempURL)
        return tempURL
    }
}
