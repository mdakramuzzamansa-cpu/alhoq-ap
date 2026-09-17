import SwiftUI
import PhotosUI

/// KYC (NID front/back/face-video) আর Category Verification (dynamic file/video fields) —
/// দুটোতেই একই ধরনের "pick → upload → show ✅/progress" UI দরকার, তাই একবারই বানানো।
struct MediaPickerField: View {
    let label: String
    let isVideo: Bool
    let isUploaded: Bool
    let isUploading: Bool
    let onPicked: (URL) -> Void

    @State private var selection: PhotosPickerItem?

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if isUploading {
                ProgressView()
            } else if isUploaded {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            PhotosPicker(
                selection: $selection,
                matching: isVideo ? .videos : .images
            ) {
                Text(isUploaded ? "বদলান" : "বেছে নিন")
            }
            .onChange(of: selection) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    let ext = isVideo ? "mov" : "jpg"
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + "." + ext)
                    try? data.write(to: tempURL)
                    onPicked(tempURL)
                }
            }
        }
    }
}
