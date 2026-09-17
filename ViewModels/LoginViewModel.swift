import Foundation
import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var login: String = ""          // email অথবা phone — web-এর মতো একটাই ফিল্ড
    @Published var password: String = ""
    @Published var isPasswordVisible: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?        // web: back()->withErrors(['login' => ...])

    private let authAPI: AuthAPIProtocol
    private let session: SessionManager

    init(authAPI: AuthAPIProtocol = AuthAPI(), session: SessionManager) {
        self.authAPI = authAPI
        self.session = session
    }

    var canSubmit: Bool {
        !login.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading
    }

    func submit() async {
        errorMessage = nil
        guard canSubmit else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await authAPI.login(LoginRequest(login: login, password: password))
            session.didAuthenticate(response)
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                errorMessage = "ইমেইল/ফোন অথবা পাসওয়ার্ড সঠিক নয়।" // web: "Invalid email/phone or password."
            case .validation(let fields):
                errorMessage = fields.values.first?.first ?? error.localizedDescription
            case .server(let message) where message.lowercased().contains("throttle"):
                errorMessage = "অনেকবার চেষ্টা করা হয়েছে — একটু পর আবার চেষ্টা করুন।" // web: throttle:login middleware
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।"
        }
    }
}
