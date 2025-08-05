import SwiftUI
import AgoraRtcKit
import FirebaseFirestore

// MARK: - UIViewWrapper
struct UIViewWrapper: UIViewRepresentable {
    let view: UIView
    
    func makeUIView(context: Context) -> UIView {
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

struct IncomingVideoCallView: View {
    @StateObject private var viewModel = IncomingVideoCallViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // Caller information from Core Data or passed parameters
    @State private var profileImageUrl: String = ""
    @State private var callerGender: String = "Male"
    @State private var callerName: String = "Unknown"
    @State private var callAnswered: Bool = false
    @State private var localVideoOffset = CGSize.zero
    @State private var localVideoView: UIView?
    
    var body: some View {
        ZStack {
            Color("Background Color")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section with caller info
                VStack(spacing: 16) {
                    // Caller's profile image
                    AsyncImage(url: URL(string: profileImageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(callerGender == "Male" ? "male" : "female")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    
                    VStack(spacing: 8) {
                        Text(callerName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Incoming Video Call")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Local video preview (for answered call)
                if callAnswered {
                    ZStack {
                        // Remote video background
                        Color.black
                            .ignoresSafeArea()
                        
                        // Local video preview (floating)
                        VStack {
                            HStack {
                                Spacer()
                                if let localView = localVideoView {
                                    UIViewWrapper(view: localView)
                                        .frame(width: 120, height: 160)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                        .offset(localVideoOffset)
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    localVideoOffset = CGSize(
                                                        width: value.translation.width,
                                                        height: value.translation.height
                                                    )
                                                }
                                                .onEnded { value in
                                                    snapToEdge()
                                                }
                                        )
                                }
                            }
                            Spacer()
                        }
                        .padding(20)
                    }
                }
                
                // Control buttons
                HStack(spacing: 60) {
                    // Decline Button
                    Button(action: {
                        declineCall()
                    }) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    
                    // Accept Button
                    Button(action: {
                        acceptCall()
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            loadIncomingCallData()
        }
    }
    
    // MARK: - Helper Methods
    private func loadIncomingCallData() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallView", message: "loadIncomingCallData() loading call information from IncomingCallManager")
        
        let incomingCallManager = IncomingCallManager.shared
        let callData = incomingCallManager.getIncomingCallData()
        
        callerName = callData.callerName.isEmpty ? "Unknown" : callData.callerName
        // Note: profileImageUrl and callerGender not available in IncomingCallManager
        // Using default values for now
        profileImageUrl = ""
        callerGender = "Male"
        
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallView", message: "loadIncomingCallData() caller: \(callerName)")
    }
    
    private func acceptCall() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallView", message: "acceptCall() accepting incoming call")
        callAnswered = true
        viewModel.startCall()
        
        // Initialize local video view
        if let agoraLocalView = viewModel.localVideo?.view {
            localVideoView = agoraLocalView
        }
    }
    
    private func declineCall() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallView", message: "declineCall() declining incoming call")
        viewModel.endCall {
            dismiss()
        }
    }
    
    private func snapToEdge() {
        let screenWidth = UIScreen.main.bounds.width
        let currentX = localVideoOffset.width
        
        // Snap to left or right side
        withAnimation(.spring()) {
            if currentX >= 0 {
                localVideoOffset = CGSize(width: screenWidth / 2 - 100, height: localVideoOffset.height)
            } else {
                localVideoOffset = CGSize(width: -screenWidth / 2 + 100, height: localVideoOffset.height)
            }
        }
        
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallView", message: "snapToEdge() snapped to offset: \(localVideoOffset)")
    }
}

// MARK: - ViewModel
@objc(IncomingVideoCallViewModel)
class IncomingVideoCallViewModel: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var callDuration = 0
    @Published var isMuted = false
    @Published var isVideoMuted = false
    @Published var localVideoOffset = CGSize.zero
    
    // Agora
    private var agoraKit: AgoraRtcEngineKit?
    var localVideo: AgoraRtcVideoCanvas?
    var remoteVideo: AgoraRtcVideoCanvas?
    
    // User & Call Data
    private var userId: String = ""
    private var userName: String = ""
    private var deviceId: String = ""
    private var otherUserId: String = ""
    private var channelName: String = ""
    
    private var isRemoteVideoRender = true
    private var isLocalVideoRender = false
    private var isStartCalling = true
    
    override init() {
        super.init()
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "init() initializing video call")
        loadSessionData()
    }
    
    private func loadSessionData() {
        loadUserData()
        
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "loadSessionData() userId: \(userId), deviceId: \(deviceId)")
        
        // Update video call statistics
        let params: [String: Any] = ["video_calls": FieldValue.increment(Int64(1))]
        Firestore.firestore().collection("UserDevData").document(deviceId).setData(params, merge: true)
        
        // Load incoming call data from Core Data
        loadIncomingCallData()
    }
    
    private func loadUserData() {
        let sessionManager = SessionManager.shared
        userId = sessionManager.userId ?? ""
        userName = sessionManager.userName ?? ""
        deviceId = sessionManager.deviceId ?? ""
    }
    
    private func loadIncomingCallData() {
        let incomingCallManager = IncomingCallManager.shared
        let callData = incomingCallManager.getIncomingCallData()
        
        channelName = callData.channelName
        otherUserId = callData.callerId
        
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "loadIncomingCallData() channelName: \(channelName), otherUserId: \(otherUserId)")
    }
    
    func startCall() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "startCall() beginning Agora setup")
        
        initializeAgoraEngine()
        setupVideo()
        setupLocalVideo()
        joinChannel()
    }
    
    private func initializeAgoraEngine() {
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: "8173040ab4524a64a1051a44026b9677", delegate: self)
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "initializeAgoraEngine() Agora engine initialized")
    }
    
    private func setupVideo() {
        agoraKit?.enableVideo()
        let config = AgoraVideoEncoderConfiguration(
            size: AgoraVideoDimension640x360,
            frameRate: .fps15,
            bitrate: AgoraVideoBitrateStandard,
            orientationMode: .adaptative,
            mirrorMode: .disabled
        )
        agoraKit?.setVideoEncoderConfiguration(config)
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "setupVideo() video configuration set")
    }
    
    private func setupLocalVideo() {
        localVideo = AgoraRtcVideoCanvas()
        localVideo?.renderMode = .hidden
        localVideo?.uid = 0
        agoraKit?.setupLocalVideo(localVideo)
        agoraKit?.startPreview()
        isLocalVideoRender = true
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "setupLocalVideo() local video preview started")
    }
    
    private func joinChannel() {
        agoraKit?.setDefaultAudioRouteToSpeakerphone(true)
        
        let uid = UInt(userId) ?? 0
        agoraKit?.joinChannel(byToken: nil, channelId: channelName, info: nil, uid: uid) { [weak self] (channel, uid, elapsed) in
            DispatchQueue.main.async {
                self?.isLocalVideoRender = true
                AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "joinChannel() successfully joined channel: \(channel)")
            }
        }
        
        isStartCalling = true
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    func toggleMute() {
        isMuted.toggle()
        agoraKit?.muteLocalAudioStream(isMuted)
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "toggleMute() muted: \(isMuted)")
    }
    
    func toggleVideo() {
        isVideoMuted.toggle()
        agoraKit?.muteLocalVideoStream(isVideoMuted)
        isLocalVideoRender = !isVideoMuted
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "toggleVideo() video muted: \(isVideoMuted)")
    }
    
    func switchCamera() {
        agoraKit?.switchCamera()
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "switchCamera() camera switched")
    }
    
    func switchVideoViews() {
        // Swap local and remote video positions
        if let local = localVideo, let remote = remoteVideo {
            let tempCanvas = local
            localVideo = remote
            remoteVideo = tempCanvas
            
            // Update render modes
            localVideo?.renderMode = .hidden
            remoteVideo?.renderMode = .hidden
            
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "switchVideoViews() video views swapped")
        }
    }
    
    func updateLocalVideoPosition(translation: CGSize) {
        localVideoOffset = translation
    }
    
    func snapLocalVideoToSide() {
        let screenWidth = UIScreen.main.bounds.width
        let currentX = localVideoOffset.width
        
        // Snap to left or right side
        if currentX >= 0 {
            localVideoOffset = CGSize(width: screenWidth / 2 - 100, height: localVideoOffset.height)
        } else {
            localVideoOffset = CGSize(width: -screenWidth / 2 + 100, height: localVideoOffset.height)
        }
        
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "snapLocalVideoToSide() snapped to offset: \(localVideoOffset)")
    }
    
    func endCall(completion: @escaping () -> Void) {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "endCall() ending call and cleaning up")
        
        leaveChannel()
        
        // Show ad popup for non-premium users
        showSubscriptionPopup()
        completion()
    }
    
    private func leaveChannel() {
        agoraKit?.leaveChannel(nil)
        isRemoteVideoRender = false
        isLocalVideoRender = false
        isStartCalling = false
        
        // Update Firebase call status
        let endCallParams: [String: Any] = ["call_ended": true, "incoming_call": false]
        
        Firestore.firestore().collection("Users").document(userId).collection("Calls").document("Calls").setData(endCallParams, merge: true)
        Firestore.firestore().collection("Users").document(otherUserId).collection("Calls").document("Calls").setData(endCallParams, merge: true)
        
        UIApplication.shared.isIdleTimerDisabled = false
        
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "leaveChannel() call ended, Firebase updated")
    }
    
    private func showSubscriptionPopup() {
        if !SessionManager.shared.premiumActive {
            // Show subscription popup
        }
    }
    
    func cleanup() {
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "cleanup() clearing incoming call data")
        
        // Clear incoming call data from IncomingCallManager
        let incomingCallManager = IncomingCallManager.shared
        incomingCallManager.clearIncomingCallData()
        
        AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "cleanup() IncomingCallManager cleared")
        
        agoraKit = nil
    }
}

// MARK: - Agora Delegate
extension IncomingVideoCallViewModel: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.isRemoteVideoRender = true
            
            if self?.remoteVideo != nil { return }
            
            self?.remoteVideo = AgoraRtcVideoCanvas()
            self?.remoteVideo?.renderMode = .hidden
            self?.remoteVideo?.uid = uid
            if let remoteVideo = self?.remoteVideo {
                self?.agoraKit?.setupRemoteVideo(remoteVideo)
            }
            
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "firstRemoteVideoDecodedOfUid() remote video setup for uid: \(uid)")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        DispatchQueue.main.async { [weak self] in
            self?.isRemoteVideoRender = false
            
            if let remoteVideo = self?.remoteVideo, remoteVideo.uid == uid {
                self?.remoteVideo = nil
            }
            
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "didOfflineOfUid() user \(uid) went offline, ending call")
            self?.endCall {}
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted: Bool, byUid: UInt) {
        DispatchQueue.main.async { [weak self] in
            self?.isRemoteVideoRender = !muted
            AppLogger.log(tag: "LOG-APP: IncomingVideoCallViewModel", message: "didVideoMuted() remote video muted: \(muted) by uid: \(byUid)")
        }
    }
}

#Preview {
    IncomingVideoCallView()
}