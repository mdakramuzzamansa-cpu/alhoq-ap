import Foundation

/// ⚠️ backend gap (আগের কয়েকটার মতোই): `HandshakeController@index` Blade view রিটার্ন করে।
/// নিচের `myHandshakes()` তাই একটা assumed JSON endpoint (`GET /handshakes`) ধরে লেখা।
protocol HandshakeAPIProtocol {
    func send(userId: Int, type: Handshake.HandshakeType) async throws -> Handshake
    func myHandshakes() async throws -> HandshakesIndexResponse
    func accept(handshakeId: Int) async throws -> Handshake
    func decline(handshakeId: Int) async throws -> Handshake
    func disconnect(handshakeId: Int) async throws
}

final class HandshakeAPI: HandshakeAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func send(userId: Int, type: Handshake.HandshakeType) async throws -> Handshake {
        struct Body: Encodable { let type: String }
        let envelope: APIEnvelope<Handshake> = try await client.request(
            "handshakes/\(userId)", method: .post, body: Body(type: type.rawValue)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func myHandshakes() async throws -> HandshakesIndexResponse {
        let envelope: APIEnvelope<HandshakesIndexResponse> = try await client.request("handshakes")
        guard let data = envelope.data else {
            return HandshakesIndexResponse(received: [], sent: [], connections: [])
        }
        return data
    }

    func accept(handshakeId: Int) async throws -> Handshake {
        let envelope: APIEnvelope<Handshake> = try await client.request(
            "handshakes/\(handshakeId)/accept", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func decline(handshakeId: Int) async throws -> Handshake {
        let envelope: APIEnvelope<Handshake> = try await client.request(
            "handshakes/\(handshakeId)/decline", method: .post
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func disconnect(handshakeId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "handshakes/\(handshakeId)/disconnect", method: .delete
        )
    }
}
