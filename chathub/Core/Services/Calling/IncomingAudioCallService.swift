import Foundation
import UIKit
import AVFoundation
import FirebaseFirestore
import AgoraRtcKit

/// IncomingAudioCallService - iOS equivalent of Android IncomingAudioCallService
/// Provides background incoming audio call functionality with 100% Android parity
@objc(IncomingAudioCallService)
class IncomingAudioCallService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = IncomingAudioCallService()
    private override init() { super.init() }
    
    // MARK: - Properties (Android Parity)
    @Published var callStatus: String = "Incoming call..."
    @Published var callDuration: String = "00:00"
    @Published var isCallActive: Bool = false
    @Published var callLifted: Bool = false
    
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
    
    // Timers and listeners
    private var callTimer: Timer?
    private var callCutListener: ListenerRegistration?
    private var countDownTimer: Timer?
    private var countDown: Int = 0
    
    // Delegate for activity communication
    weak var delegate: IncomingAudioCallServiceDelegate?
    
    // MARK: - Service Lifecycle (Android Parity)
    
    /// Start service - Android onCreate() + onStartCommand() equivalent
    func startService(callerUid: String, callerName: String, channelName: String) {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "startService() called from caller: \(callerName)")
        
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
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "stopService() called")
        
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
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["incoming_audio_call"])
    }
    
    // MARK: - Call Answer/Reject (Android Parity)
    
    /// Answer incoming call - Android answerCall() equivalent
    func answerCall() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "answerCall() answering incoming audio call")
        
        stopRingSound()
        callLifted = true
        
        // Initialize Agora engine
        initializeAgoraEngine()
        
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
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "rejectCall() rejecting incoming audio call")
        
        stopRingSound()
        
        // End call in Firebase
        setIncomingCallFalse()
        
        // Stop service
        stopService()
        
        // Notify delegate
        delegate?.deleteListenerAndLeaveChannel()
    }
    
    // MARK: - Agora Engine Setup (Android Parity)
    
    /// Initialize Agora engine - Android initializeAgoraEngineDirectVoice() equivalent
    private func initializeAgoraEngine() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "initializeAgoraEngine() called")
        
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        agoraKit?.setChannelProfile(.liveBroadcasting)
        agoraKit?.setClientRole(.broadcaster)
        agoraKit?.enableAudio()
        
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "initializeAgoraEngine() engine initialized successfully")
    }
    
    /// Join channel - Android joinChannel() equivalent
    private func joinChannel(_ channelName: String, accessToken: String) {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "joinChannel() called - channel: \(channelName)")
        
        guard let agoraKit = agoraKit else { return }
        
        let userId = sessionManager.userId?.hashValue ?? 0
        let result = agoraKit.joinChannel(byToken: accessToken.isEmpty ? nil : accessToken,
                                         channelId: channelName,
                                         info: "\(channelName)_Channel name",
                                         uid: UInt(userId))
        
        if result == 0 {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "joinChannel() successfully joined")
        } else {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "joinChannel() failed with code: \(result)")
        }
    }
    
    // MARK: - Call Timer (Android Parity)
    
    /// Start call timer - Android timer() equivalent
    func startTimer() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "startTimer() called")
        
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
            
            // Track time consumption in TimeAllocationManager for Pro subscribers
            let subscriptionManager = SubscriptionSessionManager.shared
            if subscriptionManager.hasProTier() {
                TimeAllocationManager.shared.consumeCallTime(seconds: 1)
            }
            
            if self.countDown <= 0 {
                self.delegate?.deleteListenerAndLeaveChannel()
            }
        }
    }
    
    // MARK: - Audio Management (Android Parity)
    
    /// Start ringing sound - Android startRingSound() equivalent
    func startRingSound() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "startRingSound() using system ringtone")
        
        // Use system ringtone instead of custom MP3 file
        SystemSoundManager.shared.playIncomingCallRingtone()
    }
    
    /// Stop ringing sound - Android stopRingSound() equivalent
    func stopRingSound() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "stopRingSound() system sounds stop automatically")
        
        // System sounds are short and stop automatically
        SystemSoundManager.shared.stopAllSounds()
    }
    
    // MARK: - Session Management (Android Parity)
    
    /// Set call details in session - Android setCallDetailsInSession() equivalent
    private func setCallDetailsInSession(_ set: Bool) {
        if set {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "setCallDetailsInSession() set")
            messagingSettingsManager.inCall = true
            messagingSettingsManager.incomingCallerId = callerUid
            messagingSettingsManager.incomingCallerName = callerName
            messagingSettingsManager.incomingChannelName = "AudioCall"
        } else {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "setCallDetailsInSession() removed")
            messagingSettingsManager.clearIncomingCall()
        }
    }
    
    /// Set incoming call false in Firebase - Android setIncomingCallFalse() equivalent
    private func setIncomingCallFalse() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "setIncomingCallFalse() called")
        
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
                AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "setIncomingCallFalse() error: \(error)")
            } else {
                AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "setIncomingCallFalse() call ended successfully")
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
                    AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "setupCallCutListener() call ended detected")
                    self?.delegate?.deleteListenerAndLeaveChannel()
                }
            }
    }
    
    // MARK: - Notification Setup (iOS Equivalent of Android Foreground Service)
    
    private func setupCallNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Incoming Audio Call"
        content.body = "\(callerName) is calling..."
        content.sound = nil // We handle sound separately
        
        // Add answer and decline actions
        let answerAction = UNNotificationAction(
            identifier: "ANSWER_AUDIO_CALL",
            title: "Answer",
            options: [.foreground]
        )
        
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_AUDIO_CALL",
            title: "Decline",
            options: [.destructive]
        )
        
        let category = UNNotificationCategory(
            identifier: "INCOMING_AUDIO_CALL",
            actions: [answerAction, declineAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "INCOMING_AUDIO_CALL"
        
        // Add user info for notification handling
        content.userInfo = [
            "caller_uid": callerUid,
            "caller_name": callerName,
            "channel_name": channelName,
            "call_type": "audio",
            "is_incoming": true
        ]
        
        let request = UNNotificationRequest(
            identifier: "incoming_audio_call",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - AgoraRtcEngineDelegate (Android IRtcEngineEventHandler Parity)
extension IncomingAudioCallService: AgoraRtcEngineDelegate {
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "didJoinedOfUid() other user joined channel")
        
        // Start call timer
        startTimer()
        
        DispatchQueue.main.async {
            self.isCallActive = true
            self.callStatus = "Connected"
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "didOfflineOfUid() other user went offline")
        
        callCutListener?.remove()
        delegate?.deleteListenerAndLeaveChannel()
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStateChangedOfUid uid: UInt, state: AgoraAudioRemoteState, reason: AgoraAudioRemoteReason, elapsed: Int) {
        
        // User muted audio
        if reason == .remoteMuted {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "remoteAudioStateChanged() other user muted audio")
        }
        
        // User left channel
        if reason == .remoteOffline {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallService", message: "remoteAudioStateChanged() other user left channel")
            
            callCutListener?.remove()
            delegate?.deleteListenerAndLeaveChannel()
        }
    }
}

// MARK: - Service Delegate Protocol (Android ServiceCallingActivity Parity)
protocol IncomingAudioCallServiceDelegate: AnyObject {
    func deleteListenerAndLeaveChannel()
    func updateTimer(_ timeString: String)
    func setCallLiftedView(lifted: Bool)
    func leaveChannel()
}