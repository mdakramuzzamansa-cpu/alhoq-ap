import Foundation
import UserNotifications
import UIKit

@MainActor
final class PushRegistrationManager: ObservableObject {
    static let shared = PushRegistrationManager()
    private let api: PushTokenAPIProtocol = PushTokenAPI()
    private var lastRegisteredToken: String?

    func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func didReceiveDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        guard token != lastRegisteredToken else { return }
        lastRegisteredToken = token
        Task { try? await api.registerDeviceToken(token) }
    }

    func unregister() {
        guard let token = lastRegisteredToken else { return }
        Task { try? await api.unregisterDeviceToken(token) }
        lastRegisteredToken = nil
    }
}
