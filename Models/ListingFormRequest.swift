import Foundation

/// zip: app/Http/Controllers/Panel/ListingController.php@validateListing() — প্রতিটা rule হুবহু:
/// category_id required|exists, title required|max:255, description required|max:10000,
/// price_type required|in:fixed,negotiable,free,on_request, target_scope required|in:local_only,everywhere,
/// image_urls required|array|min:1|max:10 (create-এ), max:10 (edit-এ nullable),
/// schedule.* শুধু enable_booking_schedule true হলে প্রযোজ্য।
struct ListingFormRequest: Encodable {
    let categoryId: Int
    let title: String
    let description: String
    let metaTitle: String?
    let metaDescription: String?
    let price: Double?
    let priceType: Listing.PriceType
    let requiresPayment: Bool
    let alhoqDeliveryHours: Int?
    let alhoqMaxRevisions: Int?
    let location: String?
    let targetScope: Listing.TargetScope
    let latitude: Double?
    let longitude: Double?
    let contactPhone: String?
    let contactEmail: String?
    let isAnonymous: Bool           // ক্যাটাগরিতে allow_anonymous না থাকলে সার্ভার এমনিতেই ignore করবে (web parity)
    let imageUrls: [String]         // Universal Media Upload থেকে পাওয়া URL — min 1 (create), max 10
    let removeImageIds: [Int]?      // শুধু edit-এ ব্যবহৃত
    let enableBookingSchedule: Bool
    let schedule: BookingSchedule?

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case title, description
        case metaTitle = "meta_title"
        case metaDescription = "meta_description"
        case price
        case priceType = "price_type"
        case requiresPayment = "requires_payment"
        case alhoqDeliveryHours = "alhoq_delivery_hours"
        case alhoqMaxRevisions = "alhoq_max_revisions"
        case location
        case targetScope = "target_scope"
        case latitude, longitude
        case contactPhone = "contact_phone"
        case contactEmail = "contact_email"
        case isAnonymous = "is_anonymous"
        case imageUrls = "image_urls"
        case removeImageIds = "remove_images"
        case enableBookingSchedule = "enable_booking_schedule"
        case schedule
    }
}

/// web: schedule.slot_duration_minutes (in:15,30,45,60,90,120) + schedule.days[0..6]
struct BookingSchedule: Encodable {
    var slotDurationMinutes: Int = 30
    var days: [Int: DaySchedule] = [:]   // key = day_of_week (0=Sunday..6=Saturday, Laravel কনভেনশন)

    struct DaySchedule: Encodable {
        var active: Bool = false
        var startTime: String = "09:00"   // H:i ফরম্যাট, web validation date_format:H:i মেলাতে হবে
        var endTime: String = "18:00"
    }

    enum CodingKeys: String, CodingKey {
        case slotDurationMinutes = "slot_duration_minutes"
        case days
    }

    // Laravel array validation "schedule.days.0.active" আশা করে ইনডেক্স-কী array হিসেবে,
    // তাই dictionary-কে string-key JSON object আকারে এনকোড করা হচ্ছে ("0","1"...) —
    // Laravel দিক থেকে এটাই associative array হিসেবে সঠিকভাবে পার্স হবে।
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slotDurationMinutes, forKey: .slotDurationMinutes)
        var daysContainer = container.nestedContainer(keyedBy: DynamicKey.self, forKey: .days)
        for (day, schedule) in days {
            try daysContainer.encode(schedule, forKey: DynamicKey(stringValue: "\(day)")!)
        }
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}

extension BookingSchedule {
    static let weekdayLabels: [Int: String] = [
        0: "রবিবার", 1: "সোমবার", 2: "মঙ্গলবার", 3: "বুধবার",
        4: "বৃহস্পতিবার", 5: "শুক্রবার", 6: "শনিবার"
    ]
}
