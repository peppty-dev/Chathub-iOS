import Foundation
import SwiftUI
import AgoraRtcKit
import AVFAudio

@objc(LiveCallManager)
class LiveCallManager: NSObject, ObservableObject, AgoraRtcEngineDelegate {
    @Published var isLocalSpeaking: Bool = false
    @Published var isRemoteSpeaking: Bool = false
    @Published var localVideoView: UIView? = nil
    @Published var remoteVideoView: UIView? = nil
    @Published var isVideoEnabled: Bool = true
    @Published var isMuted: Bool = false
    @Published var isRemoteAudioMuted: Bool = false
    
    private var agoraEngine: AgoraRtcEngineKit? = nil
    private let appId = "8173040ab4524a64a1051a44026b9677"
    private let sessionManager = SessionManager.shared
    
    var onRemoteUserJoined: ((UInt) -> Void)?
    var onRemoteUserLeft: ((UInt) -> Void)?
    
    // MARK: - Memory Management
    deinit {
        AppLogger.log(tag: "LiveCallManager", message: "Deinitializing LiveCallManager")
        cleanup()
    }
    
    func cleanup() {
        leaveChannel()
        AgoraRtcEngineKit.destroy()
        agoraEngine = nil
        localVideoView = nil
        remoteVideoView = nil
        onRemoteUserJoined = nil
        onRemoteUserLeft = nil
    }
    
    func initializeAgoraEngineForLive(chatId: String) {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "initializeAgoraEngineForLive() Initializing Agora engine for live")
        
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        
        // FIX: AgoraRtcEngineKit.sharedEngine returns non-optional, no guard let needed
        let engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        agoraEngine = engine
        // CROSS-PLATFORM FIX: Use .liveBroadcasting to match Android's CHANNEL_PROFILE_LIVE_BROADCASTING for direct video
        agoraEngine?.setChannelProfile(.liveBroadcasting)
        agoraEngine?.setClientRole(.broadcaster)
        agoraEngine?.enableAudio()
        agoraEngine?.enableVideo()
        agoraEngine?.enableAudioVolumeIndication(250, smooth: 3, reportVad: true)
        setupVideoConfig()
        setupLocalVideo()
        joinLiveChannel(chatId: chatId)
    }
    
    func setupLocalVideo() {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "setupLocalVideo() Setting up local video")
        
        agoraEngine?.enableVideo()
        agoraEngine?.startPreview()
        
        let videoCanvas = AgoraRtcVideoCanvas()
        let videoView = UIView()
        videoView.backgroundColor = UIColor.black
        videoCanvas.view = videoView
        videoCanvas.renderMode = .hidden
        videoCanvas.uid = 0
        
        agoraEngine?.setupLocalVideo(videoCanvas)
        localVideoView = videoView
    }
    
    func setupRemoteVideo(uid: UInt) {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "setupRemoteVideo() Setting up remote video for uid: \(uid)")

        let videoCanvas = AgoraRtcVideoCanvas()
        let videoView = UIView()
        videoView.backgroundColor = UIColor.black
        videoCanvas.view = videoView
        videoCanvas.renderMode = .hidden
        videoCanvas.uid = uid
        
        agoraEngine?.setupRemoteVideo(videoCanvas)
        remoteVideoView = videoView
    }
    
    func setupVideoConfig() {
        let videoConfig = AgoraVideoEncoderConfiguration(
            size: CGSize(width: 640, height: 480),
            frameRate: .fps15,
            bitrate: AgoraVideoBitrateStandard,
            orientationMode: .adaptative,
            mirrorMode: .auto
        )
        agoraEngine?.setVideoEncoderConfiguration(videoConfig)
    }
    
    func setUpLocalAudio() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "setUpLocalAudio() Failed to setup audio session: \(error)")
        }
    }
    
    func joinLiveChannel(chatId: String) {
        // CROSS-PLATFORM FIX: Use chatId directly to match Android direct video channel naming
        // Android uses CHATID directly, so iOS should use the same for compatibility
        let channelName = chatId
        
        // CROSS-PLATFORM FIX: Use sessionManager.userId.hashValue to match Android's sessionManager.getUserID().hashCode()
        // Use abs() to handle negative hash values since UInt cannot represent negative numbers
        let userId = UInt(abs(sessionManager.userId?.hashValue ?? 0))
        
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "joinLiveChannel() CROSS-PLATFORM: Using channel name '\(channelName)' and user ID '\(userId)' to match Android direct video")
        agoraEngine?.joinChannel(byToken: nil, channelId: channelName, info: nil, uid: userId) { [weak self] (channel, uid, elapsed) in
            guard let _ = self else { return }
            AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "joinLiveChannel() ✅ CROSS-PLATFORM SUCCESS: Joined channel: \(channel), uid: \(uid)")
        }
    }
    
    func leaveChannel() {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "leaveChannel() Leaving live channel")
        agoraEngine?.leaveChannel(nil)
        agoraEngine?.stopPreview()
        agoraEngine?.disableVideo()
    }
    
    func switchCamera() {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "switchCamera() Switching camera")
        agoraEngine?.switchCamera()
    }
    
    func toggleVideo() {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "toggleVideo() Toggling video")
        // Toggle local video enable/disable
        isVideoEnabled.toggle()
        agoraEngine?.enableLocalVideo(isVideoEnabled)
    }
    
    func toggleMute() {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "toggleMute() Toggling audio mute")
        // Toggle local audio mute
        isMuted.toggle()
        agoraEngine?.muteLocalAudioStream(isMuted)
    }
    
    func toggleRemoteAudioMute() {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "toggleRemoteAudioMute() Toggling remote audio mute")
        // Toggle remote audio playback mute
        isRemoteAudioMuted.toggle()
        agoraEngine?.muteAllRemoteAudioStreams(isRemoteAudioMuted)
    }
    
    
    // MARK: - AgoraRtcEngineDelegate
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "didJoinChannel() Joined live channel: \(channel) with uid: \(uid)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "didJoinedOfUid() Other user joined live with uid: \(uid)")
        
        DispatchQueue.main.async {
            self.setupRemoteVideo(uid: uid)
            self.onRemoteUserJoined?(uid)
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "didOfflineOfUid() User \(uid) left live")
        
        DispatchQueue.main.async {
            self.remoteVideoView = nil
            self.onRemoteUserLeft?(uid)
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        for speaker in speakers {
            if speaker.uid == 0 { // Local user
                DispatchQueue.main.async {
                    self.isLocalSpeaking = speaker.volume > 10
                }
            } else { // Remote user
                DispatchQueue.main.async {
                    self.isRemoteSpeaking = speaker.volume > 10
                }
            }
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "firstRemoteVideoDecodedOfUid() Remote video started for uid: \(uid)")
        
        DispatchQueue.main.async {
            self.setupRemoteVideo(uid: uid)
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted: Bool, byUid uid: UInt) {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "didVideoMuted() Remote video muted: \(muted) by uid: \(uid)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        AppLogger.log(tag: "LOG-APP: LiveCallManager", message: "didOccurError() Agora error: \(errorCode.rawValue)")
    }
}