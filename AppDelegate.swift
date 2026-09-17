import UIKit
import UserNotifications

/// ⚠️ ASSUMPTION: push payload-এর আসল shape backend এখনো ঠিক করেনি (web-এর VAPID payload
/// থেকে আলাদা হতে হবে — APNs-এর জন্য alert.title/alert.body + একটা custom "url" key
/// ধরে নেওয়া হয়েছে, ঠিক bellItems()-এর shape-এর সাথে মিলিয়ে)। আসল payload কনফার্ম হলে
/// শুধু DeepLinkRouter.extractURL()-এ বদলালেই চলবে।
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushRegistrationManager.shared.didReceiveDeviceToken(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // web parity নোট: browser push subscription ব্যর্থ হলেও অ্যাপ স্বাভাবিকভাবে চলতে থাকে,
        // শুধু push notification পাবে না — এখানে একই আচরণ, silent fail
    }

    // অ্যাপ foreground-এ থাকা অবস্থায়ও notification banner/sound দেখানো (web-এ ট্যাব ফোকাসড থাকলেও
    // browser notification আসত না, কিন্তু bell badge/realtime দিয়ে বোঝা যেত — iOS-এ আমরা visible push-ই রাখছি)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let urlString = userInfo["url"] as? String {
            DeepLinkRouter.shared.pendingURL = urlString
        }
    }
}
