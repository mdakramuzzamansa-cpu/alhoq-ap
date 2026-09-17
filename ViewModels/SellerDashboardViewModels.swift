import Foundation

@MainActor
final class SellerProfileViewModel: ObservableObject {
    let userId: Int
    @Published var profile: SellerProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: SellerDashboardAPIProtocol = SellerDashboardAPI()
    init(userId: Int) { self.userId = userId }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { profile = try await api.sellerProfile(userId: userId) }
        catch let error as APIError {
            if case .notFound = error { errorMessage = "এই ইউজার খুঁজে পাওয়া যায়নি।" }
            else { errorMessage = error.localizedDescription }
        } catch { errorMessage = "লোড করা যায়নি।" }
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var dashboard: DashboardStats?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: SellerDashboardAPIProtocol = SellerDashboardAPI()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { dashboard = try await api.myDashboard() }
        catch { errorMessage = "লোড করা যায়নি।" }
    }
}
