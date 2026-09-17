import Foundation

@MainActor
final class KycViewModel: ObservableObject {
    enum ScreenState: Equatable {
        case loading
        case alreadyVerified
        case pending(IdentityVerification)
        // web: $latest হয় null নাহলে rejected হলেই ফর্ম দেখানো হয় (rejection reason context সহ)
        case form(previousRejection: IdentityVerification?)
    }

    @Published var screenState: ScreenState = .loading
    @Published var nidFrontFileURL: URL?
    @Published var nidBackFileURL: URL?
    @Published var faceVideoFileURL: URL?
    @Published var isUploadingFront = false
    @Published var isUploadingBack = false
    @Published var isUploadingVideo = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private var nidFrontURL: String?
    private var nidBackURL: String?
    private var faceVideoURL: String?

    private let api: VerificationAPIProtocol
    private let uploader: MediaUploader
    private let isIdentityVerified: Bool   // AlhoqUser.identityVerifiedAt থেকে caller পাস করবে

    init(isIdentityVerified: Bool, api: VerificationAPIProtocol = VerificationAPI(), uploader: MediaUploader? = nil) {
        self.isIdentityVerified = isIdentityVerified
        self.api = api
        self.uploader = uploader ?? MediaUploader()
    }

    var canSubmit: Bool {
        nidFrontURL != nil && nidBackURL != nil && faceVideoURL != nil && !isSubmitting
    }

    func load() async {
        if isIdentityVerified {
            screenState = .alreadyVerified
            return
        }
        do {
            if let latest = try await api.kycStatus() {
                switch latest.status {
                case .pending:
                    screenState = .pending(latest)
                case .approved:
                    screenState = .alreadyVerified
                case .rejected:
                    screenState = .form(previousRejection: latest)
                }
            } else {
                screenState = .form(previousRejection: nil)
            }
        } catch {
            screenState = .form(previousRejection: nil)
        }
    }

    func uploadNidFront(fileURL: URL) async {
        nidFrontFileURL = fileURL
        isUploadingFront = true
        defer { isUploadingFront = false }
        do { nidFrontURL = try await uploader.upload(fileURL: fileURL) }
        catch { errorMessage = "NID সামনের ছবি আপলোড ব্যর্থ হয়েছে।"; nidFrontFileURL = nil }
    }

    func uploadNidBack(fileURL: URL) async {
        nidBackFileURL = fileURL
        isUploadingBack = true
        defer { isUploadingBack = false }
        do { nidBackURL = try await uploader.upload(fileURL: fileURL) }
        catch { errorMessage = "NID পেছনের ছবি আপলোড ব্যর্থ হয়েছে।"; nidBackFileURL = nil }
    }

    func uploadFaceVideo(fileURL: URL) async {
        faceVideoFileURL = fileURL
        isUploadingVideo = true
        defer { isUploadingVideo = false }
        do { faceVideoURL = try await uploader.upload(fileURL: fileURL) }
        catch { errorMessage = "ভিডিও আপলোড ব্যর্থ হয়েছে।"; faceVideoFileURL = nil }
    }

    func submit() async {
        guard let nidFrontURL, let nidBackURL, let faceVideoURL else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let submission = IdentityVerificationSubmission(
                nidFrontUrl: nidFrontURL, nidBackUrl: nidBackURL, faceVideoUrl: faceVideoURL
            )
            let result = try await api.submitKyc(submission)
            screenState = .pending(result)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "জমা দেওয়া যায়নি। আবার চেষ্টা করুন।"
        }
    }
}
