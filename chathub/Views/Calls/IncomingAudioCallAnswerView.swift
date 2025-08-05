import SwiftUI
import FirebaseFirestore
import AVFoundation

struct IncomingAudioCallAnswerView: View {
    @StateObject private var viewModel = IncomingAudioCallAnswerViewModel()
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
                
                // Audio Call Label with Icon
                HStack(spacing: 10) {
                    Image("call-70")
                        .foregroundColor(Color("ButtonColor"))
                        .frame(width: 20, height: 20)
                    
                    Text("Audio Call")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // Control Buttons
            HStack(spacing: 60) {
                // End Call Button
                Button(action: {
                    AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerView", message: "rejectCall() tapped")
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
                    AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerView", message: "answerCall() tapped")
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
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerView", message: "onAppear() setting up incoming call")
            viewModel.setupIncomingCall()
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerView", message: "onDisappear() cleaning up")
            viewModel.cleanup()
        }
        .background(
            NavigationLink(
                destination: IncomingAudioCallView(),
                isActive: $viewModel.showIncomingAudioCallView
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
}

// MARK: - ViewModel (Android Parity - Using Background Service)
@objc(IncomingAudioCallAnswerViewModel)
class IncomingAudioCallAnswerViewModel: NSObject, ObservableObject, IncomingAudioCallServiceDelegate {
    @Published var callerName = "Unknown"
    @Published var showIncomingAudioCallView = false
    @Published var callLifted = false
    
    private var userId: String = ""
    private var otherUserId: String = ""
    private var channelName: String = ""
    
    // Android parity: Use background service instead of direct implementation
    private let incomingAudioCallService = IncomingAudioCallService.shared
    
    override init() {
        super.init()
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "init() initializing incoming call answer")
        loadSessionData()
        
        // Android parity: Set service delegate
        incomingAudioCallService.delegate = self
    }
    
    private func loadSessionData() {
        userId = SessionManager.shared.userId ?? ""
        
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "loadSessionData() userId: \(userId)")
        
        // Load incoming call data from Core Data
        loadIncomingCallData()
    }
    
    private func loadIncomingCallData() {
        let incomingCallManager = IncomingCallManager.shared
        
        if incomingCallManager.hasIncomingCall() {
            let incomingCallData = incomingCallManager.getIncomingCallData()
            callerName = incomingCallData.callerName
            otherUserId = incomingCallData.callerId
            channelName = incomingCallData.channelName
            
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "loadIncomingCallData() callerName: \(callerName), otherUserId: \(otherUserId), channel: \(channelName)")
        } else {
            AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "loadIncomingCallData() no incoming call data found")
        }
    }
    
    func setupIncomingCall() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "setupIncomingCall() starting call setup")
        
        // Android parity: Start background service
        incomingAudioCallService.startService(
            callerUid: otherUserId,
            callerName: callerName,
            channelName: channelName
        )
    }
    
    func answerCall() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "answerCall() answering incoming call")
        
        // Android parity: Use service to answer call
        incomingAudioCallService.answerCall()
    }
    
    func rejectCall(completion: @escaping () -> Void) {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "rejectCall() rejecting call")
        
        // Android parity: Use service to reject call
        incomingAudioCallService.rejectCall()
        
        completion()
    }
    
    func cleanup() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "cleanup() cleaning up")
        
        // Android parity: Stop service
        incomingAudioCallService.stopService()
    }
    
    // MARK: - IncomingAudioCallServiceDelegate (Android ServiceCallingActivity Parity)
    
    func deleteListenerAndLeaveChannel() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "deleteListenerAndLeaveChannel() delegate called")
        
        DispatchQueue.main.async {
            // Return to main app
            NavigationManager.shared.navigateToMainApp()
        }
    }
    
    func updateTimer(_ timeString: String) {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "updateTimer() timer updated: \(timeString)")
        // Timer updates handled by service
    }
    
    func setCallLiftedView(lifted: Bool) {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "setCallLiftedView() lifted: \(lifted)")
        
        DispatchQueue.main.async {
            self.callLifted = lifted
            if lifted {
                // Show the IncomingAudioCallView
                self.showIncomingAudioCallView = true
            }
        }
    }
    
    func leaveChannel() {
        AppLogger.log(tag: "LOG-APP: IncomingAudioCallAnswerViewModel", message: "leaveChannel() called")
        
        DispatchQueue.main.async {
            // Return to main app
            NavigationManager.shared.navigateToMainApp()
        }
    }
}

#Preview {
    IncomingAudioCallAnswerView()
} 