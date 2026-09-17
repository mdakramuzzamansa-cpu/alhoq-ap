import Foundation
import CoreLocation

@MainActor
final class RegisterViewModel: NSObject, ObservableObject {
    @Published var form = RegisterFormState()
    @Published var fieldErrors: [String: String] = [:]     // local mirror of server validation
    @Published var serverErrors: [String: [String]] = [:]  // 422 থেকে সরাসরি আসা errors (duplicate email/phone ইত্যাদি)
    @Published var isLoading: Bool = false
    @Published var isDetectingLocation: Bool = false
    @Published var generalError: String?

    private let authAPI: AuthAPIProtocol
    private let session: SessionManager
    private var locationManager: CLLocationManager?

    init(authAPI: AuthAPIProtocol = AuthAPI(), session: SessionManager) {
        self.authAPI = authAPI
        self.session = session
    }

    // web: latitude/longitude "শুধু একসাথে আসে, GPS 'Detect My Location' থেকে" — লোকেশন স্কিপ করাও যায়
    func detectMyLocation() {
        isDetectingLocation = true
        let manager = CLLocationManager()
        manager.delegate = self
        self.locationManager = manager
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func submit() async {
        generalError = nil
        serverErrors = [:]
        fieldErrors = RegisterValidation.validate(form)
        guard fieldErrors.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await authAPI.register(form.toRequest())
            session.didAuthenticate(response)
        } catch let error as APIError {
            switch error {
            case .validation(let errors):
                // web: email/phone unique() ব্যর্থ হলে এখানে "email": ["The email has already been taken."] আসবে
                serverErrors = errors
            default:
                generalError = error.localizedDescription
            }
        } catch {
            generalError = "কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।"
        }
    }
}

extension RegisterViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.form.latitude = coordinate.latitude
            self.form.longitude = coordinate.longitude
            self.isDetectingLocation = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // web নিয়ম: location optional, ব্যর্থ হলেও registration ব্লক হবে না
        Task { @MainActor in self.isDetectingLocation = false }
    }
}
