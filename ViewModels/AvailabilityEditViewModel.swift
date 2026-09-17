import Foundation

@MainActor
final class AvailabilityEditViewModel: ObservableObject {
    let listingId: Int
    @Published var schedule = BookingSchedule()
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let api: BookingAPIProtocol
    init(listingId: Int, api: BookingAPIProtocol = BookingAPI()) {
        self.listingId = listingId
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let slots = try await api.availability(listingId: listingId)
            if let first = slots.first {
                schedule.slotDurationMinutes = first.slotDurationMinutes
            }
            for slot in slots {
                schedule.days[slot.dayOfWeek] = BookingSchedule.DaySchedule(
                    active: slot.isActive, startTime: slot.startTime, endTime: slot.endTime
                )
            }
        } catch {
            errorMessage = "শিডিউল লোড করা যায়নি।"
        }
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await api.updateAvailability(listingId: listingId, schedule: schedule)
            successMessage = "শিডিউল আপডেট হয়েছে।"
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "সেভ করা যায়নি।"
        }
    }
}
