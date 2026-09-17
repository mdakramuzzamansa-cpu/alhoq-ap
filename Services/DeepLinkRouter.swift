import Foundation
import SwiftUI

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    @Published var pendingURL: String?
}

/// zip-এর notification.url আসলে **web** route (যেমন "https://alhoq.com/panel/bookings/5")।
/// iOS নিজের নেটিভ স্ক্রিনে ম্যাপ করার চেষ্টা করে পরিচিত প্যাটার্নের জন্য, নাহলে raw URL
/// একটা in-app WKWebView-তে খুলে দেয় (fallback) — কোনো লিংকই "মৃত" থাকে না।
enum DeepLinkDestination: Hashable {
    case order(id: Int)
    case escrowOrder(id: Int)
    case chatConversation(id: Int)
    case booking
    case sellerProfile(userId: Int)
    case postDetail(id: Int)
    case unknown(urlString: String)

    static func parse(_ urlString: String) -> DeepLinkDestination {
        guard let url = URL(string: urlString) else { return .unknown(urlString: urlString) }
        let parts = url.pathComponents.filter { $0 != "/" }

        if let idx = parts.firstIndex(of: "orders"), idx + 1 < parts.count, let id = Int(parts[idx + 1]) {
            return parts.contains("escrow-marketplace") ? .escrowOrder(id: id) : .order(id: id)
        }
        if let idx = parts.firstIndex(of: "conversations"), idx + 1 < parts.count, let id = Int(parts[idx + 1]) {
            return .chatConversation(id: id)
        }
        // zip কনফার্ম করা route: Route::get('/seller/{user}', ...)->name('seller.profile')
        // {user} route-model-binding দিয়ে numeric id — username না
        if let idx = parts.firstIndex(of: "seller"), idx + 1 < parts.count, let id = Int(parts[idx + 1]) {
            return .sellerProfile(userId: id)
        }
        // zip কনফার্ম করা route: root PostController@show permalink
        if let idx = parts.firstIndex(of: "posts"), idx + 1 < parts.count, let id = Int(parts[idx + 1]) {
            return .postDetail(id: id)
        }
        if parts.contains("bookings") || parts.contains("appointments") {
            return .booking
        }
        return .unknown(urlString: urlString)
    }
}

/// RootView-তে বসানো একটা modifier — DeepLinkRouter.pendingURL সেট হলেই উপযুক্ত স্ক্রিন খোলে
struct DeepLinkHandler: ViewModifier {
    @ObservedObject var router = DeepLinkRouter.shared
    let currentUserId: Int
    @State private var destination: DeepLinkDestination?

    func body(content: Content) -> some View {
        content
            .onChange(of: router.pendingURL) { _, newValue in
                guard let newValue else { return }
                destination = DeepLinkDestination.parse(newValue)
                router.pendingURL = nil
            }
            .fullScreenCover(item: $destination) { destination in
                NavigationStack {
                    Group {
                        switch destination {
                        case .order(let id):
                            OrderDetailView(orderId: id, currentUserId: currentUserId)
                        case .escrowOrder(let id):
                            EscrowOrderDetailView(orderId: id, currentUserId: currentUserId)
                        case .chatConversation(let id):
                            ChatThreadView(conversationId: id)
                        case .booking:
                            MyAppointmentsView()
                        case .sellerProfile(let userId):
                            SellerProfileView(userId: userId)
                        case .postDetail(let id):
                            PostDetailView(postId: id, currentUserId: currentUserId)
                        case .unknown(let urlString):
                            if let url = URL(string: urlString) {
                                CheckoutWebView(checkoutURL: url, successPath: "__none__", cancelPath: "__none__") { _ in }
                            } else {
                                Text("খোলা যায়নি")
                            }
                        }
                    }
                    .toolbar {
                        cancelToolbarItem("বন্ধ করুন") { self.destination = nil }
                    }
                }
            }
    }
}

extension DeepLinkDestination: Identifiable {
    var id: String {
        switch self {
        case .order(let id): return "order-\(id)"
        case .escrowOrder(let id): return "escrow-\(id)"
        case .chatConversation(let id): return "chat-\(id)"
        case .booking: return "booking"
        case .sellerProfile(let userId): return "seller-\(userId)"
        case .postDetail(let id): return "post-\(id)"
        case .unknown(let urlString): return "unknown-\(urlString)"
        }
    }
}

extension View {
    func handleDeepLinks(currentUserId: Int) -> some View {
        modifier(DeepLinkHandler(currentUserId: currentUserId))
    }
}
