import Foundation

/// ⚠️ ASSUMPTION (আগের Phase গুলোর মতোই): path গুলো অনুমানভিত্তিক। Android API কনফার্ম হলে
/// এই ফাইলেই বদলাতে হবে।
protocol VerificationAPIProtocol {
    // Account-wide KYC (identity_verifications)
    func kycStatus() async throws -> IdentityVerification?
    func submitKyc(_ submission: IdentityVerificationSubmission) async throws -> IdentityVerification

    // Per-category "Get Trusted" (verifications + verification_values)
    func verificationRequirements(categoryId: Int) async throws -> CategoryVerificationRequirements
    func submitCategoryVerification(categoryId: Int, _ submission: CategoryVerificationSubmission) async throws -> CategoryVerification
}

final class VerificationAPI: VerificationAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func kycStatus() async throws -> IdentityVerification? {
        let envelope: APIEnvelope<IdentityVerification> = try await client.request("kyc/status")
        return envelope.data
    }

    func submitKyc(_ submission: IdentityVerificationSubmission) async throws -> IdentityVerification {
        let envelope: APIEnvelope<IdentityVerification> = try await client.request(
            "kyc", method: .post, body: submission
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func verificationRequirements(categoryId: Int) async throws -> CategoryVerificationRequirements {
        let envelope: APIEnvelope<CategoryVerificationRequirements> = try await client.request(
            "categories/\(categoryId)/verification"
        )
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func submitCategoryVerification(
        categoryId: Int, _ submission: CategoryVerificationSubmission
    ) async throws -> CategoryVerification {
        let envelope: APIEnvelope<CategoryVerification> = try await client.request(
            "categories/\(categoryId)/verification", method: .post, body: submission
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }
}
