import Foundation

@MainActor
final class PackagesViewModel: ObservableObject {
    @Published var packages: [SubscriptionPackage] = []
    @Published var activePackage: UserPackage?
    @Published var isLoading = false
    @Published var checkoutURL: URL?
    @Published var isStartingCheckout = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let api: CheckoutAPIProtocol
    init(api: CheckoutAPIProtocol = CheckoutAPI()) { self.api = api }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let pkgs = api.packages()
        async let active = api.activePackage()
        packages = (try? await pkgs) ?? []
        activePackage = try? await active
    }

    func startCheckout(for package: SubscriptionPackage) async {
        isStartingCheckout = true
        errorMessage = nil
        defer { isStartingCheckout = false }
        do {
            let session = try await api.startPackageCheckout(packageId: package.id)
            checkoutURL = URL(string: session.checkoutUrl)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "চেকআউট শুরু করা যায়নি।"
        }
    }

    func handleOutcome(_ outcome: CheckoutOutcome) async {
        checkoutURL = nil
        switch outcome {
        case .cancelled:
            errorMessage = "পেমেন্ট বাতিল করা হয়েছে।"
        case .success(let sessionId):
            guard let sessionId else { await load(); return }
            do {
                if let userPackage = try await api.confirmPackageFulfillment(sessionId: sessionId) {
                    activePackage = userPackage
                    successMessage = "প্যাকেজ সক্রিয় হয়েছে!"
                }
            } catch {
                errorMessage = "নিশ্চিত করা যায়নি — একটু পর আবার চেক করুন।"
            }
            await load()
        }
    }
}
