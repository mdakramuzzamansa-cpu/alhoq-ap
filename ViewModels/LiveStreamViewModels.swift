import Foundation

@MainActor
final class LiveBrowseViewModel: ObservableObject {
    @Published var streams: [LiveStream] = []
    @Published var isLoading = false
    private let api: LiveStreamAPIProtocol = LiveStreamAPI()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        streams = (try? await api.browse(page: 1))?.data ?? []
    }
}

@MainActor
final class BroadcastViewModel: ObservableObject {
    @Published var stream: LiveStream?
    @Published var titleText: String = ""
    @Published var isStarting = false
    @Published var errorMessage: String?
    let engine = LiveAgoraEngine()

    private let api: LiveStreamAPIProtocol = LiveStreamAPI()
    private var heartbeatTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

    func goLive() async {
        isStarting = true
        errorMessage = nil
        defer { isStarting = false }
        do {
            let response = try await api.start(title: titleText.isEmpty ? nil : titleText)
            stream = response.stream
            engine.joinAsHost(rtc: response.rtc)
            startHeartbeat(streamId: response.stream.id)
            startStatusPoll(streamId: response.stream.id)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "লাইভ শুরু করা যায়নি।"
        }
    }

    /// zip: host heartbeat প্রতি ~15s — ট্যাব বন্ধ হয়ে গেলে auto-end করার জন্য
    private func startHeartbeat(streamId: Int) {
        heartbeatTask?.cancel()
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if let updated = try? await api.hostHeartbeat(streamId: streamId) { stream = updated }
            }
        }
    }

    private func startStatusPoll(streamId: Int) {
        statusTask?.cancel()
        statusTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let updated = try? await api.status(streamId: streamId) else { continue }
                stream = updated
                if updated.status == .ended { stopEverything() }
            }
        }
    }

    func endStream() async {
        guard let stream else { return }
        _ = try? await api.end(streamId: stream.id)
        stopEverything()
    }

    private func stopEverything() {
        heartbeatTask?.cancel(); heartbeatTask = nil
        statusTask?.cancel(); statusTask = nil
        engine.leave()
        stream = stream.map { var s = $0; s.status = .ended; return s }
    }
}

@MainActor
final class WatchViewModel: ObservableObject {
    let streamId: Int
    @Published var stream: LiveStream?
    @Published var isLoading = false
    @Published var errorMessage: String?
    let engine = LiveAgoraEngine()

    private let api: LiveStreamAPIProtocol = LiveStreamAPI()
    private var heartbeatTask: Task<Void, Never>?

    init(streamId: Int) { self.streamId = streamId }

    func join() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.watchToken(streamId: streamId)
            stream = response.stream
            engine.joinAsViewer(rtc: response.rtc)
            startHeartbeat()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "স্ট্রিমে জয়েন করা যায়নি।"
        }
    }

    /// zip: viewer heartbeat প্রতি ~15s — viewer_count নির্ভুল রাখতে
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard let updated = try? await api.viewerHeartbeat(streamId: streamId) else { continue }
                stream = updated
                if updated.status == .ended {
                    leave()
                    errorMessage = "স্ট্রিম শেষ হয়ে গেছে।"
                }
            }
        }
    }

    func leave() {
        heartbeatTask?.cancel(); heartbeatTask = nil
        engine.leave()
        Task { try? await api.leave(streamId: streamId) }
    }
}
