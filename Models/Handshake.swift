import Foundation

/// zip: app/Models/Handshake.php — TYPES constant হুবহু (label_bn সহ, backend-এই বাংলা লেবেল
/// আছে, তাই এখানে নিজে থেকে অনুবাদ করার দরকার নেই — সার্ভার যা পাঠাবে তাই দেখানো হবে)
struct Handshake: Codable, Identifiable, Equatable {
    let id: Int
    var requesterId: Int
    var recipientId: Int
    var otherUser: ListingPoster
    var type: HandshakeType
    var status: Status
    var respondedAt: String?
    var createdAt: String

    enum HandshakeType: String, Codable, CaseIterable {
        case justConnect = "just_connect"
        case business
        case collaboration
        case service

        var emoji: String {
            switch self {
            case .justConnect: return "👋"
            case .business: return "💼"
            case .collaboration: return "🤝"
            case .service: return "🛠️"
            }
        }

        var labelBn: String {
            switch self {
            case .justConnect: return "সাধারণ পরিচিতি"
            case .business: return "ব্যবসায়িক যোগাযোগ"
            case .collaboration: return "একসাথে কাজ করতে চাই"
            case .service: return "Service/Provider হিসেবে যোগাযোগ"
            }
        }
    }

    enum Status: String, Codable {
        case pending, accepted, declined
    }

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case recipientId = "recipient_id"
        case otherUser = "other_user"
        case type, status
        case respondedAt = "responded_at"
        case createdAt = "created_at"
    }
}

struct HandshakesIndexResponse: Decodable {
    let received: [Handshake]
    let sent: [Handshake]
    let connections: [Handshake]
}
