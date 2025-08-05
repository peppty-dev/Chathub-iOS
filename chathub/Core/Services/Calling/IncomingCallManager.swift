import Foundation

/// IncomingCallManager handles incoming call data using UserDefaults storage
/// Replaces Incomingcall CoreData entity with Android SessionManager parity
class IncomingCallManager {
    static let shared = IncomingCallManager()
    private let sessionManager = SessionManager.shared
    private let messagingSettingsManager = MessagingSettingsSessionManager.shared
    
    private init() {}
    
    // MARK: - Keys (Android Parity)
    private enum Keys {
        static let inCall = "incoming_call_in_call"
        static let channelName = "incoming_call_channel_name"
        static let callerName = "incoming_call_caller_name"
        static let callerId = "incoming_call_caller_id"
        static let isAudioCall = "incoming_call_is_audio"
        static let callStartTime = "incoming_call_start_time"
    }
    
    // MARK: - Incoming Call Data Model
    struct IncomingCallData {
        let inCall: Bool
        let channelName: String
        let callerName: String
        let callerId: String
        let isAudioCall: Bool
        let callStartTime: TimeInterval
        
        init(inCall: Bool = false, channelName: String = "", callerName: String = "", callerId: String = "", isAudioCall: Bool = true, callStartTime: TimeInterval = 0) {
            self.inCall = inCall
            self.channelName = channelName
            self.callerName = callerName
            self.callerId = callerId
            self.isAudioCall = isAudioCall
            self.callStartTime = callStartTime
        }
    }
    
    // MARK: - Call Status Management (Android Parity)
    
    /// Get current call status - replaces Incomingcall.incall
    var inCall: Bool {
        get { sessionManager.defaults.bool(forKey: Keys.inCall) }
        set { 
            sessionManager.defaults.set(newValue, forKey: Keys.inCall)
            AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "inCall set to: \(newValue)")
        }
    }
    
    /// Get channel name - replaces Incomingcall.channelname
    var channelName: String {
        get { sessionManager.defaults.string(forKey: Keys.channelName) ?? "" }
        set { 
            sessionManager.defaults.set(newValue, forKey: Keys.channelName)
            AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "channelName set to: \(newValue)")
        }
    }
    
    /// Get caller name - replaces Incomingcall.callername
    var callerName: String {
        get { sessionManager.defaults.string(forKey: Keys.callerName) ?? "" }
        set { 
            sessionManager.defaults.set(newValue, forKey: Keys.callerName)
            AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "callerName set to: \(newValue)")
        }
    }
    
    /// Get caller ID - replaces Incomingcall.callerid
    var callerId: String {
        get { sessionManager.defaults.string(forKey: Keys.callerId) ?? "" }
        set { 
            sessionManager.defaults.set(newValue, forKey: Keys.callerId)
            AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "callerId set to: \(newValue)")
        }
    }
    
    /// Get audio call status - new property for call type
    var isAudioCall: Bool {
        get { sessionManager.defaults.bool(forKey: Keys.isAudioCall, default: true) }
        set { 
            sessionManager.defaults.set(newValue, forKey: Keys.isAudioCall)
            AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "isAudioCall set to: \(newValue)")
        }
    }
    
    /// Get call start time - for call duration tracking
    var callStartTime: TimeInterval {
        get { sessionManager.defaults.double(forKey: Keys.callStartTime) }
        set { 
            sessionManager.defaults.set(newValue, forKey: Keys.callStartTime)
            AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "callStartTime set to: \(newValue)")
        }
    }
    
    // MARK: - Call Operations (Android Parity)
    
    /// Set incoming call data - Android setIncomingCallData() equivalent
    func setIncomingCallData(channelName: String, callerName: String, callerId: String, isAudioCall: Bool = true) {
        AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "setIncomingCallData() setting call from: \(callerName)")
        
        self.inCall = true
        self.channelName = channelName
        self.callerName = callerName
        self.callerId = callerId
        self.isAudioCall = isAudioCall
        self.callStartTime = Date().timeIntervalSince1970
        
        sessionManager.synchronize()
        AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "setIncomingCallData() incoming call data set successfully")
    }
    
    /// Get incoming call data - Android getIncomingCallData() equivalent
    func getIncomingCallData() -> IncomingCallData {
        let data = IncomingCallData(
            inCall: inCall,
            channelName: channelName,
            callerName: callerName,
            callerId: callerId,
            isAudioCall: isAudioCall,
            callStartTime: callStartTime
        )
        
        AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "getIncomingCallData() returning call data for: \(data.callerName)")
        return data
    }
    
    /// Clear incoming call data - Android clearIncomingCallData() equivalent
    func clearIncomingCallData() {
        AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "clearIncomingCallData() clearing call data")
        
        inCall = false
        channelName = ""
        callerName = ""
        callerId = ""
        isAudioCall = true
        callStartTime = 0
        
        sessionManager.synchronize()
        AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "clearIncomingCallData() call data cleared successfully")
    }
    
    /// Check if there's an active incoming call - Android hasIncomingCall() equivalent
    func hasIncomingCall() -> Bool {
        let hasCall = inCall && !channelName.isEmpty && !callerId.isEmpty
        AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "hasIncomingCall() returning: \(hasCall)")
        return hasCall
    }
    
    /// Get call duration in seconds - Android getCallDuration() equivalent
    func getCallDuration() -> Int {
        guard callStartTime > 0 else { return 0 }
        let duration = Int(Date().timeIntervalSince1970 - callStartTime)
        AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "getCallDuration() returning: \(duration) seconds")
        return duration
    }
    
    /// Answer call - Android answerCall() equivalent
    func answerCall() {
        AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "answerCall() call answered")
        // Keep call data but mark as answered by updating messaging settings
        messagingSettingsManager.setIncomingCall(callerId: callerId, callerName: callerName, channelName: channelName)
        messagingSettingsManager.synchronize()
    }
    
    /// Reject call - Android rejectCall() equivalent
    func rejectCall() {
        AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "rejectCall() call rejected")
        clearIncomingCallData()
        messagingSettingsManager.clearIncomingCall()
        messagingSettingsManager.synchronize()
    }
    
    /// End call - Android endCall() equivalent
    func endCall() {
        AppLogger.log(tag: "LOG-APP: IncomingCallManager", message: "endCall() call ended")
        clearIncomingCallData()
        messagingSettingsManager.clearIncomingCall()
        messagingSettingsManager.synchronize()
    }
    
    // MARK: - Utility Methods (Android Parity)
    
    /// Get formatted call duration - Android getFormattedCallDuration() equivalent
    func getFormattedCallDuration() -> String {
        let duration = getCallDuration()
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Check if call is video call - Android isVideoCall() equivalent
    func isVideoCall() -> Bool {
        return !isAudioCall
    }
    
    /// Get call type string - Android getCallType() equivalent
    func getCallType() -> String {
        return isAudioCall ? "audio" : "video"
    }
}

// MARK: - SessionManager Extension for Call Management
extension SessionManager {
    
    /// Get incoming call manager instance - Android getIncomingCallManager() equivalent
    var incomingCallManager: IncomingCallManager {
        return IncomingCallManager.shared
    }
} 