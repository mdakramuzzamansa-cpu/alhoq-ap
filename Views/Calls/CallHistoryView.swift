import SwiftUI

@MainActor
final class CallHistoryViewModel: ObservableObject {
    @Published var calls: [AppCall] = []
    @Published var isLoading = false
    private let api: CallAPIProtocol = CallAPI()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        calls = (try? await api.history(page: 1))?.data ?? []
    }
}

struct CallHistoryView: View {
    @StateObject private var viewModel = CallHistoryViewModel()

    var body: some View {
        List(viewModel.calls) { call in
            HStack {
                Image(systemName: call.type == .video ? "video.fill" : "phone.fill")
                    .foregroundStyle(call.status == .missed ? .red : .secondary)
                VStack(alignment: .leading) {
                    Text(call.otherUser.name).font(.subheadline.bold())
                    Text(call.isCaller ? "আউটগোয়িং" : "ইনকামিং").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await CallManager.shared.startCall(userId: call.otherUser.id, type: call.type) }
                } label: {
                    Image(systemName: call.type == .video ? "video" : "phone")
                }
            }
        }
        .overlay { if viewModel.isLoading { ProgressView() } }
        .navigationTitle("কল হিস্ট্রি")
        .task { await viewModel.load() }
    }
}
