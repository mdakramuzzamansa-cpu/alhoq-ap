import Foundation

@MainActor
final class OrderDetailViewModel: ObservableObject {
    let orderId: Int
    let currentUserId: Int

    @Published var order: AlhoqOrder?
    @Published var deliveries: [OrderDelivery] = []
    @Published var statusHistory: [OrderStatusHistoryEntry] = []
    @Published var revisionRequests: [OrderRevisionRequest] = []
    @Published var activeDispute: Dispute?
    @Published var payoutMethods: [PayoutMethod] = []
    @Published var isLoading = false
    @Published var isActing = false
    @Published var errorMessage: String?

    private let api: OrderAPIProtocol
    private let uploader: MediaUploader

    init(orderId: Int, currentUserId: Int, api: OrderAPIProtocol = OrderAPI(), uploader: MediaUploader? = nil) {
        self.orderId = orderId
        self.currentUserId = currentUserId
        self.api = api
        self.uploader = uploader ?? MediaUploader()
    }

    var isBuyer: Bool { order?.buyerId == currentUserId }
    var isSeller: Bool { order?.sellerId == currentUserId }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.orderDetail(id: orderId)
            order = response.order
            deliveries = response.deliveries
            statusHistory = response.statusHistory
            revisionRequests = response.revisionRequests
            activeDispute = response.activeDispute
            payoutMethods = response.payoutMethods
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "অর্ডার লোড করা যায়নি।"
        }
    }

    func setPayoutDestination(methodId: Int, account: String) async {
        await perform {
            try await self.api.setPayoutDestination(
                orderId: self.orderId,
                SetPayoutDestinationRequest(payoutMethodId: methodId, payoutAccount: account)
            )
            await self.load()
        }
    }

    /// web: proof_file_url অবশ্যই Cloudinary secure_url — এখানে uploader দিয়ে upload করে তারপর submit
    func submitPayment(method: String, referenceNumber: String?, senderInfo: String?, proofFileURL: URL) async {
        await perform {
            let secureURL = try await self.uploader.upload(fileURL: proofFileURL)
            let updated = try await self.api.submitPayment(
                orderId: self.orderId,
                SubmitPaymentRequest(method: method, referenceNumber: referenceNumber, senderInfo: senderInfo, proofFileUrl: secureURL)
            )
            self.order = updated
        }
    }

    func deliver(note: String?, fileURLs: [URL]) async {
        await perform {
            var uploadedURLs: [String] = []
            for fileURL in fileURLs {
                uploadedURLs.append(try await self.uploader.upload(fileURL: fileURL))
            }
            let updated = try await self.api.deliverOrder(
                orderId: self.orderId, DeliverOrderRequest(note: note, fileUrls: uploadedURLs)
            )
            self.order = updated
            await self.load()
        }
    }

    func accept() async {
        await perform {
            self.order = try await self.api.acceptOrder(id: self.orderId)
        }
    }

    func requestRevision(reason: String) async {
        await perform {
            self.order = try await self.api.requestRevision(orderId: self.orderId, reason: reason)
            await self.load()
        }
    }

    func cancel(reason: String?) async {
        await perform {
            self.order = try await self.api.cancelOrder(id: self.orderId, reason: reason)
        }
    }

    func openDispute(reason: String) async {
        await perform {
            self.activeDispute = try await self.api.openDispute(orderId: self.orderId, reason: reason)
            await self.load()
        }
    }

    private func perform(_ action: @escaping () async throws -> Void) async {
        isActing = true
        errorMessage = nil
        defer { isActing = false }
        do {
            try await action()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "কাজটা সম্পন্ন করা যায়নি।"
        }
    }
}
