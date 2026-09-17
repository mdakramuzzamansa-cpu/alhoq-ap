import Foundation
import SwiftUI

/// Spec Section 4.1 (Splash) + 4.5 (Session):
/// branding → session restoration → route to Login or authenticated Home.
/// secure token storage, expiry handling, auto logout, clear session, redirect to Login.
@MainActor
final class SessionManager: ObservableObject {
    enum State {
        case restoring       // Splash দেখানো হচ্ছে, session check চলছে
        case guest           // Login/Register দেখাতে হবে
        case authenticated(AlhoqUser)
    }

    @Published private(set) var state: State = .restoring

    private let authAPI: AuthAPIProtocol
    private let tokenStore: TokenStore

    init(authAPI: AuthAPIProtocol = AuthAPI(), tokenStore: TokenStore = KeychainTokenStore.shared) {
        self.authAPI = authAPI
        self.tokenStore = tokenStore
    }

    /// অ্যাপ চালু হওয়ার সাথে সাথে Splash-এ কল হবে।
    func restoreSession() async {
        guard tokenStore.token != nil else {
            state = .guest
            return
        }
        do {
            let user = try await authAPI.me()
            state = .authenticated(user)
        } catch {
            // token থাকলেও অকার্যকর/expired — session cleared, Login-এ পাঠাও
            tokenStore.clear()
            state = .guest
        }
    }

    func didAuthenticate(_ response: AuthResponse) {
        tokenStore.save(response.token)
        state = .authenticated(response.user)
    }

    /// Section 4.5: auto logout / clear session / redirect to Login — সার্ভার কল fail
    /// হলেও local session সবসময় ক্লিয়ার হবে, যাতে ইউজার আটকে না থাকে।
    func logout() async {
        PushRegistrationManager.shared.unregister()
        try? await authAPI.logout()
        tokenStore.clear()
        state = .guest
    }
}
