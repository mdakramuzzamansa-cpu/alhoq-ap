import Foundation

/// zip: CallController@present() — হুবহু
struct AppCall: Codable, Identifiable, Equatable {
    let id: Int
    var type: CallType
    var status: Status
    var channel: String
    var isCaller: Bool
    var otherUser: CallParticipant
    var answeredAt: String?

    enum CallType: String, Codable { case voice, video }

    enum Status: String, Codable {
        case ringing, accepted, rejected, cancelled, ended, missed

        var isActive: Bool { self == .ringing || self == .accepted }
    }

    enum CodingKeys: String, CodingKey {
        case id, type, status, channel
        case isCaller = "is_caller"
        case otherUser = "other_user"
        case answeredAt = "answered_at"
    }
}

struct CallParticipant: Codable, Equatable {
    let id: Int
    var name: String
    var avatar: String?
}

/// zip: CallService::generateToken() রেসপন্স — Agora RTC join করার জন্য দরকারি সব তথ্য
struct RTCToken: Codable {
    var appId: String
    var token: String
    var channel: String
    var uid: Int

    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case token, channel, uid
    }
}

struct StartCallResponse: Decodable {
    let call: AppCall
    let rtc: RTCToken
}

struct CallStatusResponse: Decodable {
    let call: AppCall
    let rtc: RTCToken?   // শুধু status == accepted হলে present, নাহলে caller-এর আগের token-ই valid থাকে
}

/// zip: CallController@poll() — প্রতি ~2.5s পোল হয়, Pusher শুধু instant nudge (safety-net সম্পর্ক
/// বিপরীত এখানে — polling-ই মূল mechanism, Pusher accelerant) — তাই এই একটা মডিউল pure-poll
/// দিয়ে **সম্পূর্ণ web-parity**, অন্য মডিউলের (Chat/Notifications) মতো "আংশিক" না
struct CallPollResponse: Decodable {
    let incoming: AppCall?
    let busyNotice: BusyNotice?
    enum CodingKeys: String, CodingKey { case incoming; case busyNotice = "busy_notice" }
}

struct BusyNotice: Decodable {
    let id: Int
    let callerName: String
    let type: AppCall.CallType
    enum CodingKeys: String, CodingKey { case id; case callerName = "caller_name"; case type }
}
