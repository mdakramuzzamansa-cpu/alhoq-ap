import Foundation

/// ⚠️ ASSUMPTION (আগের সব Phase-এর মতোই): path গুলো অনুমানভিত্তিক।
protocol EscrowMarketAPIProtocol {
    /// zip: Escrow/EscrowController@index — marketplace_escrow_enabled ক্যাটাগরির সব published listing
    func browse(search: String, categoryId: Int?, page: Int) async throws -> APIEnvelope<[Listing]>
    func feeBreakdown(listingId: Int) async throws -> EscrowFeeBreakdown

    func createOrder(listingId: Int, _ request: CreateEscrowOrderRequest) async throws -> EscrowMarketOrder
    func orders(as role: String, page: Int) async throws -> APIEnvelope<[EscrowMarketOrder]>
    func orderDetail(id: Int) async throws -> EscrowMarketOrder
    func availablePaymentMethods() async throws -> [PaymentMethodInfo]
    func submitPayment(orderId: Int, _ request: SubmitEscrowPaymentRequest) async throws -> EscrowMarketOrder
    func deliver(orderId: Int, _ request: DeliverEscrowOrderRequest) async throws -> EscrowMarketOrder
    func accept(orderId: Int) async throws -> EscrowMarketOrder
    func requestRevision(orderId: Int, notes: String) async throws -> EscrowMarketOrder
    func cancel(orderId: Int) async throws -> EscrowMarketOrder

    func openDispute(orderId: Int, reason: String) async throws -> EscrowDispute
    func disputeDetail(id: Int) async throws -> (EscrowDispute, [DisputeEvidence], [EscrowDisputeMessage])
    func addEvidence(disputeId: Int, _ request: AddEscrowEvidenceRequest) async throws
    func sendMessage(disputeId: Int, body: String) async throws -> EscrowDisputeMessage
}

final class EscrowMarketAPI: EscrowMarketAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func browse(search: String, categoryId: Int?, page: Int) async throws -> APIEnvelope<[Listing]> {
        var query = ["page": String(page)]
        if !search.isEmpty { query["search"] = search }
        if let categoryId { query["category_id"] = String(categoryId) }
        return try await client.request("escrow-marketplace/listings", query: query, authenticated: false)
    }

    func feeBreakdown(listingId: Int) async throws -> EscrowFeeBreakdown {
        let envelope: APIEnvelope<EscrowFeeBreakdown> = try await client.request(
            "escrow-marketplace/listings/\(listingId)/fee-breakdown"
        )
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func createOrder(listingId: Int, _ request: CreateEscrowOrderRequest) async throws -> EscrowMarketOrder {
        let envelope: APIEnvelope<EscrowMarketOrder> = try await client.request(
            "escrow-marketplace/listings/\(listingId)/orders", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func orders(as role: String, page: Int) async throws -> APIEnvelope<[EscrowMarketOrder]> {
        try await client.request("escrow-marketplace/orders", query: ["as": role, "page": String(page)])
    }

    func orderDetail(id: Int) async throws -> EscrowMarketOrder {
        let envelope: APIEnvelope<EscrowMarketOrder> = try await client.request("escrow-marketplace/orders/\(id)")
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func availablePaymentMethods() async throws -> [PaymentMethodInfo] {
        // zip: Escrow/EscrowPaymentSetting — Direct-Deal-এর AlhoqSetting থেকে আলাদা মডেল/টেবিল,
        // তাই আলাদা endpoint ধরে নেওয়া হয়েছে (একই shape, ভিন্ন সোর্স)
        let envelope: APIEnvelope<[PaymentMethodInfo]> = try await client.request("escrow-marketplace/payment-methods")
        return envelope.data ?? []
    }

    func submitPayment(orderId: Int, _ request: SubmitEscrowPaymentRequest) async throws -> EscrowMarketOrder {
        let envelope: APIEnvelope<EscrowMarketOrder> = try await client.request(
            "escrow-marketplace/orders/\(orderId)/payment", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func deliver(orderId: Int, _ request: DeliverEscrowOrderRequest) async throws -> EscrowMarketOrder {
        let envelope: APIEnvelope<EscrowMarketOrder> = try await client.request(
            "escrow-marketplace/orders/\(orderId)/deliver", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func accept(orderId: Int) async throws -> EscrowMarketOrder {
        let envelope: APIEnvelope<EscrowMarketOrder> = try await client.request(
            "escrow-marketplace/orders/\(orderId)/accept", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func requestRevision(orderId: Int, notes: String) async throws -> EscrowMarketOrder {
        let envelope: APIEnvelope<EscrowMarketOrder> = try await client.request(
            "escrow-marketplace/orders/\(orderId)/revision", method: .post,
            body: RequestEscrowRevisionRequest(notes: notes)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func cancel(orderId: Int) async throws -> EscrowMarketOrder {
        let envelope: APIEnvelope<EscrowMarketOrder> = try await client.request(
            "escrow-marketplace/orders/\(orderId)/cancel", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func openDispute(orderId: Int, reason: String) async throws -> EscrowDispute {
        let envelope: APIEnvelope<EscrowDispute> = try await client.request(
            "escrow-marketplace/orders/\(orderId)/dispute", method: .post,
            body: OpenEscrowDisputeRequest(reason: reason)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func disputeDetail(id: Int) async throws -> (EscrowDispute, [DisputeEvidence], [EscrowDisputeMessage]) {
        struct Response: Decodable {
            let dispute: EscrowDispute; let evidence: [DisputeEvidence]; let messages: [EscrowDisputeMessage]
        }
        let envelope: APIEnvelope<Response> = try await client.request("escrow-marketplace/disputes/\(id)")
        guard let data = envelope.data else { throw APIError.notFound }
        return (data.dispute, data.evidence, data.messages)
    }

    func addEvidence(disputeId: Int, _ request: AddEscrowEvidenceRequest) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "escrow-marketplace/disputes/\(disputeId)/evidence", method: .post, body: request
        )
    }

    func sendMessage(disputeId: Int, body: String) async throws -> EscrowDisputeMessage {
        let envelope: APIEnvelope<EscrowDisputeMessage> = try await client.request(
            "escrow-marketplace/disputes/\(disputeId)/messages", method: .post,
            body: SendEscrowDisputeMessageRequest(body: body)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }
}
