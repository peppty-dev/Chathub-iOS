import Foundation
import SwiftUI
import AgoraRtcKit

@objc(MakeAudioCallViewModel)
class MakeAudioCallViewModel: NSObject, ObservableObject, MakeAudioCallServiceDelegate {
    @Published var callStatus: String = "Calling..."
    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = false
    @Published var isConnected: Bool = false
    @Published var showEndCallAlert: Bool = false
    @Published var callDuration: String = "00:00"
    
    // MARK: - Properties (Android Parity)
    private let otherUserId: String
    private let otherUserName: String
    private let channelId: String
    private let currentUserId: String
    
    // Android parity: Use background service instead of direct implementation
    private let makeAudioCallService = MakeAudioCallService.shared
    
    // Dismiss callback
    var onDismiss: (() -> Void)?
    
    init(otherUserId: String, otherUserName: String, channelId: String) {
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        self.channelId = channelId
        // Use specialized UserSessionManager instead of monolithic SessionManager
        self.currentUserId = UserSessionManager.shared.userId ?? ""
        
        super.init()
        
        // Android parity: Set service delegate
        makeAudioCallService.delegate = self
        
        // Android parity: Start background service
        startAudioCallService()
    }
    
    deinit {
        // Android parity: Stop service
        makeAudioCallService.stopService()
    }
    
    // MARK: - Service Management (Android Parity)
    
    private func startAudioCallService() {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallViewModel", message: "startAudioCallService() starting audio call service")
        
        // Android parity: Start service with caller details
        makeAudioCallService.startService(
            callerUid: otherUserId,
            callerName: otherUserName,
            channelName: channelId
        )
    }
    
    // MARK: - Call Control Methods (Delegated to Service)
    func toggleMute() {
        isMuted.toggle()
        AppLogger.log(tag: "LOG-APP: MakeAudioCallViewModel", message: "toggleMute() muted: \(isMuted)")
        // Service handles Agora mute operations
    }
    
    func toggleSpeaker() {
        isSpeakerOn.toggle()
        AppLogger.log(tag: "LOG-APP: MakeAudioCallViewModel", message: "toggleSpeaker() speaker on: \(isSpeakerOn)")
        // Service handles speaker operations
    }
    
    func endCall() {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallViewModel", message: "endCall() ending audio call")
        showEndCallAlert = false
        
        // Android parity: Use service to end call
        makeAudioCallService.stopService()
    }
    
    // MARK: - MakeAudioCallServiceDelegate (Android ServiceCallingActivity Parity)
    
    func deleteListenerAndLeaveChannel() {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallViewModel", message: "deleteListenerAndLeaveChannel() delegate called")
        
        DispatchQueue.main.async {
            self.callStatus = "Call Ended"
            self.onDismiss?()
        }
    }
    
    func updateTimer(_ timeString: String) {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallViewModel", message: "updateTimer() timer updated: \(timeString)")
        
        DispatchQueue.main.async {
            self.callDuration = timeString
        }
    }
    
    func leaveChannel() {
        AppLogger.log(tag: "LOG-APP: MakeAudioCallViewModel", message: "leaveChannel() delegate called")
        
        DispatchQueue.main.async {
            self.callStatus = "Call Ended"
            self.onDismiss?()
        }
    }
} 