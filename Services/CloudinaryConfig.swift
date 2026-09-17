import Foundation

/// zip: public/js/cloudinary-upload.js + config/services.php
///
/// ⚠️ আপনাকে এই দুইটা ভ্যালু দিতে হবে (এগুলো secret না — cloud_name আর unsigned
/// upload_preset ক্লায়েন্ট অ্যাপে থাকাই স্বাভাবিক, ঠিক যেমন web-এর JS ফাইলে আছে):
///   .env → CLOUDINARY_CLOUD_NAME
///   .env → CLOUDINARY_UPLOAD_PRESET (ডিফল্ট "alhoq_preset")
///
/// ❌ কখনোই CLOUDINARY_KEY / CLOUDINARY_SECRET iOS অ্যাপে বসাবেন না —
/// ওগুলো শুধু সার্ভারে থাকার কথা (signed অপারেশনের জন্য, যেমন delete)।
/// unsigned preset দিয়ে upload করলে key/secret কখনোই লাগে না — এটাই এই
/// আর্কিটেকচারের নিরাপত্তা ভিত্তি।
enum CloudinaryConfig {
    static let cloudName = "PUT_CLOUDINARY_CLOUD_NAME_HERE"
    static let uploadPreset = "alhoq_preset"
}
