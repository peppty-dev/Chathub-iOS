import SwiftUI
import AgoraRtcKit
import FirebaseFirestore
import AVFAudio

// MARK: - IncomingAudioCallViewModel for 100% UIKit Parity
@objc(IncomingAudioCallViewModel)
class IncomingAudioCallViewModel: NSObject, ObservableObject, AgoraRtcEngineDelegate {
    @Published var callerName: String = ""
    @Published var callDuration: String = "00:00"
    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = false
    // Core properties matching UIKit exactly
    private var agoraKit: AgoraRtcEngineKit?
    private let appId = "8173040ab4524a64a1051a44026b9677" // Exact match with UIKit
    private var callTimer: Timer?
    private var callDurationSeconds: Int = 0
    
    // User and call data
    private let currentUserId: String
    private var otherUserId: String = ""
    private var channelName: String = ""
    
    // Firebase
    private let database = Firestore.firestore()
    private var callListener: ListenerRegistration?
    
    // Dismiss callback
    var onDismiss: (() -> Void)?
    
    override init() {
        self.currentUserId = SessionManager.shared.userId ?? ""
        super.init()
        
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "init() Incoming audio call initialized")
        
        loadCallData()
        initializeAgora()
        setupCallListener()
        startCallTimer()
        updateVoiceCallStats()
    }
    
    deinit {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "deinit() Incoming audio call view model deallocated")
        stopCallTimer()
        leaveChannel()
        callListener?.remove()
    }
    
    // MARK: - IncomingCallManager Integration (Replacing Core Data)
    private func loadCallData() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "loadCallData() Loading incoming call data from IncomingCallManager")
        
        let incomingCallManager = IncomingCallManager.shared
        let callData = incomingCallManager.getIncomingCallData()
        
        channelName = callData.channelName
        callerName = callData.callerName.isEmpty ? "Unknown" : callData.callerName
        otherUserId = callData.callerId
        
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "loadCallData() Loaded call data - Caller: \(callerName), Channel: \(channelName)")
    }
    
    private func clearCallData() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "clearCallData() Clearing incoming call data from IncomingCallManager")
        
        let incomingCallManager = IncomingCallManager.shared
        incomingCallManager.clearIncomingCallData()
        
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "clearCallData() Call data cleared successfully")
    }
    
    // MARK: - Agora Integration (Matching UIKit exactly)
    private func initializeAgora() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "initializeAgora() Initializing Agora with App ID: \(appId)")
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: appId, delegate: self)
        
        // Join channel immediately (matching UIKit behavior)
        if !channelName.isEmpty {
            joinChannel()
        }
    }
    
    private func joinChannel() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "joinChannel() Joining audio channel: \(channelName)")
        
        let result = agoraKit?.joinChannel(byToken: nil, channelId: channelName, info: nil, uid: UInt(currentUserId.hashValue))
        if result == 0 {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "joinChannel() Successfully joined channel")
        } else {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "joinChannel() Failed to join channel: \(result ?? -1)")
        }
    }
    
    // MARK: - Call Control Methods (Matching UIKit exactly)
    func toggleMute() {
        isMuted.toggle()
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "toggleMute() Mute toggled: \(isMuted)")
        agoraKit?.muteLocalAudioStream(isMuted)
    }
    
    func toggleSpeaker() {
        isSpeakerOn.toggle()
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "toggleSpeaker() Speaker toggled: \(isSpeakerOn)")
        agoraKit?.setEnableSpeakerphone(isSpeakerOn)
    }
    
    func endCall() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "endCall() Ending incoming audio call")
        leaveChannel()
    }
    
    // MARK: - Timer Management (Matching UIKit exactly)
    private func startCallTimer() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "startCallTimer() Starting call duration timer")
        
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateCallDuration()
        }
    }
    
    private func stopCallTimer() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "stopCallTimer() Stopping call duration timer")
        callTimer?.invalidate()
        callTimer = nil
    }
    
    private func updateCallDuration() {
        callDurationSeconds += 1
        let minutes = callDurationSeconds / 60
        let seconds = callDurationSeconds % 60
        
        let minutesString = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        let secondsString = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        
        DispatchQueue.main.async {
            self.callDuration = "\(minutesString):\(secondsString)"
        }
    }
    
    // MARK: - Firebase Call Management (Matching UIKit exactly)
    private func setupCallListener() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "setupCallListener() Setting up Firebase call listener")
        
        callListener = database.collection("Users").document(currentUserId).collection("Calls").document("Calls")
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else { return }
                
                let data = document.data()
                let callEnded = data?["call_ended"] as? Bool ?? false
                
                if callEnded {
                    AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "setupCallListener() Call ended by other user")
                    DispatchQueue.main.async {
                        self.leaveChannel()
                    }
                }
            }
    }
    
    private func updateFirebaseCallStatus() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "updateFirebaseCallStatus() Updating Firebase call status")
        
        let callEndData: [String: Any] = [
            "call_ended": true,
            "incoming_call": false
        ]
        
        // Update current user's call status
        database.collection("Users").document(currentUserId).collection("Calls").document("Calls").setData(callEndData, merge: true)
        
        // Update other user's call status
        if !otherUserId.isEmpty {
            database.collection("Users").document(otherUserId).collection("Calls").document("Calls").setData(callEndData, merge: true)
        }
    }
    
    // MARK: - Analytics (Matching UIKit exactly)
    private func updateVoiceCallStats() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "updateVoiceCallStats() Updating voice call statistics")
        
        let deviceId = SessionManager.shared.deviceId ?? ""
        if !deviceId.isEmpty {
            let statsData: [String: Any] = ["voice_calls": FieldValue.increment(1.0)]
            database.collection("UserDevData").document(deviceId).setData(statsData, merge: true)
        }
    }
    
    func leaveChannel() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "leaveChannel() Leaving Agora channel and cleaning up")
        
        stopCallTimer()
        callListener?.remove()
        
        agoraKit?.leaveChannel(nil)
        agoraKit = nil
        
        // Re-enable device sleep
        UIApplication.shared.isIdleTimerDisabled = false
        
        // Update Firebase call status
        updateFirebaseCallStatus()
        
        // Clear Core Data
        clearCallData()
        
        DispatchQueue.main.async {
            self.onDismiss?()
        }
    }
    

    
    // MARK: - AgoraRtcEngineDelegate (Matching UIKit exactly)
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "didJoinChannel() Joined audio channel: \(channel) with uid: \(uid)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "didOfflineOfUid() Other user left: \(uid), ending call")
        
        DispatchQueue.main.async {
            self.leaveChannel()
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "didOccurError() Agora error: \(errorCode.rawValue)")
    }
}

// MARK: - IncomingAudioCallView (100% UIKit UIKit Parity)
struct IncomingAudioCallView: View {
    @StateObject private var viewModel = IncomingAudioCallViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background matching 
                Color("Background Color")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Banner Ad Area (matching 
                    VStack {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 50)
                            .padding(.top, 20)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Call Info Section (matching 
                    VStack(spacing: 23) {
                        // Caller Name
                        Text(viewModel.callerName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        
                        // Call Duration
                        Text(viewModel.callDuration)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color("shade8"))
                            .multilineTextAlignment(.center)
                        
                        // Audio Call Icon and Label
                        HStack(spacing: 10) {
                            Image("call-70")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(Color("ButtonColor"))
                            
                            Text("Audio Call")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(Color.primary)
                        }
                    }
                    .padding(.bottom, 40)
                    
                    Spacer()
                    
                    // Control Buttons (Bottom section, matching 
                    VStack {
                        HStack(spacing: 25) { // Match 
                            // Mute Button
                            Button(action: {
                                viewModel.toggleMute()
                            }) {
                                Text("Mute")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(viewModel.isMuted ? Color.white : Color("ButtonColor"))
                                    .frame(width: 101, height: 50) // Exact 
                                    .background(viewModel.isMuted ? Color("blue") : Color("shade2"))
                                    .cornerRadius(8)
                            }
                            
                            // Speaker Button
                            Button(action: {
                                viewModel.toggleSpeaker()
                            }) {
                                Text("Speaker")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(viewModel.isSpeakerOn ? Color.white : Color("ButtonColor"))
                                    .frame(width: 101, height: 50) // Exact 
                                    .background(viewModel.isSpeakerOn ? Color("blue") : Color("shade2"))
                                    .cornerRadius(8)
                            }
                            
                            // End Call Button
                            Button(action: {
                                viewModel.endCall()
                            }) {
                                Text("End Call")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.white)
                                    .frame(width: 101, height: 50) // Exact 
                                    .background(Color("Here")) // Red color matching 
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 20) // Match 
                        .padding(.bottom, 50) // Match 
                    }
                    .frame(height: 88) // Exact 
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "onAppear() Incoming audio call screen appeared")
            
            // Prevent device from sleeping during call
            UIApplication.shared.isIdleTimerDisabled = true
            
            viewModel.onDismiss = {
                dismiss()
            }
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallView", message: "onDisappear() Incoming audio call screen disappeared")
            viewModel.leaveChannel()
        }
    }
}

// MARK: - Preview
struct IncomingAudioCallView_Previews: PreviewProvider {
    static var previews: some View {
        IncomingAudioCallView()
            .preferredColorScheme(.light)
        
        IncomingAudioCallView()
            .preferredColorScheme(.dark)
    }
} 
