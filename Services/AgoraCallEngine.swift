import Foundation
#if canImport(AgoraRtcKit)
import AgoraRtcKit
#endif

/// ⚠️ SETUP প্রয়োজন — এই ফাইল কম্পাইল হওয়ার আগে Agora RTC SDK যোগ করতে হবে:
/// Xcode → File → Add Package Dependencies → `https://github.com/AgoraIO/AgoraRtcEngine_iOS`
/// (অথবা CocoaPods: `pod 'AgoraRtcEngine_iOS'`), Info.plist-এ Camera + Microphone usage
/// description যোগ করতে হবে (`NSCameraUsageDescription`, `NSMicrophoneUsageDescription`)।
///
/// zip: `CallService::generateToken()` app_id ফেরত দেয় — অর্থাৎ Agora App ID **backend-নির্ধারিত**,
/// iOS-এ হার্ডকোড করার দরকার নেই, প্রতিবার token response থেকেই আসবে।
@MainActor
final class AgoraCallEngine: NSObject, ObservableObject {
    @Published var isRemoteUserJoined = false
    @Published var isMuted = false
    @Published var isVideoEnabled = true
    @Published var isSpeakerOn = true

    #if canImport(AgoraRtcKit)
    private var engine: AgoraRtcEngineKit?

    func join(rtc: RTCToken, isVideo: Bool) {
        let config = AgoraRtcEngineConfig()
        config.appId = rtc.appId
        let engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        engine.setChannelProfile(.communication)
        if isVideo {
            engine.enableVideo()
        } else {
            engine.disableVideo()
        }
        engine.joinChannel(byToken: rtc.token, channelId: rtc.channel, info: nil, uid: UInt(rtc.uid)) { _, _, _ in }
        self.engine = engine
        isVideoEnabled = isVideo
    }

    func leave() {
        engine?.leaveChannel(nil)
        AgoraRtcEngineKit.destroy()
        engine = nil
        isRemoteUserJoined = false
    }

    func toggleMute() {
        isMuted.toggle()
        engine?.muteLocalAudioStream(isMuted)
    }

    func toggleVideo() {
        isVideoEnabled.toggle()
        engine?.enableLocalVideo(isVideoEnabled)
    }

    func toggleSpeaker() {
        isSpeakerOn.toggle()
        engine?.setEnableSpeakerphone(isSpeakerOn)
    }

    func setupLocalVideo(_ view: AgoraRtcVideoCanvas) {
        engine?.setupLocalVideo(view)
    }
    #else
    // AgoraRtcKit যোগ না করা পর্যন্ত প্রজেক্ট কম্পাইল হওয়ার জন্য no-op স্টাব
    func join(rtc: RTCToken, isVideo: Bool) { isVideoEnabled = isVideo }
    func leave() { isRemoteUserJoined = false }
    func toggleMute() { isMuted.toggle() }
    func toggleVideo() { isVideoEnabled.toggle() }
    func toggleSpeaker() { isSpeakerOn.toggle() }
    #endif
}

#if canImport(AgoraRtcKit)
extension AgoraCallEngine: AgoraRtcEngineDelegate {
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        Task { @MainActor in self.isRemoteUserJoined = true }
    }

    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        Task { @MainActor in self.isRemoteUserJoined = false }
    }
}
#endif
