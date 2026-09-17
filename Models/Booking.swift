import Foundation

/// zip: app/Models/Booking.php + BookingController@store — প্রতিটা ফিল্ড হুবহু
struct Booking: Codable, Identifiable, Equatable {
    let id: Int
    var listingId: Int
    var listing: Listing?
    var userId: Int
    var name: String
    var email: String?
    var phone: String?
    var bookingDate: String     // "YYYY-MM-DD"
    var bookingTime: String     // "H:i"
    var dailySerial: Int        // "আপনি এই দিনে এই প্রোভাইডারের ৩য় সিরিয়াল" — টোকেন নম্বর
    var notes: String?
    var amount: Double?
    var paymentStatus: PaymentStatus
    var status: Status

    enum PaymentStatus: String, Codable { case unpaid, paid }

    enum Status: String, Codable {
        case pending, confirmed, cancelled, completed

        var label: String {
            switch self {
            case .pending: return "অপেক্ষমাণ"
            case .confirmed: return "নিশ্চিত"
            case .cancelled: return "বাতিল"
            case .completed: return "সম্পন্ন"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case listing
        case userId = "user_id"
        case name, email, phone
        case bookingDate = "booking_date"
        case bookingTime = "booking_time"
        case dailySerial = "daily_serial"
        case notes, amount
        case paymentStatus = "payment_status"
        case status
    }
}

/// zip: BookingController@store validation
struct CreateBookingRequest: Encodable {
    let bookingDate: String
    let bookingTime: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case bookingDate = "booking_date"
        case bookingTime = "booking_time"
        case notes
    }
}

/// zip: app/Models/AvailabilitySlot.php + Panel/AvailabilityController — provider-এর সেভ করা শিডিউল,
/// day_of_week দিয়ে key করা (0=রবিবার..6=শনিবার)
struct AvailabilitySlot: Codable, Equatable {
    var dayOfWeek: Int
    var startTime: String
    var endTime: String
    var slotDurationMinutes: Int
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
        case slotDurationMinutes = "slot_duration_minutes"
        case isActive = "is_active"
    }
}
