import Foundation
import UIKit
import SwiftUI
import FirebaseFirestore

/// CallsService - iOS equivalent of Android CallsWorker
/// Provides Firebase call listener functionality with 100% Android parity
class CallsService {
    
    // MARK: - Singleton
    static let shared = CallsService()
    private init() {}
    
    // MARK: - Properties (Android Parity) - Use specialized managers
    private let userSessionManager = UserSessionManager.shared
    private let database = Firestore.firestore()
    private var callsListener: ListenerRegistration?
    private var isListenerActive = false
    
    // MARK: - Continuous Retry Properties (Android Parity)
    private static let TAG = "CallsService"
    private static let RETRY_DELAY_SECONDS: TimeInterval = 30.0 // 30 seconds like current implementation
    private var retryTimer: Timer?
    private var retryCount = 0
    private var isRetryingForUserId: String? = nil
    
    // MARK: - Public Methods (Android Parity)
    
    /// Starts the calls listener - Android doWork() equivalent
    func startCallsListener() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startCallsListener() starting Firebase calls listener")
        
        guard let userId = userSessionManager.userId, !userId.isEmpty else {
            // Android parity: Continuous retry until user is authenticated
            if isRetryingForUserId == nil {
                retryCount += 1
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startCallsListener() no user ID available, scheduling CONTINUOUS retry attempt \(retryCount) in \(Self.RETRY_DELAY_SECONDS)s")
                isRetryingForUserId = nil // Mark that we're retrying for null user
                scheduleContinuousRetry()
            } else {
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startCallsListener() already retrying for user authentication")
            }
            return
        }
        
        // User authenticated successfully - stop any retry timers and proceed
        stopRetryTimer()
        retryCount = 0
        isRetryingForUserId = userId
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startCallsListener() User authenticated, starting listener for userId: \(userId)")
        
        // Remove existing listener if active
        if isListenerActive {
            stopCallsListener()
        }
        
        // Android equivalent: Firebase snapshot listener setup
        callsListener = database.collection("Users")
            .document(userId)
            .collection("Calls")
            .document("Calls")
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: CallsService", message: "startCallsListener() error: \(error.localizedDescription)")
                    return
                }
                
                if let document = documentSnapshot, document.exists {
                    self.processCallData(document: document)
                }
            }
        
        isListenerActive = true
        AppLogger.log(tag: "LOG-APP: CallsService", message: "startCallsListener() calls listener started successfully")
    }
    
    /// Stops the calls listener - Android onStopped() equivalent
    func stopCallsListener() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "stopCallsListener() stopping Firebase calls listener")
        
        // Stop continuous retry mechanism
        stopRetryTimer()
        retryCount = 0
        isRetryingForUserId = nil
        
        callsListener?.remove()
        callsListener = nil
        isListenerActive = false
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "stopCallsListener() calls listener stopped")
    }
    
    // MARK: - Continuous Retry Methods (Android Parity)
    
    /// Schedules continuous retry until user authentication - iOS equivalent of Android Handler.postDelayed loop
    private func scheduleContinuousRetry() {
        stopRetryTimer() // Cancel any existing timer
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: Self.RETRY_DELAY_SECONDS, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "scheduleContinuousRetry() Executing scheduled retry attempt")
            self.startCallsListener() // CONTINUOUS RETRY - calls itself again until user is authenticated
        }
    }
    
    /// Stops the retry timer
    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    /// Gets listener status
    func isCallsListenerActive() -> Bool {
        return isListenerActive
    }
    
    // MARK: - Private Methods (Android Parity)
    
    /// Processes incoming call data - Android processCallData() equivalent
    private func processCallData(document: DocumentSnapshot) {
        AppLogger.log(tag: "LOG-APP: CallsService", message: "processCallData() processing incoming call data")
        
        // Execute on background thread like Android
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let data = document.data()
                
                // Check for incoming call - Android parity
                guard let incomingCall = data?["incoming_call"] as? Bool, incomingCall else {
                    AppLogger.log(tag: "LOG-APP: CallsService", message: "processCallData() no incoming call detected")
                    return
                }
                
                // Get call details - Android parity
                let isAudio = data?["is_audio"] as? Bool ?? true
                let channelName = data?["channel_name"] as? String ?? ""
                let callerName = data?["caller_name"] as? String ?? ""
                let callerUid = data?["caller_uid"] as? String ?? ""
                
                // Validate channel name - Android parity
                guard !channelName.isEmpty else {
                    AppLogger.log(tag: "LOG-APP: CallsService", message: "processCallData() channel name is empty")
                    return
                }
                
                // Check if already in call - Android parity
                guard !self.userSessionManager.inCall else {
                    AppLogger.log(tag: "LOG-APP: CallsService", message: "processCallData() already in call, ignoring")
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: CallsService", message: "processCallData() processing \(isAudio ? "audio" : "video") call from \(callerName)")
                
                // Store call data in Core Data - Android parity
                self.storeIncomingCallData(
                    channelName: channelName,
                    callerName: callerName,
                    callerUid: callerUid,
                    isAudio: isAudio
                )
                
                // Show incoming call screen on main thread - Android parity
                DispatchQueue.main.async {
                    self.showIncomingCallScreen(isAudio: isAudio)
                }
                
            } catch {
                AppLogger.log(tag: "LOG-APP: CallsService", message: "processCallData() error processing call data: \(error.localizedDescription)")
            }
        }
    }
    
    /// Stores incoming call data using IncomingCallManager - Android parity
    private func storeIncomingCallData(channelName: String, callerName: String, callerUid: String, isAudio: Bool) {
        AppLogger.log(tag: "LOG-APP: CallsService", message: "storeIncomingCallData() storing call data: \(callerName)")
        
        let incomingCallManager = IncomingCallManager.shared
        incomingCallManager.setIncomingCallData(
            channelName: channelName,
            callerName: callerName,
            callerId: callerUid,
            isAudioCall: isAudio
        )
        
        AppLogger.log(tag: "LOG-APP: CallsService", message: "storeIncomingCallData() call data stored successfully using IncomingCallManager")
    }
    
    /// Shows incoming call screen - Android Intent equivalent
    private func showIncomingCallScreen(isAudio: Bool) {
        AppLogger.log(tag: "LOG-APP: CallsService", message: "showIncomingCallScreen() showing \(isAudio ? "audio" : "video") call screen")
        
        // Navigate to appropriate incoming call screen
        if isAudio {
            NavigationManager.shared.navigateToIncomingAudioCall()
        } else {
            NavigationManager.shared.navigateToIncomingVideoCall()
        }
    }
}

// MARK: - SessionManager Extension for Call State (Android Parity)
extension UserSessionManager {
    
    /// Gets whether user is currently in a call - Android getInCall() equivalent
    var inCall: Bool {
        get { UserDefaults.standard.bool(forKey: "inCall") }
        set { 
            UserDefaults.standard.set(newValue, forKey: "inCall")
            synchronize()
        }
    }
    
    /// Sets in-call status - Android setInCall() equivalent
    func setInCall(_ inCall: Bool) {
        self.inCall = inCall
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setInCall() call status set to: \(inCall)")
    }
    
    /// Gets in-call status - Android getInCall() equivalent
    func getInCall() -> Bool {
        return inCall
    }
}

// MARK: - NavigationManager Extension for Call Navigation
extension NavigationManager {
    
    /// Navigates to incoming audio call screen - Android Intent equivalent
    func navigateToIncomingAudioCall() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToIncomingAudioCall() navigating to audio call screen")
        
        DispatchQueue.main.async {
            // Set root view to incoming audio call
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let incomingCallView = IncomingAudioCallAnswerView()
                let hostingController = UIHostingController(rootView: incomingCallView)
                window.rootViewController = hostingController
                window.makeKeyAndVisible()
            }
        }
    }
    
    /// Navigates to incoming video call screen - Android Intent equivalent
    func navigateToIncomingVideoCall() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToIncomingVideoCall() navigating to video call screen")
        
        DispatchQueue.main.async {
            // Set root view to incoming video call
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let incomingCallView = IncomingVideoCallAnswerView()
                let hostingController = UIHostingController(rootView: incomingCallView)
                window.rootViewController = hostingController
                window.makeKeyAndVisible()
            }
        }
    }
} 