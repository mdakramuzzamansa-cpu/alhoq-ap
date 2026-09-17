import SwiftUI

/// RootView-তে একবার বসানো হবে — CallManager.state যাই হোক না কেন উপযুক্ত ফুল-স্ক্রিন কল UI দেখাবে
struct CallOverlay: View {
    @ObservedObject var callManager = CallManager.shared

    var body: some View {
        Group {
            switch callManager.state {
            case .idle:
                EmptyView()
            case .outgoingRinging(let call):
                OutgoingCallView(call: call)
            case .incomingRinging(let call):
                IncomingCallView(call: call)
            case .connected(let call):
                InCallView(call: call)
            case .ended(let reason):
                CallEndedToast(reason: reason)
            }
        }
        .overlay(alignment: .top) {
            if let toast = callManager.busyToast {
                Text("\(toast.callerName) আপনাকে কল করার চেষ্টা করেছিলেন")
                    .font(.caption)
                    .padding(10)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 8)
            }
        }
    }
}

private struct OutgoingCallView: View {
    let call: AppCall
    @ObservedObject var callManager = CallManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 100, height: 100)
            Text(call.otherUser.name).font(.title2.bold())
            Text("রিং হচ্ছে…").foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await callManager.cancelOutgoing() }
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(.red)
                    .clipShape(Circle())
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.9))
        .foregroundStyle(.white)
        .ignoresSafeArea()
    }
}

private struct IncomingCallView: View {
    let call: AppCall
    @ObservedObject var callManager = CallManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 100, height: 100)
            Text(call.otherUser.name).font(.title2.bold())
            Text(call.type == .video ? "ভিডিও কল আসছে…" : "ভয়েস কল আসছে…").foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 60) {
                Button {
                    Task { await callManager.rejectIncoming() }
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.title).foregroundStyle(.white)
                        .frame(width: 64, height: 64).background(.red).clipShape(Circle())
                }
                Button {
                    Task { await callManager.acceptIncoming() }
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.title).foregroundStyle(.white)
                        .frame(width: 64, height: 64).background(.green).clipShape(Circle())
                }
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.9))
        .foregroundStyle(.white)
        .ignoresSafeArea()
    }
}

private struct InCallView: View {
    let call: AppCall
    @ObservedObject var callManager = CallManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            if call.type == .video {
                // TODO: AgoraRtcVideoCanvas দিয়ে local/remote video view বসাতে হবে
                // (AgoraCallEngine.setupLocalVideo + remote video handling — SDK যোগ হলে)
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.3))
                    .frame(height: 300)
                    .overlay(Text(callManager.agora.isRemoteUserJoined ? "ভিডিও কানেক্টেড" : "কানেক্ট হচ্ছে…").foregroundStyle(.white))
            } else {
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 100, height: 100)
            }
            Text(call.otherUser.name).font(.title2.bold())
            Text(callManager.agora.isRemoteUserJoined ? "কানেক্টেড" : "কানেক্ট হচ্ছে…").foregroundStyle(.secondary)
            Spacer()

            HStack(spacing: 32) {
                controlButton(icon: callManager.agora.isMuted ? "mic.slash.fill" : "mic.fill") {
                    callManager.toggleMute()
                }
                if call.type == .video {
                    controlButton(icon: callManager.agora.isVideoEnabled ? "video.fill" : "video.slash.fill") {
                        callManager.toggleVideo()
                    }
                }
                controlButton(icon: callManager.agora.isSpeakerOn ? "speaker.wave.2.fill" : "speaker.fill") {
                    callManager.toggleSpeaker()
                }
                Button {
                    Task { await callManager.endCall() }
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.title2).foregroundStyle(.white)
                        .frame(width: 56, height: 56).background(.red).clipShape(Circle())
                }
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.9))
        .foregroundStyle(.white)
        .ignoresSafeArea()
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3).foregroundStyle(.white)
                .frame(width: 48, height: 48).background(.white.opacity(0.2)).clipShape(Circle())
        }
    }
}

private struct CallEndedToast: View {
    let reason: String
    var body: some View {
        VStack {
            Text(reason).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.7))
        .ignoresSafeArea()
    }
}
