import SwiftUI

struct RoomJoinView: View {
    @StateObject private var viewModel: RoomJoinViewModel

    init(token: String) {
        _viewModel = StateObject(wrappedValue: RoomJoinViewModel(token: token))
    }

    var body: some View {
        VStack(spacing: 20) {
            if let room = viewModel.room {
                Text(room.name).font(.title2.bold())

                if viewModel.pendingRequest {
                    Label("আপনার জয়েন রিকোয়েস্ট অ্যাডমিনদের কাছে পাঠানো হয়েছে", systemImage: "clock")
                        .foregroundStyle(.orange)
                } else {
                    Text("এই রুমে ঢুকতে PIN দিন").foregroundStyle(.secondary)
                    TextField("৬-সংখ্যার PIN", text: $viewModel.pin)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .multilineTextAlignment(.center)

                    if let error = viewModel.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }

                    Button {
                        Task { await viewModel.verifyPin() }
                    } label: {
                        if viewModel.isVerifying { ProgressView() } else { Text("PIN দিয়ে ঢুকুন") }
                    }
                    .buttonStyle(.borderedProminent)

                    Divider().padding(.vertical, 8)

                    Text("PIN নেই?").font(.caption).foregroundStyle(.secondary)
                    Button("জয়েনের অনুরোধ পাঠান") {
                        Task { await viewModel.requestToJoin() }
                    }
                    .buttonStyle(.bordered)
                }
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
        .padding()
        .navigationTitle("রুমে জয়েন করুন")
        .task { await viewModel.loadInfo() }
        .navigationDestination(isPresented: $viewModel.didUnlock) {
            RoomThreadView(token: viewModel.token)
        }
    }
}
