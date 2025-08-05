import SwiftUI
import FirebaseFirestore
import AVFoundation

struct IncomingVideoCallAnswerView: View {
    @StateObject private var viewModel = IncomingVideoCallAnswerViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Call Information Section
            VStack(spacing: 20) {
                // Caller Name
                Text(viewModel.callerName)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                // Video Call Label with Icon
                HStack(spacing: 10) {
                    Image("video-70")
                        .foregroundColor(Color("ButtonColor"))
                        .frame(width: 20, height: 20)
                    
                    Text("Video Call")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // Control Buttons
            HStack(spacing: 60) {
                // End Call Button
                Button(action: {
                    AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerView", message: "rejectCall() tapped")
                    viewModel.rejectCall {
                        dismiss()
                    }
                }) {
                    Text("End Call")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 136.67, height: 50)
                .background(Color(red: 1.0, green: 0.219, blue: 0.286))
                .cornerRadius(8)
                
                // Answer Call Button
                Button(action: {
                    AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerView", message: "answerCall() tapped")
                    viewModel.answerCall()
                }) {
                    Text("Answer Call")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 136.33, height: 50)
                .background(Color.green)
                .cornerRadius(8)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
        .background(Color("Background Color"))
        .navigationBarHidden(true)
        .statusBarHidden()
        .onAppear {
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerView", message: "onAppear() setting up incoming video call")
            viewModel.setupIncomingCall()
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerView", message: "onDisappear() cleaning up")
            viewModel.cleanup()
        }
        .background(
            NavigationLink(
                destination: IncomingVideoCallView(),
                isActive: $viewModel.showIncomingVideoCallView
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
}

// MARK: - ViewModel (Android Parity - Using Background Service)
@objc(IncomingVideoCallAnswerViewModel)
class IncomingVideoCallAnswerViewModel: NSObject, ObservableObject, IncomingVideoCallServiceDelegate {
    @Published var callerName = "Unknown"
    @Published var showIncomingVideoCallView = false
    @Published var callLifted = false
    
    private var userId: String = ""
    private var otherUserId: String = ""
    private var channelName: String = ""
    
    // Android parity: Use background service instead of direct implementation
    private let incomingVideoCallService = IncomingVideoCallService.shared
    
    override init() {
        super.init()
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "init() initializing incoming video call answer")
        loadUserSession()
        
        // Android parity: Set service delegate
        incomingVideoCallService.delegate = self
    }
    
    private func loadUserSession() {
        let sessionManager = SessionManager.shared
        userId = sessionManager.userId ?? ""
        
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "loadUserSession() User session loaded for userId: \(userId)")
    }
    
    private func loadIncomingCallData() {
        let incomingCallManager = IncomingCallManager.shared
        
        if incomingCallManager.hasIncomingCall() {
            let incomingCallData = incomingCallManager.getIncomingCallData()
            callerName = incomingCallData.callerName
            otherUserId = incomingCallData.callerId
            channelName = incomingCallData.channelName
            
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "loadIncomingCallData() callerName: \(callerName), otherUserId: \(otherUserId), channel: \(channelName)")
        } else {
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "loadIncomingCallData() no incoming call data found")
        }
    }
    
    func setupIncomingCall() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "setupIncomingCall() starting video call setup")
        
        loadIncomingCallData()
        
        // Android parity: Start background service
        incomingVideoCallService.startService(
            callerUid: otherUserId,
            callerName: callerName,
            channelName: channelName
        )
    }
    
    func answerCall() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "answerCall() answering incoming video call")
        
        // Android parity: Use service to answer call
        incomingVideoCallService.answerCall()
    }
    
    func rejectCall(completion: @escaping () -> Void) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "rejectCall() rejecting video call")
        
        // Android parity: Use service to reject call
        incomingVideoCallService.rejectCall()
        
        completion()
    }
    
    func cleanup() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "cleanup() cleaning up")
        
        // Android parity: Stop service
        incomingVideoCallService.stopService()
    }
    
    // MARK: - IncomingVideoCallServiceDelegate (Android ServiceCallingActivity Parity)
    
    func deleteListenerAndLeaveChannel() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "deleteListenerAndLeaveChannel() delegate called")
        
        DispatchQueue.main.async {
            // Return to main app
            NavigationManager.shared.navigateToMainApp()
        }
    }
    
    func updateTimer(_ timeString: String) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "updateTimer() timer updated: \(timeString)")
        // Timer updates handled by service
    }
    
    func setCallLiftedView(lifted: Bool) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "setCallLiftedView() lifted: \(lifted)")
        
        DispatchQueue.main.async {
            self.callLifted = lifted
            if lifted {
                // Show the IncomingVideoCallView
                self.showIncomingVideoCallView = true
            }
        }
    }
    
    func setupRemoteVideo(uid: UInt) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "setupRemoteVideo() uid: \(uid)")
        // Handled by IncomingVideoCallView
    }
    
    func removeRemoteVideo(uid: UInt) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "removeRemoteVideo() uid: \(uid)")
        // Handled by IncomingVideoCallView
    }
    
    func setupVideoConfig() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "setupVideoConfig() called")
        // Handled by service
    }
    
    func setupLocalVideo() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "setupLocalVideo() called")
        // Handled by service
    }
    
    func leaveChannel() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallAnswerViewModel", message: "leaveChannel() called")
        
        DispatchQueue.main.async {
            // Return to main app
            NavigationManager.shared.navigateToMainApp()
        }
    }
}

// REMOVED: Duplicate VAdEnhancerBannerAdViewRepresentable - using the one from Shared/VAdEnhancerBannerAdViewRepresentable.swift

// REMOVED: VAdEnhancerMrecAdViewRepresentable - now using shared version from Shared/VAdEnhancerMrecAdViewRepresentable.swift

#Preview {
    IncomingVideoCallAnswerView()
} 