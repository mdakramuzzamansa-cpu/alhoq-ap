import Foundation
#if canImport(AgoraRtcKit)
import AgoraRtcKit
#endif

/// zip parity নোট: Calls (Phase 17) `.communication` profile ব্যবহার করে (দুইজন সমান),
/// কিন্তু Live Streaming `.liveBroadcasting` profile + host/audience role লাগে — তাই
/// আলাদা ইঞ্জিন ক্লাস, `AgoraCallEngine` থেকে কোড শেয়ার করা হয়নি (ভুলভাবে একটাই ব্যবহার
/// করলে broadcaster-এর ভিডিও viewer-রা দেখতেই পেত না)।
@MainActor
final class LiveAgoraEngine: NSObject, ObservableObject {
    @Published var isConnected = false

    #if canImport(AgoraRtcKit)
    private var engine: AgoraRtcEngineKit?

    func joinAsHost(rtc: RTCToken) {
        let config = AgoraRtcEngineConfig()
        config.appId = rtc.appId
        let engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        engine.setChannelProfile(.liveBroadcasting)
        engine.setClientRole(.broadcaster)
        engine.enableVideo()
        engine.joinChannel(byToken: rtc.token, channelId: rtc.channel, info: nil, uid: UInt(rtc.uid)) { _, _, _ in }
        self.engine = engine
    }

    func joinAsViewer(rtc: RTCToken) {
        let config = AgoraRtcEngineConfig()
        config.appId = rtc.appId
        let engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        engine.setChannelProfile(.liveBroadcasting)
        engine.setClientRole(.audience)
        engine.joinChannel(byToken: rtc.token, channelId: rtc.channel, info: nil, uid: UInt(rtc.uid)) { _, _, _ in }
        self.engine = engine
    }

    func leave() {
        engine?.leaveChannel(nil)
        AgoraRtcEngineKit.destroy()
        engine = nil
        isConnected = false
    }
    #else
    func joinAsHost(rtc: RTCToken) { isConnected = true }
    func joinAsViewer(rtc: RTCToken) { isConnected = true }
    func leave() { isConnected = false }
    #endif
}

#if canImport(AgoraRtcKit)
extension LiveAgoraEngine: AgoraRtcEngineDelegate {
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        Task { @MainActor in self.isConnected = true }
    }
}
#endif
