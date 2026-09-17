import Foundation

@MainActor
final class MyListingsViewModel: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var deletingId: Int?

    private let api: ListingAPIProtocol

    init(api: ListingAPIProtocol = ListingAPI()) {
        self.api = api
    }

    /// Section 5.7: active/pending/expired — status অনুযায়ী গ্রুপ করা, web-এর behavior অনুযায়ী
    var grouped: [(status: Listing.Status, items: [Listing])] {
        let order: [Listing.Status] = [.published, .pending, .draft, .rejected, .expired]
        return order.compactMap { status in
            let items = listings.filter { $0.status == status }
            return items.isEmpty ? nil : (status, items)
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let envelope = try await api.myListings(page: 1)
            listings = envelope.data ?? []
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "লিস্টিং লোড করা যায়নি।"
        }
    }

    /// Rule 9: destructive action confirmation UI-লেয়ারে হবে (View-তে alert), এখানে শুধু actual delete call
    func delete(_ listing: Listing) async {
        deletingId = listing.id
        defer { deletingId = nil }
        do {
            try await api.delete(id: listing.id)
            listings.removeAll { $0.id == listing.id }
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "ডিলিট করা যায়নি।"
        }
    }
}
