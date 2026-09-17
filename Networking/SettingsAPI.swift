import Foundation

/// zip: Panel/SettingsController@update validation হুবহু
struct UpdateSettingsRequest: Encodable {
    var callsEnabled: Bool
    var smsEnabled: Bool
    var chatEnabled: Bool
    var payoutMethod: String?   // bkash | nagad | rocket | bank_transfer
    var payoutAccount: String?
    var password: String?
    var passwordConfirmation: String?

    enum CodingKeys: String, CodingKey {
        case callsEnabled = "calls_enabled"
        case smsEnabled = "sms_enabled"
        case chatEnabled = "chat_enabled"
        case payoutMethod = "payout_method"
        case payoutAccount = "payout_account"
        case password
        case passwordConfirmation = "password_confirmation"
    }
}

protocol SettingsAPIProtocol {
    func updateSettings(_ request: UpdateSettingsRequest) async throws -> AlhoqUser
}

final class SettingsAPI: SettingsAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func updateSettings(_ request: UpdateSettingsRequest) async throws -> AlhoqUser {
        let envelope: APIEnvelope<AlhoqUser> = try await client.request(
            "panel/settings", method: .put, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }
}
