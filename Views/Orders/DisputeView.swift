import SwiftUI
import PhotosUI

struct DisputeView: View {
    @StateObject private var viewModel: DisputeViewModel
    @State private var evidenceItem: PhotosPickerItem?
    @State private var evidenceDescription = ""
    @State private var showAppealAlert = false
    @State private var appealReason = ""

    init(disputeId: Int, currentUserId: Int) {
        _viewModel = StateObject(wrappedValue: DisputeViewModel(disputeId: disputeId, currentUserId: currentUserId))
    }

    var body: some View {
        ScrollView {
            if let dispute = viewModel.dispute {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("বিরোধ #\(dispute.id)").font(.title3.bold())
                        Text(dispute.status.label)
                            .font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                        Text(dispute.reason)
                        if let decision = dispute.decision {
                            Label("সিদ্ধান্ত: \(decisionLabel(decision))", systemImage: "gavel")
                                .font(.subheadline.bold())
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("এভিডেন্স").font(.headline)
                        ForEach(viewModel.evidence) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Label(item.fileType, systemImage: "paperclip")
                                if let description = item.description { Text(description).font(.caption) }
                                Text("জমা দিয়েছেন: \(item.uploadedByName)").font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // zip: DisputePolicy::addEvidence() — decided/closed ছাড়া বাকি সব
                        // অবস্থায় (pending_senior_approval, appealed সহ) এভিডেন্স যোগ করা যায় —
                        // আগে শুধু open/under_review-এ সীমাবদ্ধ ছিল
                        if ![.decided, .closed].contains(dispute.status) {
                            TextField("বিবরণ (ঐচ্ছিক)", text: $evidenceDescription)
                            PhotosPicker(selection: $evidenceItem, matching: .any(of: [.images, .videos])) {
                                if viewModel.isUploadingEvidence { ProgressView() } else { Text("এভিডেন্স যোগ করুন") }
                            }
                            .onChange(of: evidenceItem) { _, item in
                                guard let item else { return }
                                Task {
                                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                                    try? data.write(to: tempURL)
                                    await viewModel.addEvidence(fileURL: tempURL, description: evidenceDescription.isEmpty ? nil : evidenceDescription)
                                    evidenceDescription = ""
                                }
                            }
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error).foregroundStyle(.red)
                    }

                    // zip: DisputePolicy::withdraw() — শুধু যিনি dispute খুলেছেন (opened_by)
                    // তিনিই withdraw করতে পারবেন, অন্য পক্ষ না — আগে দুজনকেই বাটন দেখানো হতো
                    if viewModel.canWithdraw {
                        Button("বিরোধ প্রত্যাহার করুন") { Task { await viewModel.withdraw() } }
                            .buttonStyle(.bordered)
                    }
                    if dispute.status == .decided {
                        Button("আপিল করুন") { showAppealAlert = true }
                            .buttonStyle(.bordered)
                    }
                }
                .padding()
            } else if viewModel.isLoading {
                ProgressView().padding(.top, 60)
            }
        }
        .navigationTitle("বিরোধ নিষ্পত্তি")
        .task { await viewModel.load() }
        .alert("আপিলের কারণ", isPresented: $showAppealAlert) {
            TextField("কারণ লিখুন", text: $appealReason)
            Button("আপিল করুন") { Task { await viewModel.appeal(reason: appealReason) } }
            Button("বাতিল", role: .cancel) {}
        }
    }

    private func decisionLabel(_ decision: Dispute.Decision) -> String {
        switch decision {
        case .refund: return "সম্পূর্ণ রিফান্ড"
        case .partialRefund: return "আংশিক রিফান্ড"
        case .releaseToSeller: return "বিক্রেতাকে টাকা দেওয়া হয়েছে"
        case .requestMoreEvidence: return "আরও এভিডেন্স চাওয়া হয়েছে"
        case .cancelled: return "বাতিল"
        }
    }
}
