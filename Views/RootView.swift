import SwiftUI

struct RootView: View {
    @StateObject private var session = SessionManager()
    @StateObject private var notificationsBadge = NotificationsViewModel()

    var body: some View {
        Group {
            switch session.state {
            case .restoring:
                SplashView()
            case .guest:
                LoginView(session: session)
            case .authenticated(let user):
                TabView {
                    ListingFeedView()
                        .tabItem { Label("হোম", systemImage: "house") }

                    FeedView(currentUserId: user.id)
                        .tabItem { Label("ফিড", systemImage: "photo.stack") }

                    InboxView()
                        .tabItem { Label("চ্যাট", systemImage: "message") }

                    MyListingsView()
                        .tabItem { Label("আমার লিস্টিং", systemImage: "list.bullet.rectangle") }

                    NavigationStack { NotificationsView(currentUserId: user.id) }
                        .tabItem { Label("নোটিফিকেশন", systemImage: "bell") }
                        .badge(notificationsBadge.unreadCount)

                    ProfileView(user: user)
                        .tabItem { Label("প্রোফাইল", systemImage: "person") }
                }
                .handleDeepLinks(currentUserId: user.id)
                .task {
                    PushRegistrationManager.shared.requestAuthorizationAndRegister()
                    notificationsBadge.startPolling()
                    CallManager.shared.startIdlePolling()
                }
                .onDisappear {
                    notificationsBadge.stopPolling()
                    CallManager.shared.stopIdlePolling()
                }
                .overlay { CallOverlay() }
            }
        }
        .environmentObject(session)
    }
}
