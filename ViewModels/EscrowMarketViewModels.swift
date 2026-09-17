import Foundation

@MainActor
final class EscrowMarketBrowseViewModel: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var errorMessage: String?

    private let api: EscrowMarketAPIProtocol
    init(api: EscrowMarketAPIProtocol = EscrowMarketAPI()) { self.api = api }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let envelope = try await api.browse(search: searchText, categoryId: nil, page: 1)
            listings = envelope.data ?? []
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }
}

@MainActor
final class EscrowOrderCreateViewModel: ObservableObject {
    let listing: Listing
    @Published var requirements: String = ""
    @Published var deliveryDays: String = ""
    @Published var agreeTerms = false
    @Published var feeBreakdown: EscrowFeeBreakdown?
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var createdOrder: EscrowMarketOrder?

    private let api: EscrowMarketAPIProtocol
    init(listing: Listing, api: EscrowMarketAPIProtocol = EscrowMarketAPI()) {
        self.listing = listing
        self.api = api
    }

    func loadFeeBreakdown() async {
        feeBreakdown = try? await api.feeBreakdown(listingId: listing.id)
    }

    func submit() async {
        guard agreeTerms else {
            errorMessage = "শর্তাবলীতে সম্মত হতে হবে।"
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            createdOrder = try await api.createOrder(
                listingId: listing.id,
                CreateEscrowOrderRequest(
                    requirements: requirements.isEmpty ? nil : requirements,
                    deliveryDays: Int(deliveryDays),
                    agreeTerms: agreeTerms
                )
            )
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "অর্ডার তৈরি করা যায়নি।"
        }
    }
}

@MainActor
final class EscrowOrderListViewModel: ObservableObject {
    @Published var buying: [EscrowMarketOrder] = []
    @Published var selling: [EscrowMarketOrder] = []
    @Published var isLoading = false

    private let api: EscrowMarketAPIProtocol
    init(api: EscrowMarketAPIProtocol = EscrowMarketAPI()) { self.api = api }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let b = api.orders(as: "buying", page: 1)
        async let s = api.orders(as: "selling", page: 1)
        buying = (try? await b)?.data ?? []
        selling = (try? await s)?.data ?? []
    }
}

@MainActor
final class EscrowOrderDetailViewModel: ObservableObject {
    let orderId: Int
    let currentUserId: Int
    @Published var order: EscrowMarketOrder?
    @Published var isLoading = false
    @Published var isActing = false
    @Published var errorMessage: String?

    private let api: EscrowMarketAPIProtocol
    private let uploader: MediaUploader

    init(orderId: Int, currentUserId: Int, api: EscrowMarketAPIProtocol = EscrowMarketAPI(), uploader: MediaUploader? = nil) {
        self.orderId = orderId
        self.currentUserId = currentUserId
        self.api = api
        self.uploader = uploader ?? MediaUploader()
    }

    var isBuyer: Bool { order?.buyerId == currentUserId }
    var isSeller: Bool { order?.sellerId == currentUserId }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        order = try? await api.orderDetail(id: orderId)
    }

    func submitPayment(method: String, referenceNumber: String?, senderInfo: String?, proofFileURL: URL) async {
        await perform {
            let secureURL = try await self.uploader.upload(fileURL: proofFileURL)
            self.order = try await self.api.submitPayment(
                orderId: self.orderId,
                SubmitEscrowPaymentRequest(method: method, referenceNumber: referenceNumber, senderInfo: senderInfo, proofUrl: secureURL)
            )
        }
    }

    func deliver(note: String, fileURL: URL?) async {
        await perform {
            var uploadedURL: String?
            if let fileURL { uploadedURL = try await self.uploader.upload(fileURL: fileURL) }
            self.order = try await self.api.deliver(
                orderId: self.orderId, DeliverEscrowOrderRequest(note: note, fileUrl: uploadedURL)
            )
        }
    }

    func accept() async { await perform { self.order = try await self.api.accept(orderId: self.orderId) } }

    func requestRevision(notes: String) async {
        await perform { self.order = try await self.api.requestRevision(orderId: self.orderId, notes: notes) }
    }

    func cancel() async {
        await perform { self.order = try await self.api.cancel(orderId: self.orderId) }
    }

    func openDisputeAndReturnId(reason: String) async -> Int? {
        do {
            let dispute = try await api.openDispute(orderId: orderId, reason: reason)
            return dispute.id
        } catch {
            errorMessage = "বিরোধ খোলা যায়নি।"
            return nil
        }
    }

    private func perform(_ action: @escaping () async throws -> Void) async {
        isActing = true
        errorMessage = nil
        defer { isActing = false }
        do { try await action() }
        catch let error as APIError { errorMessage = error.localizedDescription }
        catch { errorMessage = "কাজটা সম্পন্ন করা যায়নি।" }
    }
}

@MainActor
final class EscrowDisputeViewModel: ObservableObject {
    let disputeId: Int
    @Published var dispute: EscrowDispute?
    @Published var evidence: [DisputeEvidence] = []
    @Published var messages: [EscrowDisputeMessage] = []
    @Published var messageText = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?

    private let api: EscrowMarketAPIProtocol
    private let uploader: MediaUploader

    init(disputeId: Int, api: EscrowMarketAPIProtocol = EscrowMarketAPI(), uploader: MediaUploader? = nil) {
        self.disputeId = disputeId
        self.api = api
        self.uploader = uploader ?? MediaUploader()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { (dispute, evidence, messages) = try await api.disputeDetail(id: disputeId) }
        catch { errorMessage = "লোড করা যায়নি।" }
    }

    func addEvidence(fileURL: URL, description: String?) async {
        do {
            let secureURL = try await uploader.upload(fileURL: fileURL)
            try await api.addEvidence(
                disputeId: disputeId,
                AddEscrowEvidenceRequest(fileUrl: secureURL, fileType: fileURL.pathExtension, description: description)
            )
            await load()
        } catch {
            errorMessage = "এভিডেন্স আপলোড করা যায়নি।"
        }
    }

    func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        isSending = true
        defer { isSending = false }
        do {
            let message = try await api.sendMessage(disputeId: disputeId, body: text)
            messages.append(message)
        } catch {
            errorMessage = "মেসেজ পাঠানো যায়নি।"
        }
    }
}
