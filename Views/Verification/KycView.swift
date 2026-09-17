import SwiftUI

struct KycView: View {
    @StateObject private var viewModel: KycViewModel

    init(isIdentityVerified: Bool) {
        _viewModel = StateObject(wrappedValue: KycViewModel(isIdentityVerified: isIdentityVerified))
    }

    var body: some View {
        content
            .navigationTitle("পরিচয় যাচাই (KYC)")
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.screenState {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)

        case .alreadyVerified:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(.green)
                Text("আপনার পরিচয় ইতিমধ্যে ভেরিফাইড।").font(.headline)
                Text("এখন থেকে Escrow-ভিত্তিক লেনদেন করতে পারবেন — আবার ডকুমেন্ট জমা দিতে হবে না।")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .pending(let verification):
            VStack(spacing: 12) {
                Image(systemName: "clock.fill").font(.system(size: 48)).foregroundStyle(.orange)
                Text("রিভিউ চলছে").font(.headline)
                Text("জমা দেওয়ার সময়: \(verification.createdAt?.formatted() ?? "")")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("অনুমোদন পেলে সাথে সাথে জানিয়ে দেওয়া হবে।")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .form(let previousRejection):
            form(previousRejection: previousRejection)
        }
    }

    private func form(previousRejection: IdentityVerification?) -> some View {
        Form {
            if let previousRejection, let reason = previousRejection.rejectionReason {
                Section {
                    Label("আগের আবেদন প্রত্যাখ্যাত হয়েছে", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text(reason).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("জাতীয় পরিচয়পত্র (NID)") {
                MediaPickerField(
                    label: "NID সামনের ছবি", isVideo: false,
                    isUploaded: viewModel.nidFrontFileURL != nil, isUploading: viewModel.isUploadingFront
                ) { url in Task { await viewModel.uploadNidFront(fileURL: url) } }

                MediaPickerField(
                    label: "NID পেছনের ছবি", isVideo: false,
                    isUploaded: viewModel.nidBackFileURL != nil, isUploading: viewModel.isUploadingBack
                ) { url in Task { await viewModel.uploadNidBack(fileURL: url) } }
            }

            Section("লাইভ ফেস ভিডিও") {
                Text("সরাসরি ক্যামেরায় তোলা একটা ছোট ভিডিও দিন যেখানে আপনার মুখ স্পষ্ট দেখা যায়।")
                    .font(.caption2).foregroundStyle(.secondary)
                MediaPickerField(
                    label: "ফেস ভিডিও", isVideo: true,
                    isUploaded: viewModel.faceVideoFileURL != nil, isUploading: viewModel.isUploadingVideo
                ) { url in Task { await viewModel.uploadFaceVideo(fileURL: url) } }
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            }

            Button {
                Task { await viewModel.submit() }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("জমা দিন").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmit)
        }
    }
}
