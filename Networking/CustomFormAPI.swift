import Foundation

/// ⚠️ ASSUMPTION: path গুলো অনুমানভিত্তিক।
///
/// ⚠️ গুরুত্বপূর্ণ পার্থক্য: `file_upload` টাইপের উত্তর **Cloudinary-তে যায় না** —
/// zip নিজেই বলছে এগুলো private disk-এ (`storage/app/private`), কখনো পাবলিক URL হয় না,
/// শুধু owner/respondent gated download দিয়ে ফিরে পাওয়া যায়। তাই এই একটা জায়গায়
/// `MediaUploader` (Cloudinary) reuse করা যাবে না — সরাসরি Laravel endpoint-এ
/// multipart/form-data পাঠাতে হবে, ঠিক যেমন Auth-এর মতো token-authenticated কিন্তু
/// আলাদা storage backend।
protocol CustomFormAPIProtocol {
    // Builder (listing owner)
    func getForm(listingId: Int) async throws -> CustomForm?
    func saveForm(listingId: Int, _ request: UpdateCustomFormRequest) async throws -> CustomForm
    func deleteForm(listingId: Int) async throws

    // Public fill
    func submitResponse(listingId: Int, textAnswers: [String: FormAnswerValue], fileAnswers: [String: URL]) async throws

    // Owner dashboard
    func responsesDashboard(listingId: Int) async throws -> FormResponsesDashboard
    func downloadAttachment(listingId: Int, responseId: Int, fieldId: String) async throws -> Data
    func csvExportURL(listingId: Int) -> URL
}

final class CustomFormAPI: CustomFormAPIProtocol {
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func getForm(listingId: Int) async throws -> CustomForm? {
        let envelope: APIEnvelope<CustomForm> = try await client.request("panel/listings/\(listingId)/form")
        return envelope.data
    }

    func saveForm(listingId: Int, _ request: UpdateCustomFormRequest) async throws -> CustomForm {
        let envelope: APIEnvelope<CustomForm> = try await client.request(
            "panel/listings/\(listingId)/form", method: .put, body: request
        )
        guard let data = envelope.data else { throw APIError.unknown }
        return data
    }

    func deleteForm(listingId: Int) async throws {
        let _: APIEnvelope<EmptyData> = try await client.request("panel/listings/\(listingId)/form", method: .delete)
    }

    /// multipart সরাসরি এখানে বানানো হচ্ছে (MediaUploader না) — file field private storage-এ যায়
    func submitResponse(listingId: Int, textAnswers: [String: FormAnswerValue], fileAnswers: [String: URL]) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("listings/\(listingId)/form-responses"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = KeychainTokenStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        for (fieldId, value) in textAnswers {
            switch value {
            case .text(let text):
                appendField("answers[\(fieldId)]", text)
            case .choices(let choices):
                for choice in choices { appendField("answers[\(fieldId)][]", choice) }
            case .file:
                break // এখানে আসার কথা না — file answer আলাদা dictionary-তে থাকে
            }
        }

        for (fieldId, fileURL) in fileAnswers {
            guard let fileData = try? Data(contentsOf: fileURL) else { continue }
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"answers[\(fieldId)]\"; filename=\"\(fileURL.lastPathComponent)\"\r\n"
                    .data(using: .utf8)!
            )
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 422 {
                let decoded = try? JSONDecoder.alhoq.decode(APIEnvelope<EmptyData>.self, from: data)
                throw APIError.validation(decoded?.errors ?? [:])
            }
            throw APIError.server("ফর্ম জমা দেওয়া যায়নি।")
        }
    }

    func responsesDashboard(listingId: Int) async throws -> FormResponsesDashboard {
        let envelope: APIEnvelope<FormResponsesDashboard> = try await client.request(
            "panel/listings/\(listingId)/form-responses"
        )
        guard let data = envelope.data else { throw APIError.notFound }
        return data
    }

    func downloadAttachment(listingId: Int, responseId: Int, fieldId: String) async throws -> Data {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent(
            "panel/listings/\(listingId)/form-responses/\(responseId)/download/\(fieldId)"
        ))
        if let token = KeychainTokenStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.notFound
        }
        return data
    }

    /// CSV export বড় ফাইল হতে পারে — সরাসরি ডাউনলোড URL ফেরত দেওয়া হচ্ছে, View একটা
    /// WKWebView/Safari দিয়ে খুলবে (token cookie-based session না, তাই query-তে token পাঠানো দরকার
    /// হতে পারে — Android API কনফার্ম হলে এখানে ঠিক করতে হবে)
    func csvExportURL(listingId: Int) -> URL {
        APIConfig.baseURL.appendingPathComponent("panel/listings/\(listingId)/form-responses/export")
    }
}
