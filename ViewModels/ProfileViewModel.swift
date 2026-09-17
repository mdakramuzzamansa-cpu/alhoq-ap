import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: AlhoqUser
    @Published var form: EditableFields
    @Published var isSaving = false
    @Published var usernameStatus: UsernameStatus = .idle
    @Published var errorMessage: String?
    @Published var successMessage: String?

    /// avatar/cover-এর জন্য নতুন ছবি বেছে নেওয়া হলে সেভ করার আগ পর্যন্ত লোকাল প্রিভিউ এখানে থাকবে
    @Published var pendingAvatarURL: URL?
    @Published var pendingCoverURL: URL?
    @Published var isUploadingAvatar = false
    @Published var isUploadingCover = false

    enum UsernameStatus: Equatable {
        case idle, checking, available, taken
    }

    struct EditableFields {
        var name: String
        var username: String
        var email: String
        var phone: String
        var accountType: AlhoqUser.AccountType
        var bio: String
        var address: String
        var website: String
        var occupation: String
        var companyName: String
    }

    private let api: ProfileAPIProtocol
    private let uploader: MediaUploader
    private var usernameCheckTask: Task<Void, Never>?

    init(user: AlhoqUser, api: ProfileAPIProtocol = ProfileAPI(), uploader: MediaUploader? = nil) {
        self.user = user
        self.api = api
        self.uploader = uploader ?? MediaUploader()
        self.form = EditableFields(
            name: user.name,
            username: user.username ?? "",
            email: user.email ?? "",
            phone: user.phone ?? "",
            accountType: user.accountType,
            bio: user.bio ?? "",
            address: user.address ?? "",
            website: user.website ?? "",
            occupation: user.occupation ?? "",
            companyName: user.companyName ?? ""
        )
    }

    func usernameChanged(_ newValue: String) {
        usernameCheckTask?.cancel()
        guard newValue != user.username, !newValue.isEmpty else {
            usernameStatus = .idle
            return
        }
        usernameStatus = .checking
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // debounce, web-এর মতো keystroke-এ keystroke-এ কল না করে
            guard !Task.isCancelled else { return }
            do {
                let available = try await api.checkUsernameAvailability(newValue)
                usernameStatus = available ? .available : .taken
            } catch {
                usernameStatus = .idle
            }
        }
    }

    /// PhotosPicker থেকে ছবি বাছার সাথে সাথে আপলোড শুরু হয় — save চাপার জন্য অপেক্ষা করে না,
    /// কিন্তু URL সাথে সাথে profile-এ বসে না, "সেভ করুন" চাপলে তবেই বসবে (web behavior অনুযায়ী,
    /// avatar preview vs actually saved — দুটো আলাদা ধাপ)
    private var uploadedAvatarURL: String?
    private var uploadedCoverURL: String?

    func pickedAvatar(fileURL: URL) async {
        pendingAvatarURL = fileURL
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        do {
            uploadedAvatarURL = try await uploader.upload(fileURL: fileURL)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            pendingAvatarURL = nil
        } catch {
            errorMessage = "ছবি আপলোড ব্যর্থ হয়েছে।"
            pendingAvatarURL = nil
        }
    }

    func pickedCover(fileURL: URL) async {
        pendingCoverURL = fileURL
        isUploadingCover = true
        defer { isUploadingCover = false }
        do {
            uploadedCoverURL = try await uploader.upload(fileURL: fileURL)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            pendingCoverURL = nil
        } catch {
            errorMessage = "ছবি আপলোড ব্যর্থ হয়েছে।"
            pendingCoverURL = nil
        }
    }

    func save() async {
        errorMessage = nil
        successMessage = nil
        isSaving = true
        defer { isSaving = false }

        let request = UpdateProfileRequest(
            name: form.name,
            username: form.username.isEmpty ? nil : form.username,
            email: form.email.isEmpty ? nil : form.email,
            phone: form.phone.isEmpty ? nil : form.phone,
            accountType: form.accountType,
            companyName: form.accountType == .business ? form.companyName : nil,
            occupation: form.occupation,
            bio: form.bio.isEmpty ? nil : form.bio,
            address: form.address.isEmpty ? nil : form.address,
            website: form.website.isEmpty ? nil : form.website,
            avatar: uploadedAvatarURL,
            coverPhoto: uploadedCoverURL
        )

        do {
            user = try await api.updateProfile(request)
            successMessage = "প্রোফাইল আপডেট হয়েছে।"
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "কিছু একটা ভুল হয়েছে।"
        }
    }
}
