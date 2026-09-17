import SwiftUI

/// প্রোফাইল পেজের 🤝 বাটনে ট্যাপ করলে এই popup দেখানো হয় — ৪টা টাইপের একটা বেছে নেওয়া
struct SendHandshakeSheet: View {
    @StateObject private var viewModel: SendHandshakeViewModel
    @Environment(\.dismiss) private var dismiss
    let userName: String

    init(userId: Int, userName: String) {
        _viewModel = StateObject(wrappedValue: SendHandshakeViewModel(userId: userId))
        self.userName = userName
    }

    var body: some View {
        NavigationStack {
            if viewModel.sentSuccessfully {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(.green)
                    Text("\(userName)-কে Handshake পাঠানো হয়েছে!").font(.headline)
                    Button("বন্ধ করুন") { dismiss() }.buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                List(Handshake.HandshakeType.allCases, id: \.self) { type in
                    Button {
                        Task { await viewModel.send(type: type) }
                    } label: {
                        HStack {
                            Text(type.emoji).font(.title2)
                            Text(type.labelBn)
                            Spacer()
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .overlay { if viewModel.isSending { ProgressView() } }
                .navigationTitle("Handshake পাঠান")
                .toolbar { cancelToolbarItem("বাতিল") { dismiss() } }
                .alert("সমস্যা হয়েছে", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
                    Button("ঠিক আছে", role: .cancel) {}
                } message: {
                    Text(viewModel.errorMessage ?? "")
                }
            }
        }
    }
}

struct HandshakesPanelView: View {
    @StateObject private var viewModel = HandshakesViewModel()
    @State private var tab = 0

    var body: some View {
        VStack {
            Picker("", selection: $tab) {
                Text("এসেছে (\(viewModel.received.count))").tag(0)
                Text("পাঠানো (\(viewModel.sent.count))").tag(1)
                Text("সংযোগ (\(viewModel.connections.count))").tag(2)
            }
            .pickerStyle(.segmented).padding()

            List {
                switch tab {
                case 0:
                    ForEach(viewModel.received) { handshake in
                        HStack {
                            row(handshake)
                            Spacer()
                            Button("গ্রহণ") { Task { await viewModel.accept(handshake) } }.buttonStyle(.borderedProminent)
                            Button("প্রত্যাখ্যান") { Task { await viewModel.decline(handshake) } }.buttonStyle(.bordered)
                        }
                    }
                case 1:
                    ForEach(viewModel.sent) { handshake in row(handshake) }
                default:
                    ForEach(viewModel.connections) { handshake in
                        HStack {
                            row(handshake)
                            Spacer()
                            Button("সংযোগ বিচ্ছিন্ন করুন", role: .destructive) {
                                Task { await viewModel.disconnect(handshake) }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .overlay { if viewModel.isLoading { ProgressView() } }
        .navigationTitle("Handshake")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func row(_ handshake: Handshake) -> some View {
        HStack {
            Text(handshake.type.emoji)
            VStack(alignment: .leading) {
                Text(handshake.otherUser.name).font(.subheadline.bold())
                Text(handshake.type.labelBn).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
