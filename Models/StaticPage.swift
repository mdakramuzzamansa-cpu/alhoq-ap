import Foundation

/// zip: app/Models/Page.php — শুধু ৩টা fixed slug আছে routes/web.php-এ:
/// about-us, faq, privacy-policy। `BlogPost` মডেল zip-এ আছে কিন্তু কোনো route/controller
/// ব্যবহার করে না — তাই Blog আপাতত dormant/unused ফিচার, iOS-এ বানানো হয়নি (Rule 15)।
struct StaticPage: Decodable {
    let title: String
    let slug: String
    let content: String   // HTML — WKWebView দিয়ে রেন্ডার করা হবে, plain Text না
    let metaTitle: String?
    let metaDescription: String?

    enum CodingKeys: String, CodingKey {
        case title, slug, content
        case metaTitle = "meta_title"
        case metaDescription = "meta_description"
    }
}

enum StaticPageSlug: String {
    case aboutUs = "about-us"
    case faq
    case privacyPolicy = "privacy-policy"

    var titleBn: String {
        switch self {
        case .aboutUs: return "আমাদের সম্পর্কে"
        case .faq: return "সচরাচর জিজ্ঞাসা"
        case .privacyPolicy: return "প্রাইভেসি পলিসি"
        }
    }
}

/// zip: ContactController@store validation হুবহু
struct ContactMessageRequest: Encodable {
    let name: String
    let email: String
    let phone: String?
    let subject: String?
    let message: String
}
