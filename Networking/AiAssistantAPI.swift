import Foundation

protocol AiAssistantAPIProtocol {
    func chat(message: String, history: [AiChatTurn], lang: String) async throws -> AiChatResponse
    /// zip: সফল হলে audio/mpeg bytes, ব্যর্থ হলে HTTP 502 (front-end কে fallback করতে বলা) —
    /// তাই nil মানে "browser/device-এর নিজস্ব TTS-এ ফলব্যাক করো", error না
    func tts(text: String, lang: String) async throws -> Data?
}

final class AiAssistantAPI: AiAssistantAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func chat(message: String, history: [AiChatTurn], lang: String) async throws -> AiChatResponse {
        // zip: response()->json() সরাসরি — কোনো envelope wrapper নেই (webhook-এর মতো raw)
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("ai-chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainTokenStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder.alhoq.encode(
            AiChatRequest(message: message, history: Array(history.suffix(20)), lang: lang)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        if http.statusCode == 429 {
            throw APIError.server(lang == "en" ? "Too many messages — wait a moment." : "অনেক মেসেজ পাঠানো হয়েছে — একটু পর আবার চেষ্টা করুন।")
        }
        guard (200...299).contains(http.statusCode) else { throw APIError.server("AI সহকারী থেকে উত্তর আসেনি।") }
        return try JSONDecoder.alhoq.decode(AiChatResponse.self, from: data)
    }

    func tts(text: String, lang: String) async throws -> Data? {
        var components = URLComponents(url: APIConfig.baseURL.appendingPathComponent("ai-tts"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "text", value: String(text.prefix(220))),
            URLQueryItem(name: "lang", value: lang),
        ]
        var request = URLRequest(url: components.url!)
        if let token = KeychainTokenStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return nil }
        return http.statusCode == 200 ? data : nil   // 502 → nil → caller device TTS-এ ফলব্যাক করবে
    }
}
