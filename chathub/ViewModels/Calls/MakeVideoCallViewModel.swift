import Foundation
import SwiftUI
import AgoraRtcKit
import AVFAudio
import FirebaseFirestore

// MARK: - MakeVideoCallViewModel for 100% Android Parity - Using Background Service
@objc(MakeVideoCallViewModel)
class MakeVideoCallViewModel: NSObject, ObservableObject, MakeVideoCallServiceDelegate {
    @Published var callStatus: String = "calling..."
    @Published var isMuted: Bool = false
    @Published var isCameraOn: Bool = true
    @Published var isLocalVideoRender: Bool = false
    @Published var isRemoteVideoRender: Bool = true
    @Published var isSwitchingCamera: Bool = false
    @Published var showEndCallConfirmation: Bool = false
    @Published var remoteVideoUid: UInt? = nil
    @Published var remainingTime: Int16 = 0
    @Published var callDuration: String = "00:00"
    
    // MARK: - Properties (Android Parity)
    let otherUserId: String
    let otherUserName: String
    let otherUserProfileImage: String
    let channelId: String
    private let currentUserId: String
    
    // Android parity: Use background service instead of direct implementation
    private let makeVideoCallService = MakeVideoCallService.shared
    
    // Local and remote video views
    private var localVideoView: UIView?
    private var remoteVideoView: UIView?
    
    // Dismiss callback
    var onDismiss: (() -> Void)?
    
    init(otherUserId: String, otherUserName: String, otherUserProfileImage: String, channelId: String) {
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        self.otherUserProfileImage = otherUserProfileImage
        self.channelId = channelId
        // Use specialized UserSessionManager instead of monolithic SessionManager
        self.currentUserId = UserSessionManager.shared.userId ?? ""
        
        super.init()
        
        // Android parity: Set service delegate
        makeVideoCallService.delegate = self
        
        // Android parity: Start background service
        startVideoCallService()
    }
    
    deinit {
        // Android parity: Stop service
        makeVideoCallService.stopService()
    }
    
    // MARK: - Service Management (Android Parity)
    
    private func startVideoCallService() {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "startVideoCallService() starting video call service")
        
        // Android parity: Start service with caller details
        makeVideoCallService.startService(
            callerUid: otherUserId,
            callerName: otherUserName,
            channelName: channelId
        )
    }
    
    // MARK: - Video Setup Methods (Delegated to Service)
    func setupLocalVideo() -> UIView? {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "setupLocalVideo() delegating to service")
        
        localVideoView = makeVideoCallService.setupLocalVideo()
        return localVideoView
    }
    
    func setupRemoteVideo(uid: UInt) -> UIView? {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "setupRemoteVideo() delegating to service")
        
        remoteVideoView = makeVideoCallService.setupRemoteVideo(uid: uid)
        remoteVideoUid = uid
        return remoteVideoView
    }
    
    // MARK: - Call Control Methods (Delegated to Service)
    func toggleMute() {
        isMuted.toggle()
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "toggleMute() muted: \(isMuted)")
        // Service handles Agora mute operations
    }
    
    func toggleCamera() {
        isCameraOn.toggle()
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "toggleCamera() camera on: \(isCameraOn)")
        
        // Update local video state through service
        makeVideoCallService.setLocalVideoOn(isCameraOn)
        isLocalVideoRender = isCameraOn
    }
    
    func switchCamera() {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "switchCamera() switching camera")
        isSwitchingCamera.toggle()
        // Service handles camera switching
    }
    
    func endCall() {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "endCall() ending video call")
        showEndCallConfirmation = false
        
        // Android parity: Use service to end call
        makeVideoCallService.stopService()
    }
    
    // MARK: - MakeVideoCallServiceDelegate (Android ServiceCallingActivity Parity)
    
    func deleteListenerAndLeaveChannel() {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "deleteListenerAndLeaveChannel() delegate called")
        
        DispatchQueue.main.async {
            self.callStatus = "Call Ended"
            self.onDismiss?()
        }
    }
    
    func updateTimer(_ timeString: String) {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "updateTimer() timer updated: \(timeString)")
        
        DispatchQueue.main.async {
            self.callDuration = timeString
        }
    }
    
    func setupRemoteVideo(uid: UInt) {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "setupRemoteVideo() delegate called with uid: \(uid)")
        
        DispatchQueue.main.async {
            self.remoteVideoUid = uid
            self.isRemoteVideoRender = true
            self.callStatus = "In Call"
        }
    }
    
    func removeRemoteVideo(uid: UInt) {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "removeRemoteVideo() delegate called with uid: \(uid)")
        
        DispatchQueue.main.async {
            if self.remoteVideoUid == uid {
                self.remoteVideoUid = nil
                self.isRemoteVideoRender = false
            }
        }
    }
    
    func setupVideoConfig() {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "setupVideoConfig() delegate called")
        // Handled by service
    }
    
    func setupLocalVideo() {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "setupLocalVideo() delegate called")
        
        DispatchQueue.main.async {
            self.isLocalVideoRender = true
            self.callStatus = "Connected"
        }
    }
    
    func leaveChannel() {
        AppLogger.log(tag: "LOG-APP: MakeVideoCallViewModel", message: "leaveChannel() delegate called")
        
        DispatchQueue.main.async {
            self.callStatus = "Call Ended"
            self.onDismiss?()
        }
    }
} 