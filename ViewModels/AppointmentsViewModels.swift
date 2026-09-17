import Foundation

@MainActor
final class MyAppointmentsViewModel: ObservableObject {
    @Published var bookings: [Booking] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: BookingAPIProtocol
    init(api: BookingAPIProtocol = BookingAPI()) { self.api = api }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let envelope = try await api.myAppointments(page: 1)
            bookings = envelope.data ?? []
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }
}

/// zip: Panel/BookingController — provider-এর নিজের listing-এ আসা বুকিং, status বদলানো
@MainActor
final class ProviderBookingsViewModel: ObservableObject {
    @Published var bookings: [Booking] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var updatingId: Int?

    private let api: BookingAPIProtocol
    init(api: BookingAPIProtocol = BookingAPI()) { self.api = api }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let envelope = try await api.incomingBookings(page: 1)
            bookings = envelope.data ?? []
        } catch {
            errorMessage = "লোড করা যায়নি।"
        }
    }

    func updateStatus(_ booking: Booking, to status: Booking.Status) async {
        updatingId = booking.id
        defer { updatingId = nil }
        do {
            let updated = try await api.updateBookingStatus(id: booking.id, status: status)
            if let index = bookings.firstIndex(where: { $0.id == booking.id }) {
                bookings[index] = updated
            }
        } catch {
            errorMessage = "স্ট্যাটাস আপডেট করা যায়নি।"
        }
    }
}
