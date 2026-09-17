import SwiftUI

struct LiveBrowseView: View {
    @StateObject private var viewModel = LiveBrowseViewModel()
    @State private var showBroadcast = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.streams) { stream in
                    NavigationLink {
                        WatchLiveView(streamId: stream.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.85))
                                .aspectRatio(9/16, contentMode: .fit)
                                .overlay(alignment: .topLeading) {
                                    Text("LIVE").font(.caption2.bold())
                                        .padding(4).background(.red).foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 4)).padding(6)
                                }
                                .overlay(alignment: .bottomLeading) {
                                    Label("\(stream.viewerCount)", systemImage: "eye.fill")
                                        .font(.caption2).padding(4).background(.black.opacity(0.6))
                                        .foregroundStyle(.white).clipShape(Capsule()).padding(6)
                                }
                            Text(stream.title).font(.caption.bold()).lineLimit(1)
                            Text(stream.broadcaster.name).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.streams.isEmpty {
                Text("এখন কেউ লাইভ নেই").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("লাইভ")
        .toolbar {
            toolbarItem(placement: .topBarTrailing) {
                Button { showBroadcast = true } label: { Image(systemName: "video.badge.plus") }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .fullScreenCover(isPresented: $showBroadcast) { BroadcastView() }
    }
}

struct BroadcastView: View {
    @StateObject private var viewModel = BroadcastViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            if let stream = viewModel.stream, stream.status == .live {
                ZStack(alignment: .topLeading) {
                    // TODO: AgoraRtcVideoCanvas দিয়ে local preview বসাতে হবে (SDK যোগ হলে)
                    Rectangle().fill(Color.black)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("লাইভ", systemImage: "dot.radiowaves.left.and.right")
                            .padding(6).background(.red).foregroundStyle(.white).clipShape(Capsule())
                        Label("\(stream.viewerCount) দর্শক", systemImage: "eye")
                            .padding(6).background(.black.opacity(0.5)).foregroundStyle(.white).clipShape(Capsule())
                    }
                    .padding()
                }
                Button("লাইভ শেষ করুন") { Task { await viewModel.endStream(); dismiss() } }
                    .buttonStyle(.borderedProminent).tint(.red).padding()
            } else {
                VStack(spacing: 16) {
                    TextField("শিরোনাম (ঐচ্ছিক)", text: $viewModel.titleText)
                        .textFieldStyle(.roundedBorder).padding(.horizontal)
                    if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
                    Button {
                        Task { await viewModel.goLive() }
                    } label: {
                        if viewModel.isStarting { ProgressView() } else { Text("লাইভ শুরু করুন") }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("বাতিল") { dismiss() }
                }
                .padding()
            }
        }
        .background(.black)
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.white.opacity(0.8))
            }
            .padding()
        }
    }
}

struct WatchLiveView: View {
    @StateObject private var viewModel: WatchViewModel
    @Environment(\.dismiss) private var dismiss

    init(streamId: Int) {
        _viewModel = StateObject(wrappedValue: WatchViewModel(streamId: streamId))
    }

    var body: some View {
        ZStack {
            // TODO: AgoraRtcVideoCanvas দিয়ে remote broadcaster video বসাতে হবে (SDK যোগ হলে)
            Color.black.ignoresSafeArea()

            if let stream = viewModel.stream {
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(stream.broadcaster.name).font(.subheadline.bold()).foregroundStyle(.white)
                            Label("\(stream.viewerCount)", systemImage: "eye.fill").font(.caption).foregroundStyle(.white)
                        }
                        Spacer()
                        Button { viewModel.leave(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundStyle(.white)
                                .padding(8).background(.black.opacity(0.5)).clipShape(Circle())
                        }
                    }
                    .padding()
                    Spacer()
                }
            }

            if let error = viewModel.errorMessage {
                VStack {
                    Text(error).foregroundStyle(.white).padding()
                    Button("বন্ধ করুন") { dismiss() }.buttonStyle(.borderedProminent)
                }
            } else if viewModel.isLoading {
                ProgressView().tint(.white)
            }
        }
        .task { await viewModel.join() }
        .onDisappear { viewModel.leave() }
    }
}
