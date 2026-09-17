import Foundation

/// ⚠️ backend gap (এখন পরিচিত প্যাটার্ন): `SellerProfileController@show` ও
/// `Panel/DashboardController@index` দুটোই Blade view রিটার্ন করে — assumed JSON endpoint।
protocol SellerDashboardAPIProtocol {
    func sellerProfile(userId: Int) async throws -> SellerProfile
    func myDashboard() async throws -> DashboardStats
}

final class SellerDashboardAPI: SellerDashboardAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func sellerProfile(userId: Int) async throws -> SellerProfile {
        let envelope: APIEnvelope<SellerProfile> = try await client.request(
            "sellers/\(userId)", authenticated: false
        )
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func myDashboard() async throws -> DashboardStats {
        let envelope: APIEnvelope<DashboardStats> = try await client.request("panel/dashboard")
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }
}
