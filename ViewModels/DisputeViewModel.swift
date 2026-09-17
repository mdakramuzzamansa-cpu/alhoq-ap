import Foundation

@MainActor
final class DisputeViewModel: ObservableObject {
    let disputeId: Int
    let currentUserId: Int
    @Published var dispute: Dispute?
    @Published var evidence: [DisputeEvidence] = []
    @Published var isLoading = false
    @Published var isUploadingEvidence = false
    @Published var isActing = false
    @Published var errorMessage: String?

    private let api: OrderAPIProtocol
    private let uploader: MediaUploader

    var canWithdraw: Bool {
        guard let dispute else { return false }
        return dispute.openedBy == currentUserId && [.open, .underReview].contains(dispute.status)
    }

    init(disputeId: Int, currentUserId: Int, api: OrderAPIProtocol = OrderAPI(), uploader: MediaUploader? = nil) {
        self.disputeId = disputeId
        self.currentUserId = currentUserId
        self.api = api
        self.uploader = uploader ?? MediaUploader()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            (dispute, evidence) = try await api.disputeDetail(id: disputeId)
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }

    func addEvidence(fileURL: URL, description: String?) async {
        isUploadingEvidence = true
        errorMessage = nil
        defer { isUploadingEvidence = false }
        do {
            let secureURL = try await uploader.upload(fileURL: fileURL)
            let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
            try await api.addEvidence(
                disputeId: disputeId,
                AddEvidenceRequest(
                    fileUrl: secureURL, fileType: fileURL.pathExtension,
                    fileSizeBytes: sizeBytes ?? 0, description: description
                )
            )
            await load()
        } catch {
            errorMessage = "এভিডেন্স আপলোড করা যায়নি।"
        }
    }

    func withdraw() async {
        isActing = true
        defer { isActing = false }
        do {
            try await api.withdrawDispute(id: disputeId)
            await load()
        } catch {
            errorMessage = "বিরোধ প্রত্যাহার করা যায়নি।"
        }
    }

    func appeal(reason: String) async {
        isActing = true
        defer { isActing = false }
        do {
            try await api.appealDispute(id: disputeId, reason: reason)
            await load()
        } catch {
            errorMessage = "আপিল করা যায়নি।"
        }
    }
}
