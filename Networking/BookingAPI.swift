import Foundation

/// ⚠️ ASSUMPTION (আগের সব Phase-এর মতোই): path গুলো অনুমানভিত্তিক।
protocol BookingAPIProtocol {
    // customer side
    func activeWeekdays(listingId: Int) async throws -> [Int]
    func slots(listingId: Int, date: String) async throws -> [String]
    func createBooking(listingId: Int, _ request: CreateBookingRequest) async throws -> Booking
    func bookingDetail(id: Int) async throws -> Booking
    func myAppointments(page: Int) async throws -> APIEnvelope<[Booking]>

    // provider side
    func incomingBookings(page: Int) async throws -> APIEnvelope<[Booking]>
    func updateBookingStatus(id: Int, status: Booking.Status) async throws -> Booking
    func availability(listingId: Int) async throws -> [AvailabilitySlot]
    func updateAvailability(listingId: Int, schedule: BookingSchedule) async throws
}

final class BookingAPI: BookingAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func activeWeekdays(listingId: Int) async throws -> [Int] {
        struct Response: Decodable { let activeWeekdays: [Int]
            enum CodingKeys: String, CodingKey { case activeWeekdays = "active_weekdays" }
        }
        let envelope: APIEnvelope<Response> = try await client.request(
            "listings/\(listingId)/booking", authenticated: false
        )
        return envelope.data?.activeWeekdays ?? []
    }

    func slots(listingId: Int, date: String) async throws -> [String] {
        struct Response: Decodable { let slots: [String] }
        let envelope: APIEnvelope<Response> = try await client.request(
            "listings/\(listingId)/booking/slots", query: ["date": date]
        )
        return envelope.data?.slots ?? []
    }

    func createBooking(listingId: Int, _ request: CreateBookingRequest) async throws -> Booking {
        let envelope: APIEnvelope<Booking> = try await client.request(
            "listings/\(listingId)/booking", method: .post, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func bookingDetail(id: Int) async throws -> Booking {
        let envelope: APIEnvelope<Booking> = try await client.request("bookings/\(id)")
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func myAppointments(page: Int) async throws -> APIEnvelope<[Booking]> {
        try await client.request("panel/appointments", query: ["page": String(page)])
    }

    func incomingBookings(page: Int) async throws -> APIEnvelope<[Booking]> {
        try await client.request("panel/bookings", query: ["page": String(page)])
    }

    func updateBookingStatus(id: Int, status: Booking.Status) async throws -> Booking {
        struct Body: Encodable { let status: String }
        let envelope: APIEnvelope<Booking> = try await client.request(
            "panel/bookings/\(id)", method: .put, body: Body(status: status.rawValue)
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func availability(listingId: Int) async throws -> [AvailabilitySlot] {
        let envelope: APIEnvelope<[AvailabilitySlot]> = try await client.request(
            "panel/listings/\(listingId)/availability"
        )
        return envelope.data ?? []
    }

    func updateAvailability(listingId: Int, schedule: BookingSchedule) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request(
            "panel/listings/\(listingId)/availability", method: .put, body: schedule
        )
    }
}
