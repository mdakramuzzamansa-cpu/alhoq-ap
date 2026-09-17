import Foundation

@MainActor
final class BookingCreateViewModel: ObservableObject {
    let listing: Listing

    @Published var activeWeekdays: Set<Int> = []
    @Published var selectedDate = Date()
    @Published var availableSlots: [String] = []
    @Published var selectedSlot: String?
    @Published var notes: String = ""
    @Published var isLoadingSlots = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var createdBooking: Booking?

    private let api: BookingAPIProtocol

    init(listing: Listing, api: BookingAPIProtocol = BookingAPI()) {
        self.listing = listing
        self.api = api
    }

    func loadWeekdays() async {
        activeWeekdays = Set((try? await api.activeWeekdays(listingId: listing.id)) ?? [])
    }

    /// web: ক্যালেন্ডারে যেসব দিনে কোনো slot-ই কখনো থাকবে না সেগুলো গ্রে-আউট
    func isDateDisabled(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date) - 1 // 0=Sunday, web কনভেনশন
        return !activeWeekdays.contains(weekday) || date < Calendar.current.startOfDay(for: Date())
    }

    func dateChanged() async {
        selectedSlot = nil
        isLoadingSlots = true
        defer { isLoadingSlots = false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        do {
            availableSlots = try await api.slots(listingId: listing.id, date: formatter.string(from: selectedDate))
        } catch {
            availableSlots = []
        }
    }

    func submit() async {
        guard let selectedSlot else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        do {
            let request = CreateBookingRequest(
                bookingDate: formatter.string(from: selectedDate),
                bookingTime: selectedSlot,
                notes: notes.isEmpty ? nil : notes
            )
            createdBooking = try await api.createBooking(listingId: listing.id, request)
        } catch let error as APIError {
            switch error {
            case .validation(let errors):
                // web: "That time slot was just taken by someone else" — race condition handling
                errorMessage = errors.values.first?.first ?? "এই সময়টা এইমাত্র বুক হয়ে গেছে। অন্য সময় বেছে নিন।"
                await dateChanged() // fresh slot list আবার লোড
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "বুকিং করা যায়নি। আবার চেষ্টা করুন।"
        }
    }
}
