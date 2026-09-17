import Foundation

/// zip: public/js/cloudinary-upload.js — এই ক্লাসটা তার Swift-সংস্করণ, হুবহু একই আচরণ:
/// unsigned Cloudinary upload, resource_type ফাইল টাইপ অনুযায়ী (video হলে "video", বাকি সব "auto")।
///
/// এই একটা ক্লাসই Profile avatar/cover, Listing images, Post media, Chat attachment,
/// KYC/Verification file, Payment proof, Dispute evidence — সব জায়গায় reuse হবে,
/// ঠিক যেমন web-এ একটাই cloudinary-upload.js সব ফর্মে ব্যবহৃত হয় (Rule 7)।
@MainActor
final class MediaUploader: NSObject, ObservableObject {
    @Published private(set) var progress: Double = 0
    @Published private(set) var isUploading = false

    func upload(fileURL: URL) async throws -> String {
        let fileExtension = fileURL.pathExtension
        let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0

        if let validationError = MediaValidation.validate(fileExtension: fileExtension, sizeBytes: sizeBytes ?? 0) {
            throw APIError.validation(["file": [validationError]])
        }

        guard CloudinaryConfig.cloudName != "PUT_CLOUDINARY_CLOUD_NAME_HERE" else {
            // ইচ্ছাকৃতভাবে এখানে থামানো হচ্ছে — ভুল/খালি cloud_name দিয়ে সাইলেন্টলি
            // fail করা থেকে ভালো, স্পষ্ট এরর দেখানো (config বসানো না হলে)
            throw APIError.server("Cloudinary config বসানো হয়নি — CloudinaryConfig.swift চেক করুন।")
        }

        isUploading = true
        progress = 0
        defer { isUploading = false }

        let isVideo = Self.mimeType(for: fileExtension).hasPrefix("video/")
        let resourceType = isVideo ? "video" : "auto"
        let url = URL(string: "https://api.cloudinary.com/v1_1/\(CloudinaryConfig.cloudName)/\(resourceType)/upload")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // NOTE: Cloudinary-তে কোনো Authorization header লাগে না — unsigned preset-ই যথেষ্ট।

        let fileData = try Data(contentsOf: fileURL)
        let mimeType = Self.mimeType(for: fileExtension)

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("upload_preset", CloudinaryConfig.uploadPreset)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

        let (data, response) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
            let task = session.uploadTask(with: request, from: body) { data, response, error in
                if let error {
                    continuation.resume(throwing: APIError.network(error as? URLError ?? URLError(.unknown)))
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: APIError.unknown)
                }
            }
            task.resume()
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

        guard (200...299).contains(http.statusCode) else {
            struct CloudinaryError: Decodable {
                struct ErrorBody: Decodable { let message: String? }
                let error: ErrorBody?
            }
            let decoded = try? JSONDecoder().decode(CloudinaryError.self, from: data)
            throw APIError.server(decoded?.error?.message ?? "Cloudinary আপলোড ব্যর্থ হয়েছে।")
        }

        struct CloudinaryResponse: Decodable { let secureUrl: String
            enum CodingKeys: String, CodingKey { case secureUrl = "secure_url" }
        }
        guard let decoded = try? JSONDecoder().decode(CloudinaryResponse.self, from: data) else {
            throw APIError.decoding
        }
        return decoded.secureUrl
    }

    private static func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "jpeg", "jpg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "avi": return "video/x-msvideo"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "ogg": return "audio/ogg"
        case "pdf": return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default: return "application/octet-stream"
        }
    }
}

extension MediaUploader: URLSessionTaskDelegate {
    nonisolated func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let value = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        Task { @MainActor in self.progress = value }
    }
}
