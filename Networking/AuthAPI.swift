import Foundation

/// ⚠️ ASSUMPTION — যাচাই করা দরকার:
/// নিচের path গুলো (`auth/login`, `auth/register`, `auth/logout`, `auth/me`) আমার অনুমান,
/// কারণ Android চ্যাটে বানানো আসল `/api/v1/auth/...` route list আমি দেখিনি।
/// Android-side backend থেকে exact route names (`routes/api.php`) পেলে শুধু এই একটা ফাইলের
/// path string বদলালেই যথেষ্ট হবে — বাকি অ্যাপের কোনো কোড বদলাতে হবে না।
///
/// ❌ NOTE: web-এ (`Auth/AuthController.php`, `routes/web.php`) কোনো forgot/reset-password
/// route নেই — অর্থাৎ Password Recovery (spec Section 4.4) web-এ এখনো implement করা হয়নি।
/// Rule 15 অনুযায়ী "ZIP এর সাথে ডকুমেন্ট মিলবে না — ZIP জেতে" — তাই এখানে forgot-password
/// API/UI বানানো হয়নি (বানালে এমন একটা ফিচার হবে যেটার সাথে মেলানোর মতো backend নেই)।
/// Android API-তে যদি ইতিমধ্যে password-reset endpoint যোগ করা হয়ে থাকে, জানালে এই ফাইলে যোগ করে দেব।
protocol AuthAPIProtocol {
    func login(_ request: LoginRequest) async throws -> AuthResponse
    func register(_ request: RegisterRequest) async throws -> AuthResponse
    func logout() async throws
    func me() async throws -> AlhoqUser
}

final class AuthAPI: AuthAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func login(_ request: LoginRequest) async throws -> AuthResponse {
        let envelope: APIEnvelope<AuthResponse> = try await client.request(
            "auth/login", method: .post, body: request, authenticated: false
        )
        guard let data = envelope.data else { throw APIError.unauthorized }
        return data
    }

    func register(_ request: RegisterRequest) async throws -> AuthResponse {
        let envelope: APIEnvelope<AuthResponse> = try await client.request(
            "auth/register", method: .post, body: request, authenticated: false
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func logout() async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("auth/logout", method: .post)
    }

    func me() async throws -> AlhoqUser {
        let envelope: APIEnvelope<AlhoqUser> = try await client.request("auth/me")
        guard let data = envelope.data else { throw APIError.sessionExpired }
        return data
    }
}
