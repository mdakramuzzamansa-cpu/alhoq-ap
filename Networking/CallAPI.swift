import Foundation

/// ⚠️ ASSUMPTION: path গুলো অনুমানভিত্তিক। `history()` web-এ Blade view রিটার্ন করে
/// (JSON না) — তাই ধরে নিচ্ছি backend-এ এর একটা JSON/API সংস্করণ থাকবে বা বানাতে হবে।
protocol CallAPIProtocol {
    func start(userId: Int, type: AppCall.CallType) async throws -> StartCallResponse
    func poll() async throws -> CallPollResponse
    func status(callId: Int) async throws -> CallStatusResponse
    func accept(callId: Int) async throws -> StartCallResponse
    func reject(callId: Int) async throws -> AppCall
    func cancel(callId: Int) async throws -> AppCall
    func heartbeat(callId: Int) async throws
    func end(callId: Int) async throws -> AppCall
    func token(callId: Int) async throws -> RTCToken
    func history(page: Int) async throws -> APIEnvelope<[AppCall]>
}

final class CallAPI: CallAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func start(userId: Int, type: AppCall.CallType) async throws -> StartCallResponse {
        struct Body: Encodable { let type: String }
        let envelope: APIEnvelope<StartCallResponse> = try await client.request(
            "calls/start/\(userId)", method: .post, body: Body(type: type.rawValue)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func poll() async throws -> CallPollResponse {
        let envelope: APIEnvelope<CallPollResponse> = try await client.request("calls/poll")
        guard let data = envelope.data else { return CallPollResponse(incoming: nil, busyNotice: nil) }
        return data
    }

    func status(callId: Int) async throws -> CallStatusResponse {
        let envelope: APIEnvelope<CallStatusResponse> = try await client.request("calls/\(callId)/status")
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func accept(callId: Int) async throws -> StartCallResponse {
        let envelope: APIEnvelope<StartCallResponse> = try await client.request("calls/\(callId)/accept", method: .post)
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func reject(callId: Int) async throws -> AppCall {
        struct Response: Decodable { let call: AppCall }
        let envelope: APIEnvelope<Response> = try await client.request("calls/\(callId)/reject", method: .post)
        guard let data = envelope.data else { throw APIError.unknown }
        return data.call
    }

    func cancel(callId: Int) async throws -> AppCall {
        struct Response: Decodable { let call: AppCall }
        let envelope: APIEnvelope<Response> = try await client.request("calls/\(callId)/cancel", method: .post)
        guard let data = envelope.data else { throw APIError.unknown }
        return data.call
    }

    func heartbeat(callId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("calls/\(callId)/heartbeat", method: .post)
    }

    func end(callId: Int) async throws -> AppCall {
        struct Response: Decodable { let call: AppCall }
        let envelope: APIEnvelope<Response> = try await client.request("calls/\(callId)/end", method: .post)
        guard let data = envelope.data else { throw APIError.unknown }
        return data.call
    }

    func token(callId: Int) async throws -> RTCToken {
        let envelope: APIEnvelope<RTCToken> = try await client.request("calls/\(callId)/token")
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func history(page: Int) async throws -> APIEnvelope<[AppCall]> {
        try await client.request("calls/history", query: ["page": String(page)])
    }
}
