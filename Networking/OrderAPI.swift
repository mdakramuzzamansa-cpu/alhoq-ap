import Foundation

/// ⚠️ ASSUMPTION (আগের সব Phase-এর মতোই): path গুলো অনুমানভিত্তিক।
///
/// এই মডিউলের payment/delivery/dispute-evidence — সবগুলোই Cloudinary secure_url নেয়
/// (raw file bytes কখনো এই endpoint গুলোতে যায় না), তাই `MediaUploader` আগে থেকেই যেভাবে
/// বানানো আছে (Phase 3-এ সংশোধিত) সরাসরি reuse হচ্ছে।
protocol OrderAPIProtocol {
    func createOrder(listingId: Int, _ request: CreateOrderRequest) async throws -> AlhoqOrder
    func buyingOrders(page: Int) async throws -> APIEnvelope<[AlhoqOrder]>
    func sellingOrders(page: Int) async throws -> APIEnvelope<[AlhoqOrder]>
    func orderDetail(id: Int) async throws -> OrderDetailResponse
    func cancelOrder(id: Int, reason: String?) async throws -> AlhoqOrder
    func setPayoutDestination(orderId: Int, _ request: SetPayoutDestinationRequest) async throws
    func availablePaymentMethods() async throws -> [PaymentMethodInfo]
    func submitPayment(orderId: Int, _ request: SubmitPaymentRequest) async throws -> AlhoqOrder
    func deliverOrder(orderId: Int, _ request: DeliverOrderRequest) async throws -> AlhoqOrder
    func acceptOrder(id: Int) async throws -> AlhoqOrder
    func requestRevision(orderId: Int, reason: String) async throws -> AlhoqOrder

    func openDispute(orderId: Int, reason: String) async throws -> Dispute
    func disputeDetail(id: Int) async throws -> (Dispute, [DisputeEvidence])
    func addEvidence(disputeId: Int, _ request: AddEvidenceRequest) async throws
    func withdrawDispute(id: Int) async throws
    func appealDispute(id: Int, reason: String) async throws
}

final class OrderAPI: OrderAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func createOrder(listingId: Int, _ request: CreateOrderRequest) async throws -> AlhoqOrder {
        let envelope: APIEnvelope<AlhoqOrder> = try await client.request(
            "listings/\(listingId)/order", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func buyingOrders(page: Int) async throws -> APIEnvelope<[AlhoqOrder]> {
        try await client.request("orders", query: ["role": "buying", "page": String(page)])
    }

    func sellingOrders(page: Int) async throws -> APIEnvelope<[AlhoqOrder]> {
        try await client.request("orders", query: ["role": "selling", "page": String(page)])
    }

    func orderDetail(id: Int) async throws -> OrderDetailResponse {
        let envelope: APIEnvelope<OrderDetailResponse> = try await client.request("orders/\(id)")
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func cancelOrder(id: Int, reason: String?) async throws -> AlhoqOrder {
        let envelope: APIEnvelope<AlhoqOrder> = try await client.request(
            "orders/\(id)/cancel", method: .post, body: CancelOrderRequest(reason: reason)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func setPayoutDestination(orderId: Int, _ request: SetPayoutDestinationRequest) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "orders/\(orderId)/payout-destination", method: .post, body: request
        )
    }

    func availablePaymentMethods() async throws -> [PaymentMethodInfo] {
        let envelope: APIEnvelope<[PaymentMethodInfo]> = try await client.request("orders/payment-methods")
        return envelope.data ?? []
    }

    func submitPayment(orderId: Int, _ request: SubmitPaymentRequest) async throws -> AlhoqOrder {
        let envelope: APIEnvelope<AlhoqOrder> = try await client.request(
            "orders/\(orderId)/payment", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func deliverOrder(orderId: Int, _ request: DeliverOrderRequest) async throws -> AlhoqOrder {
        let envelope: APIEnvelope<AlhoqOrder> = try await client.request(
            "orders/\(orderId)/delivery", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func acceptOrder(id: Int) async throws -> AlhoqOrder {
        let envelope: APIEnvelope<AlhoqOrder> = try await client.request("orders/\(id)/accept", method: .post)
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func requestRevision(orderId: Int, reason: String) async throws -> AlhoqOrder {
        let envelope: APIEnvelope<AlhoqOrder> = try await client.request(
            "orders/\(orderId)/revision", method: .post, body: RequestRevisionRequest(reason: reason)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func openDispute(orderId: Int, reason: String) async throws -> Dispute {
        let envelope: APIEnvelope<Dispute> = try await client.request(
            "orders/\(orderId)/dispute", method: .post, body: OpenDisputeRequest(reason: reason)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func disputeDetail(id: Int) async throws -> (Dispute, [DisputeEvidence]) {
        struct Response: Decodable { let dispute: Dispute; let evidence: [DisputeEvidence] }
        let envelope: APIEnvelope<Response> = try await client.request("disputes/\(id)")
        guard let data = envelope.data else { throw APIError.notFound }
        return (data.dispute, data.evidence)
    }

    func addEvidence(disputeId: Int, _ request: AddEvidenceRequest) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "disputes/\(disputeId)/evidence", method: .post, body: request
        )
    }

    func withdrawDispute(id: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("disputes/\(id)/withdraw", method: .post)
    }

    func appealDispute(id: Int, reason: String) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "disputes/\(id)/appeal", method: .post, body: AppealDisputeRequest(reason: reason)
        )
    }
}
