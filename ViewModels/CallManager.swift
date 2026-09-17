import Foundation

@MainActor
final class CallManager: ObservableObject {
    static let shared = CallManager()

    enum State: Equatable {
        case idle
        case outgoingRinging(AppCall)
        case incomingRinging(AppCall)
        case connected(AppCall)
        case ended(reason: String)
    }

    @Published var state: State = .idle
    @Published var busyToast: BusyNotice?
    @Published var errorMessage: String?

    let agora = AgoraCallEngine()
    private let api: CallAPIProtocol = CallAPI()
    private var idlePollTask: Task<Void, Never>?
    private var activePollTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var currentRTC: RTCToken?

    private init() {}

    /// zip: poll() প্রতি ~2.5s — অ্যাপ চালু থাকা অবস্থায় সবসময় চলবে (idle থাকলে)
    func startIdlePolling() {
        stopIdlePolling()
        idlePollTask = Task {
            while !Task.isCancelled {
                if case .idle = state {
                    await pollForIncoming()
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }

    func stopIdlePolling() {
        idlePollTask?.cancel()
        idlePollTask = nil
    }

    private func pollForIncoming() async {
        guard let response = try? await api.poll() else { return }
        if let incoming = response.incoming, case .idle = state {
            state = .incomingRinging(incoming)
            startActivePolling(callId: incoming.id)
        }
        if let notice = response.busyNotice {
            busyToast = notice
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if busyToast?.id == notice.id { busyToast = nil }
            }
        }
    }

    func startCall(userId: Int, type: AppCall.CallType) async {
        errorMessage = nil
        do {
            let response = try await api.start(userId: userId, type: type)
            currentRTC = response.rtc
            state = .outgoingRinging(response.call)
            startActivePolling(callId: response.call.id)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "কল শুরু করা যায়নি।"
        }
    }

    func acceptIncoming() async {
        guard case .incomingRinging(let call) = state else { return }
        do {
            let response = try await api.accept(callId: call.id)
            currentRTC = response.rtc
            connectAgora(rtc: response.rtc, call: response.call)
        } catch {
            errorMessage = "কল গ্রহণ করা যায়নি।"
            state = .idle
        }
    }

    func rejectIncoming() async {
        guard case .incomingRinging(let call) = state else { return }
        _ = try? await api.reject(callId: call.id)
        stopActivePolling()
        state = .idle
    }

    func cancelOutgoing() async {
        guard case .outgoingRinging(let call) = state else { return }
        _ = try? await api.cancel(callId: call.id)
        stopActivePolling()
        state = .idle
    }

    func endCall() async {
        let callId: Int?
        switch state {
        case .connected(let call), .outgoingRinging(let call), .incomingRinging(let call): callId = call.id
        default: callId = nil
        }
        if let callId { _ = try? await api.end(callId: callId) }
        finishCall(reason: "কল শেষ হয়েছে")
    }

    /// zip: প্রতি ~800ms status poll ringing/active অবস্থায় — accept/reject/cancel/end/missed শনাক্ত করে
    private func startActivePolling(callId: Int) {
        stopActivePolling()
        activePollTask = Task {
            while !Task.isCancelled {
                guard let response = try? await api.status(callId: callId) else {
                    try? await Task.sleep(nanoseconds: 800_000_000); continue
                }
                await handleStatusUpdate(response)
                if !response.call.status.isActive { break }
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
        }
    }

    private func stopActivePolling() {
        activePollTask?.cancel()
        activePollTask = nil
    }

    private func handleStatusUpdate(_ response: CallStatusResponse) async {
        switch response.call.status {
        case .accepted:
            let rtc = response.rtc ?? currentRTC
            if let rtc { connectAgora(rtc: rtc, call: response.call) }
        case .rejected:
            finishCall(reason: "কল প্রত্যাখ্যাত হয়েছে")
        case .cancelled:
            finishCall(reason: "কল বাতিল করা হয়েছে")
        case .ended:
            finishCall(reason: "কল শেষ হয়েছে")
        case .missed:
            finishCall(reason: "কল মিস হয়েছে")
        case .ringing:
            break
        }
    }

    private func connectAgora(rtc: RTCToken, call: AppCall) {
        state = .connected(call)
        agora.join(rtc: rtc, isVideo: call.type == .video)
        startHeartbeat(callId: call.id)
    }

    /// zip: heartbeat প্রতি ~15s — abandoned call sweep এড়াতে
    private func startHeartbeat(callId: Int) {
        heartbeatTask?.cancel()
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                try? await api.heartbeat(callId: callId)
            }
        }
    }

    private func finishCall(reason: String) {
        stopActivePolling()
        heartbeatTask?.cancel()
        heartbeatTask = nil
        agora.leave()
        currentRTC = nil
        state = .ended(reason: reason)
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if case .ended = state { state = .idle }
        }
    }

    func toggleMute() { agora.toggleMute() }
    func toggleVideo() { agora.toggleVideo() }
    func toggleSpeaker() { agora.toggleSpeaker() }
}
