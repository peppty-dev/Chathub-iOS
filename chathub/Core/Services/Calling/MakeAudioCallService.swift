import Foundation
import UIKit
import AVFoundation
import FirebaseFirestore
import AgoraRtcKit

/// MakeAudioCallService - iOS equivalent of Android MakeAudioCallService
/// Provides background audio call functionality with 100% Android parity
@objc(MakeAudioCallService)
class MakeAudioCallService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = MakeAudioCallService()
    private override init() { super.init() }
    
    // MARK: - Properties (Android Parity)
    @Published var callStatus: String = "Calling..."
    @Published var callDuration: String = "00:00"
    @Published var isCallActive: Bool = false
    
    private var callerUid: String = ""
    private var callerName: String = ""
    private var channelName: String = ""
    private var callStarted: Bool = false
    
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
    weak var delegate: MakeAudioCallServiceDelegate?
    
    // MARK: - Service Lifecycle (Android Parity)
    
    /// Start service - Android onCreate() + onStartCommand() equivalent
    func startService(callerUid: String, callerName: String, channelName: String) {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "startService() called with caller: \(callerName)")
        
        self.callerUid = callerUid
        self.callerName = callerName
        self.channelName = channelName
        
        // Android parity: Set call details in session
        setCallDetailsInSession(true)
        
        // Android parity: Start ringing sound
        startRingSound()
        
        if !callStarted {
            callStarted = true
            startCall()
        }
        
        // iOS equivalent of Android foreground notification
        setupCallNotification()
    }
    
    /// Stop service - Android onDestroy() equivalent
    func stopService() {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "stopService() called")
        
        stopRingSound()
        setCallDetailsInSession(false)
        
        countDownTimer?.invalidate()
        callTimer?.invalidate()
        callCutListener?.remove()
        
        agoraKit?.leaveChannel(nil)
        AgoraRtcEngineKit.destroy()
        
        isCallActive = false
        callStarted = false
        
        // Clear notification
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["audio_call"])
    }
    
    // MARK: - Agora Engine Setup (Android Parity)
    
    /// Initialize Agora engine - Android initializeAgoraEngine() equivalent
    private func initializeAgoraEngine() -> AgoraRtcEngineKit? {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "initializeAgoraEngine() called")
        
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        agoraKit?.setChannelProfile(.communication)
        agoraKit?.setClientRole(.broadcaster)
        agoraKit?.enableAudio()
        
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "initializeAgoraEngine() engine initialized successfully")
        return agoraKit
    }
    
    /// Join channel - Android joinChannel() equivalent
    private func joinChannel(_ channelName: String, accessToken: String) {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "joinChannel() called - channel: \(channelName)")
        
        guard let agoraKit = agoraKit else { return }
        
        let userId = sessionManager.userId?.hashValue ?? 0
        let result = agoraKit.joinChannel(byToken: accessToken.isEmpty ? nil : accessToken,
                                         channelId: channelName,
                                         info: "\(channelName)_Channel name",
                                         uid: UInt(userId))
        
        if result == 0 {
            AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "joinChannel() successfully joined")
        } else {
            AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "joinChannel() failed with code: \(result)")
        }
    }
    
    // MARK: - Call Management (Android Parity)
    
    /// Start call - Android startCall() equivalent
    private func startCall() {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "startCall() called")
        
        // Generate random channel name like Android
        let generatedChannelName = generateRandomString(length: 14)
        putInFirebase(channelName: generatedChannelName, accessToken: "")
    }
    
    /// Put call data in Firebase - Android putInFirebase() equivalent
    private func putInFirebase(channelName: String, accessToken: String) {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "putInFirebase() called")
        
        guard let userId = sessionManager.userId else { return }
        
        let batch = database.batch()
        
        // Set caller data
        let callerData: [String: Any] = [
            "channel_name": channelName,
            "caller_name": callerName,
            "caller_uid": callerUid,
            "incoming_call": false,
            "is_audio": true,
            "call_ended": false
        ]
        
        let callerRef = database.collection("Users").document(userId).collection("Calls").document("Calls")
        batch.setData(callerData, forDocument: callerRef, merge: true)
        
        // Set receiver data
        let receiverData: [String: Any] = [
            "channel_name": channelName,
            "caller_name": sessionManager.userName ?? "",
            "caller_uid": userId,
            "incoming_call": true,
            "is_audio": true,
            "call_ended": false
        ]
        
        let receiverRef = database.collection("Users").document(callerUid).collection("Calls").document("Calls")
        batch.setData(receiverData, forDocument: receiverRef, merge: true)
        
        // Set online status
        setOnCall(uid: userId, onCall: true)
        setOnCall(uid: callerUid, onCall: true)
        
        batch.commit { [weak self] error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "putInFirebase() error: \(error)")
                return
            }
            
            self?.callCutListener?.remove()
            
            // Initialize Agora and join channel
            _ = self?.initializeAgoraEngine()
            self?.joinChannel(channelName, accessToken: accessToken)
            self?.setupCallCutListener()
        }
    }
    
    /// Set user online call status - Android setOnCall() equivalent
    private func setOnCall(uid: String, onCall: Bool) {
        let data: [String: Any] = ["on_call": onCall]
        database.collection("Users").document(uid).setData(data, merge: true)
    }
    
    // MARK: - Call Timer (Android Parity)
    
    /// Start call timer - Android timer() equivalent
    func startTimer() {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "startTimer() called")
        
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
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "startRingSound() using system ringtone")
        
        // Use system ringtone instead of custom MP3 file
        SystemSoundManager.shared.playOutgoingCallRingtone()
    }
    
    /// Stop ringing sound - Android stopRingSound() equivalent
    func stopRingSound() {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "stopRingSound() system sounds stop automatically")
        
        // System sounds are short and stop automatically
        SystemSoundManager.shared.stopAllSounds()
    }
    
    // MARK: - Session Management (Android Parity)
    
    /// Set call details in session - Android setCallDetailsInSession() equivalent
    private func setCallDetailsInSession(_ set: Bool) {
        if set {
            AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "setCallDetailsInSession() set")
            messagingSettingsManager.setIncomingCall(callerId: callerUid, callerName: callerName, channelName: "AudioCall")
        } else {
            AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "setCallDetailsInSession() removed")
            messagingSettingsManager.clearIncomingCall()
        }
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
                    AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "setupCallCutListener() call ended detected")
                    self?.delegate?.deleteListenerAndLeaveChannel()
                }
            }
    }
    
    // MARK: - Notification Setup (iOS Equivalent of Android Foreground Service)
    
    private func setupCallNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Audio Call"
        content.body = "Calling \(callerName)..."
        content.sound = nil // We handle sound separately
        
        // Add call end action
        let endCallAction = UNNotificationAction(
            identifier: "END_CALL",
            title: "End Call",
            options: [.destructive]
        )
        
        let category = UNNotificationCategory(
            identifier: "AUDIO_CALL",
            actions: [endCallAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "AUDIO_CALL"
        
        let request = UNNotificationRequest(
            identifier: "audio_call",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Utility Methods (Android Parity)
    
    private func generateRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap{ _ in 
            guard let randomChar = letters.randomElement() else {
                AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "generateRandomString() failed to get random character, using default")
                return "A"
            }
            return randomChar
        })
    }
}

// MARK: - AgoraRtcEngineDelegate (Android IRtcEngineEventHandler Parity)
extension MakeAudioCallService: AgoraRtcEngineDelegate {
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "didOfflineOfUid() other user went offline")
        
        callCutListener?.remove()
        delegate?.deleteListenerAndLeaveChannel()
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "didJoinedOfUid() other user joined channel")
        
        stopRingSound()
        startTimer()
        
        DispatchQueue.main.async {
            self.isCallActive = true
            self.callStatus = "Connected"
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStateChangedOfUid uid: UInt, state: AgoraAudioRemoteState, reason: AgoraAudioRemoteReason, elapsed: Int) {
        
        // User muted audio
        if reason == .remoteMuted {
            AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "remoteAudioStateChanged() other user muted audio")
            // Show toast equivalent
            DispatchQueue.main.async {
                // Could show banner or alert here
            }
        }
        
        // User left channel
        if reason == .remoteOffline {
            AppLogger.log(tag: "LOG-APP: MakeAudioCallService", message: "remoteAudioStateChanged() other user left channel")
            
            callCutListener?.remove()
            delegate?.deleteListenerAndLeaveChannel()
        }
    }
}

// MARK: - Service Delegate Protocol (Android ServiceCallingActivity Parity)
protocol MakeAudioCallServiceDelegate: AnyObject {
    func deleteListenerAndLeaveChannel()
    func updateTimer(_ timeString: String)
    func leaveChannel()
}

// MARK: - SessionManager Extension for Call Data
extension SessionManager {
    
    /// Caller UID - Android getCallerUid() equivalent
    var callerUid: String {
        get { UserDefaults.standard.string(forKey: "caller_uid") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "caller_uid") }
    }
    
    /// Channel name - Android getChannelName() equivalent
    var channelName: String {
        get { UserDefaults.standard.string(forKey: "channel_name") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "channel_name") }
    }
}