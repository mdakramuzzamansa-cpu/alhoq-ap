import Foundation

/// zip: LiveStreamController@present()
struct LiveStream: Codable, Identifiable, Equatable {
    let id: Int
    var title: String
    var status: Status
    var channel: String
    var viewerCount: Int
    var broadcaster: CallParticipant   // Calls মডিউলের CallParticipant reuse — একই shape (id/name/avatar)

    enum Status: String, Codable { case live, ended }

    enum CodingKeys: String, CodingKey {
        case id, title, status, channel
        case viewerCount = "viewer_count"
        case broadcaster
    }
}

struct StartLiveResponse: Decodable {
    let stream: LiveStream
    let rtc: RTCToken
}

struct LiveStatusResponse: Decodable {
    let stream: LiveStream
}
