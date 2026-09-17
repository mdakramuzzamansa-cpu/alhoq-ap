import Foundation

/// zip: NotificationController@bellItems()/index() — একই shape দুই জায়গাতেই ব্যবহৃত
struct AppNotification: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var body: String
    var url: String?
    var unread: Bool
    var timeLabel: String

    enum CodingKeys: String, CodingKey {
        case id, title, body, url, unread
        case timeLabel = "time_label"
    }
}
