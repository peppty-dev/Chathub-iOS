import Foundation
import UIKit
import AVFoundation
import FirebaseFirestore
import AgoraRtcKit

/// IncomingVideoCallService - iOS equivalent of Android IncomingVideoCallService
/// Provides background incoming video call functionality with 100% Android parity
@objc(IncomingVideoCallService)
class IncomingVideoCallService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = IncomingVideoCallService()
    private override init() { super.init() }
    
    // MARK: - Properties (Android Parity)
    @Published var callStatus: String = "Incoming call..."
    @Published var callDuration: String = "00:00"
    @Published var isCallActive: Bool = false
    @Published var callLifted: Bool = false
    @Published var localVideoOn: Bool = true
    @Published var remoteVideoOn: Bool = true
    
    private var callerUid: String = ""
    private var callerName: String = ""
    private var channelName: String = ""
    
    // Audio and Firebase
    // audioPlayer removed - now using SystemSoundManager
    private let database = Firestore.firestore()
    private let sessionManager = SessionManager.shared
    private let messagingSettingsManager = MessagingSettingsSessionManager.shared
    
    // Agora
    private var agoraKit: AgoraRtcEngineKit?
    private let appId = "8173040ab4524a64a1051a44026b9677" // Android parity
    
    // Video views
    private var localVideoCanvas: AgoraRtcVideoCanvas?
    private var remoteVideoCanvas: AgoraRtcVideoCanvas?
    
    // Timers and listeners
    private var callTimer: Timer?
    private var callCutListener: ListenerRegistration?
    private var countDownTimer: Timer?
    private var countDown: Int = 0
    
    // Delegate for activity communication
    weak var delegate: IncomingVideoCallServiceDelegate?
    
    // MARK: - Service Lifecycle (Android Parity)
    
    /// Start service - Android onCreate() + onStartCommand() equivalent
    func startService(callerUid: String, callerName: String, channelName: String) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "startService() called from caller: \(callerName)")
        
        self.callerUid = callerUid
        self.callerName = callerName
        self.channelName = channelName
        
        // Android parity: Set call details in session
        setCallDetailsInSession(true)
        
        // Android parity: Start ringing sound
        startRingSound()
        
        // iOS equivalent of Android foreground notification
        setupCallNotification()
        
        // Setup call cut listener
        setupCallCutListener()
    }
    
    /// Stop service - Android onDestroy() equivalent
    func stopService() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "stopService() called")
        
        stopRingSound()
        setCallDetailsInSession(false)
        
        countDownTimer?.invalidate()
        callTimer?.invalidate()
        callCutListener?.remove()
        
        agoraKit?.leaveChannel(nil)
        AgoraRtcEngineKit.destroy()
        
        isCallActive = false
        callLifted = false
        
        // Clear notification
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["incoming_video_call"])
    }
    
    // MARK: - Call Answer/Reject (Android Parity)
    
    /// Answer incoming call - Android answerCall() equivalent
    func answerCall() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "answerCall() answering incoming video call")
        
        stopRingSound()
        callLifted = true
        
        // Initialize Agora engine
        initializeAgoraEngine()
        
        // Setup video configuration
        setupVideoConfig()
        
        // Setup local video
        _ = setupLocalVideo()
        
        // Join channel
        joinChannel(channelName, accessToken: "")
        
        // Update call status
        DispatchQueue.main.async {
            self.callStatus = "Connecting..."
            self.isCallActive = true
        }
        
        // Notify delegate
        delegate?.setCallLiftedView(lifted: true)
    }
    
    /// Reject incoming call - Android rejectCall() equivalent
    func rejectCall() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "rejectCall() rejecting incoming video call")
        
        stopRingSound()
        
        // End call in Firebase
        setIncomingCallFalse()
        
        // Stop service
        stopService()
        
        // Notify delegate
        delegate?.deleteListenerAndLeaveChannel()
    }
    
    // MARK: - Agora Engine Setup (Android Parity)
    
    /// Initialize Agora engine - Android initializeAgoraEngine() equivalent
    private func initializeAgoraEngine() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "initializeAgoraEngine() called")
        
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        agoraKit?.setChannelProfile(.liveBroadcasting)
        agoraKit?.setClientRole(.broadcaster)
        agoraKit?.enableVideo()
        agoraKit?.enableAudio()
        
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "initializeAgoraEngine() engine initialized successfully")
    }
    
    /// Setup video configuration - Android setupVideoConfig() equivalent
    func setupVideoConfig() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "setupVideoConfig() called")
        
        let videoConfig = AgoraVideoEncoderConfiguration(
            size: AgoraVideoDimension640x360,
            frameRate: .fps15,
            bitrate: AgoraVideoBitrateStandard,
            orientationMode: .adaptative,
            mirrorMode: .disabled
        )
        
        agoraKit?.setVideoEncoderConfiguration(videoConfig)
    }
    
    /// Setup local video - Android setupLocalVideo() equivalent
    func setupLocalVideo() -> UIView? {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "setupLocalVideo() called")
        
        guard let agoraKit = agoraKit else { return nil }
        
        agoraKit.setClientRole(.broadcaster)
        agoraKit.muteLocalVideoStream(false)
        agoraKit.enableVideo()
        
        let localView = UIView()
        localView.backgroundColor = UIColor.black
        
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.view = localView
        videoCanvas.renderMode = .hidden
        videoCanvas.uid = 0
        
        agoraKit.setupLocalVideo(videoCanvas)
        localVideoCanvas = videoCanvas
        
        return localView
    }
    
    /// Setup remote video - Android setupRemoteVideo() equivalent
    func setupRemoteVideo(uid: UInt) -> UIView? {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "setupRemoteVideo() called")
        
        stopRingSound()
        
        guard let agoraKit = agoraKit else { return nil }
        
        let remoteView = UIView()
        remoteView.backgroundColor = UIColor.black
        
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.view = remoteView
        videoCanvas.renderMode = .hidden
        videoCanvas.uid = uid
        
        agoraKit.setupRemoteVideo(videoCanvas)
        agoraKit.setRemoteRenderMode(uid, mode: .hidden, mirror: .auto)
        
        remoteVideoCanvas = videoCanvas
        
        return remoteView
    }
    
    /// Remove remote video - Android removeRemoteVideo() equivalent
    func removeRemoteVideo(uid: UInt) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "removeRemoteVideo() called")
        
        guard let agoraKit = agoraKit else { return }
        
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.view = nil
        videoCanvas.uid = uid
        
        agoraKit.setupRemoteVideo(videoCanvas)
        remoteVideoCanvas = nil
    }
    
    /// Join channel - Android joinChannel() equivalent
    private func joinChannel(_ channelName: String, accessToken: String) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "joinChannel() called - channel: \(channelName)")
        
        guard let agoraKit = agoraKit else { return }
        
        let userId = sessionManager.userId?.hashValue ?? 0
        let result = agoraKit.joinChannel(byToken: accessToken.isEmpty ? nil : accessToken,
                                         channelId: channelName,
                                         info: "\(channelName)_Channel name",
                                         uid: UInt(userId))
        
        if result == 0 {
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "joinChannel() successfully joined")
        } else {
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "joinChannel() failed with code: \(result)")
        }
    }
    
    // MARK: - Call Timer (Android Parity)
    
    /// Start call timer - Android timer() equivalent
    func startTimer() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "startTimer() called")
        
        let callSeconds = sessionManager.callSeconds
        countDown = callSeconds
        
        countDownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.countDown -= 1
            let minutes = (callSeconds - self.countDown) / 60
            let seconds = (callSeconds - self.countDown) % 60
            
            let formattedTime = String(format: "%02d:%02d", minutes, seconds)
            
            DispatchQueue.main.async {
                self.callDuration = formattedTime
                self.delegate?.updateTimer(formattedTime)
            }
            
            // Update session manager
            self.sessionManager.callSeconds = self.countDown
            
            if self.countDown <= 0 {
                self.delegate?.deleteListenerAndLeaveChannel()
            }
        }
    }
    
    // MARK: - Audio Management (Android Parity)
    
    /// Start ringing sound - Android startRingSound() equivalent
    func startRingSound() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "startRingSound() using system ringtone")
        
        // Use system ringtone instead of custom MP3 file
        SystemSoundManager.shared.playIncomingCallRingtone()
    }
    
    /// Stop ringing sound - Android stopRingSound() equivalent
    func stopRingSound() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "stopRingSound() system sounds stop automatically")
        
        // System sounds are short and stop automatically
        SystemSoundManager.shared.stopAllSounds()
    }
    
    // MARK: - Video State Management (Android Parity)
    
    /// Get local video state - Android getLocalVideoOn() equivalent
    func getLocalVideoOn() -> Bool {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "getLocalVideoOn() called")
        return localVideoOn
    }
    
    /// Set local video state - Android setLocalVideoOn() equivalent
    func setLocalVideoOn(_ video: Bool) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "setLocalVideoOn() called")
        localVideoOn = video
    }
    
    /// Get remote video state - Android getRemoteVideoOn() equivalent
    func getRemoteVideoOn() -> Bool {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "getRemoteVideoOn() called")
        return remoteVideoOn
    }
    
    /// Set remote video state - Android setRemoteVideoOn() equivalent
    func setRemoteVideoOn(_ video: Bool) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "setRemoteVideoOn() called")
        remoteVideoOn = video
    }
    
    // MARK: - Session Management (Android Parity)
    
    /// Set call details in session - Android setCallDetailsInSession() equivalent
    private func setCallDetailsInSession(_ set: Bool) {
        if set {
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "setCallDetailsInSession() set")
            messagingSettingsManager.setIncomingCall(callerId: callerUid, callerName: callerName, channelName: "VideoCall")
        } else {
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "setCallDetailsInSession() removed")
            messagingSettingsManager.clearIncomingCall()
        }
    }
    
    /// Set incoming call false in Firebase - Android setIncomingCallFalse() equivalent
    private func setIncomingCallFalse() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "setIncomingCallFalse() called")
        
        guard let userId = sessionManager.userId else { return }
        
        let batch = database.batch()
        
        // End call for current user
        let currentUserData: [String: Any] = [
            "call_ended": true,
            "incoming_call": false
        ]
        
        let currentUserRef = database.collection("Users").document(userId).collection("Calls").document("Calls")
        batch.setData(currentUserData, forDocument: currentUserRef, merge: true)
        
        // End call for caller
        let callerData: [String: Any] = [
            "call_ended": true,
            "incoming_call": false
        ]
        
        let callerRef = database.collection("Users").document(callerUid).collection("Calls").document("Calls")
        batch.setData(callerData, forDocument: callerRef, merge: true)
        
        // Update online status
        setOnCallStatus(uid: userId, onCall: false)
        setOnCallStatus(uid: callerUid, onCall: false)
        
        batch.commit { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "setIncomingCallFalse() error: \(error)")
            } else {
                AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "setIncomingCallFalse() call ended successfully")
            }
        }
    }
    
    /// Set user online call status - Android setOnCall() equivalent
    private func setOnCallStatus(uid: String, onCall: Bool) {
        let data: [String: Any] = ["on_call": onCall]
        database.collection("Users").document(uid).setData(data, merge: true)
    }
    
    // MARK: - Firebase Listeners (Android Parity)
    
    /// Setup call cut listener - Android callCutListener() equivalent
    private func setupCallCutListener() {
        guard let userId = sessionManager.userId else { return }
        
        callCutListener = database.collection("Users")
            .document(userId)
            .collection("Calls")
            .document("Calls")
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let document = documentSnapshot, document.exists else { return }
                
                let data = document.data()
                let callEnded = data?["call_ended"] as? Bool ?? false
                
                if callEnded {
                    AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "setupCallCutListener() call ended detected")
                    self?.delegate?.deleteListenerAndLeaveChannel()
                }
            }
    }
    
    // MARK: - Notification Setup (iOS Equivalent of Android Foreground Service)
    
    private func setupCallNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Incoming Video Call"
        content.body = "\(callerName) is calling..."
        content.sound = nil // We handle sound separately
        
        // Add answer and decline actions
        let answerAction = UNNotificationAction(
            identifier: "ANSWER_VIDEO_CALL",
            title: "Answer",
            options: [.foreground]
        )
        
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_VIDEO_CALL",
            title: "Decline",
            options: [.destructive]
        )
        
        let category = UNNotificationCategory(
            identifier: "INCOMING_VIDEO_CALL",
            actions: [answerAction, declineAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "INCOMING_VIDEO_CALL"
        
        // Add user info for notification handling
        content.userInfo = [
            "caller_uid": callerUid,
            "caller_name": callerName,
            "channel_name": channelName,
            "call_type": "video",
            "is_incoming": true
        ]
        
        let request = UNNotificationRequest(
            identifier: "incoming_video_call",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - AgoraRtcEngineDelegate (Android IRtcEngineEventHandler Parity)
extension IncomingVideoCallService: AgoraRtcEngineDelegate {
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteVideoStateChangedOfUid uid: UInt, state: AgoraVideoRemoteState, reason: AgoraVideoRemoteReason, elapsed: Int) {
        
        DispatchQueue.main.async {
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "remoteVideoStateChanged() uid: \(uid), state: \(state.rawValue), reason: \(reason.rawValue)")
            
            if reason == .remoteUnmuted {
                AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "remoteVideoStateChanged() remote receiving resumed")
                _ = self.setupRemoteVideo(uid: uid)
            }
            
            if reason == .remoteMuted {
                AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "remoteVideoStateChanged() remote receiving stopped")
                self.removeRemoteVideo(uid: uid)
            }
            
            if state == .decoding {
                AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "remoteVideoStateChanged() remote receiving started")
                _ = self.setupRemoteVideo(uid: uid)
            }
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "didJoinedOfUid() other user joined channel")
        
        DispatchQueue.main.async {
            _ = self.setupRemoteVideo(uid: uid)
            self.startTimer()
            
            self.isCallActive = true
            self.callStatus = "Connected"
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallService", message: "didOfflineOfUid() other user went offline")
        
        callCutListener?.remove()
        delegate?.deleteListenerAndLeaveChannel()
    }
}

// MARK: - Service Delegate Protocol (Android ServiceCallingActivity Parity)
protocol IncomingVideoCallServiceDelegate: AnyObject {
    func deleteListenerAndLeaveChannel()
    func updateTimer(_ timeString: String)
    func setCallLiftedView(lifted: Bool)
    func setupRemoteVideo(uid: UInt)
    func removeRemoteVideo(uid: UInt)
    func setupVideoConfig()
    func setupLocalVideo()
    func leaveChannel()
} 