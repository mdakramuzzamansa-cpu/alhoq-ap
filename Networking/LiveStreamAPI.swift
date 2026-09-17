import Foundation

/// ⚠️ ASSUMPTION: path গুলো অনুমানভিত্তিক।
protocol LiveStreamAPIProtocol {
    func browse(page: Int) async throws -> APIEnvelope<[LiveStream]>
    func start(title: String?) async throws -> StartLiveResponse
    func end(streamId: Int) async throws -> LiveStream
    func hostHeartbeat(streamId: Int) async throws -> LiveStream
    func status(streamId: Int) async throws -> LiveStream
    func watchToken(streamId: Int) async throws -> StartLiveResponse
    func viewerHeartbeat(streamId: Int) async throws -> LiveStream
    func leave(streamId: Int) async throws
}

final class LiveStreamAPI: LiveStreamAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func browse(page: Int) async throws -> APIEnvelope<[LiveStream]> {
        try await client.request("live", query: ["page": String(page)], authenticated: false)
    }

    func start(title: String?) async throws -> StartLiveResponse {
        struct Body: Encodable { let title: String? }
        let envelope: APIEnvelope<StartLiveResponse> = try await client.request(
            "live/start", method: .post, body: Body(title: title)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func end(streamId: Int) async throws -> LiveStream {
        let envelope: APIEnvelope<LiveStatusResponse> = try await client.request("live/\(streamId)/end", method: .post)
        guard let data = envelope.data else { throw APIError.unknown }
        return data.stream
    }

    func hostHeartbeat(streamId: Int) async throws -> LiveStream {
        let envelope: APIEnvelope<LiveStatusResponse> = try await client.request(
            "live/\(streamId)/host-heartbeat", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data.stream
    }

    func status(streamId: Int) async throws -> LiveStream {
        let envelope: APIEnvelope<LiveStatusResponse> = try await client.request("live/\(streamId)/status")
        guard let data = envelope.data else { throw APIError.notFound }
        return data.stream
    }

    func watchToken(streamId: Int) async throws -> StartLiveResponse {
        let envelope: APIEnvelope<StartLiveResponse> = try await client.request(
            "live/\(streamId)/watch-token", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func viewerHeartbeat(streamId: Int) async throws -> LiveStream {
        let envelope: APIEnvelope<LiveStatusResponse> = try await client.request(
            "live/\(streamId)/heartbeat", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data.stream
    }

    func leave(streamId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("live/\(streamId)/leave", method: .post)
    }
}
