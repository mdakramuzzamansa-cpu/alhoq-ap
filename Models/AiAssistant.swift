import Foundation

/// zip: routes/web.php কনফার্ম করা path — `POST /ai-chat`, `GET /ai-tts`, দুটোই throttle:20,1।
/// ⚠️ এই দুটো endpoint web-এর মতোই সরাসরি JSON/audio রিটার্ন করে — আগের অনেক Phase-এর
/// মতো "Blade-only gap" এখানে নেই। শুধু `/api/v1/` prefix-এর ভেতরে সরানো হয়েছে কিনা
/// Android API-তে, সেটাই কনফার্ম করার বাকি (path assumption সেই একটুকুই)।
struct AiChatTurn: Codable {
    let role: String   // "user" | "model" — web-এর কনভেনশন হুবহু (Gemini API-এর নিজস্ব role নাম)
    let text: String
}

struct AiChatRequest: Encodable {
    let message: String
    let history: [AiChatTurn]
    let lang: String   // "bn" | "en"
}

/// zip: chat() রেসপন্স — action.url ইতিমধ্যে backend-resolved পূর্ণ web URL (whitelisted
/// siteMap থেকে), তাই iOS নিজে থেকে কোনো page-key ম্যাপিং করবে না — সরাসরি DeepLinkRouter
/// (Phase 16/25-এ বানানো)-তে পাস করে দেবে, ঠিক যেমন push notification-এর url করে
struct AiChatResponse: Decodable {
    let reply: String
    let action: AiAction?
}

struct AiAction: Decodable {
    let type: String    // "navigate" | "search"
    let url: String
    let page: String?
}
