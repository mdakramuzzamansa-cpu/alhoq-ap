import Foundation

/// web validate() rules that gate the client-side Cloudinary upload widget
/// (see verification/create.blade.php + cloudinary-upload.js):
/// mimes: jpeg,png,jpg,gif,webp,mp4,mov,avi,mp3,wav,ogg,pdf,docx | max:100MB
enum MediaValidation {
    static let allowedExtensions: Set<String> = [
        "jpeg", "png", "jpg", "gif", "webp", "mp4", "mov", "avi", "mp3", "wav", "ogg", "pdf", "docx"
    ]
    static let maxSizeBytes: Int64 = 100 * 1024 * 1024

    static func validate(fileExtension: String, sizeBytes: Int64) -> String? {
        if !allowedExtensions.contains(fileExtension.lowercased()) {
            return "এই ফাইল টাইপ সাপোর্টেড না।"
        }
        if sizeBytes > maxSizeBytes {
            return "ফাইলের সাইজ সর্বোচ্চ ১০০MB হতে পারবে।"
        }
        return nil
    }
}
