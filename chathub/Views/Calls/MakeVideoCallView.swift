import SwiftUI
import AgoraRtcKit
import AVFAudio
import FirebaseFirestore

// MARK: - MakeVideoCallView (100% UIKit/Android Parity)
struct MakeVideoCallView: View {
    let otherUserId: String
    let otherUserName: String
    let otherUserProfileImage: String
    let chatId: String
    
    @StateObject private var viewModel: MakeVideoCallViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFullScreenControls = true
    
    init(otherUserId: String, otherUserName: String, otherUserProfileImage: String, chatId: String) {
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        self.otherUserProfileImage = otherUserProfileImage
        self.chatId = chatId
        
        _viewModel = StateObject(wrappedValue: MakeVideoCallViewModel(
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserProfileImage: otherUserProfileImage,
            channelId: chatId
        ))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background matching 
                Color("TabColor")
                    .ignoresSafeArea()
                
                // Remote Video View (Full Screen)
                ZStack {
                    if viewModel.isRemoteVideoRender, let _ = viewModel.remoteVideoUid {
                        AgoraVideoView(viewModel: viewModel, isLocal: false)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        // Default remote video placeholder
                        Color("TabColor")
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    
                    // Status Bar Background (matching 
                    if showFullScreenControls {
                        VStack {
                            Rectangle()
                                .fill(Color(UIColor.systemBackground))
                                .frame(height: 55)
                                .padding(.top, 60)
                            Spacer()
                        }
                    }
                    
                    // User Info Labels (matching 
                    if showFullScreenControls {
                        VStack {
                            Spacer()
                                .frame(height: 125) // Match 
                            
                            Text(otherUserName)
                                .font(.system(size: 23, weight: .semibold))
                                .foregroundColor(Color("dark"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                            
                            Text(viewModel.callStatus)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color("shade8"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                                .padding(.top, 20)
                            
                            Spacer()
                        }
                    }
                    
                    // Local Video View (Small preview in corner, matching 
                    if viewModel.isLocalVideoRender && viewModel.isCameraOn {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                AgoraVideoView(viewModel: viewModel, isLocal: true)
                                    .frame(width: 120, height: 180) // Exact 
                                    .background(Color("TabColor"))
                                    .cornerRadius(15)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color("shade3"), lineWidth: 1)
                                    )
                                    .padding(.trailing, 25) // Match 
                                    .padding(.bottom, 30) // Above buttons
                                    .gesture(
                                        TapGesture()
                                            .onEnded {
                                                // Handle local video container tap (future enhancement)
                                                AppLogger.log(tag: "LOG-APP: MakeVideoCallView", message: "localVideoTapped() Local video container tapped")
                                            }
                                    )
                            }
                        }
                    }
                }
                .onTapGesture {
                    // Toggle full screen controls (matching Android behavior)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showFullScreenControls.toggle()
                    }
                }
                
                // Control Buttons (Bottom, matching 
                if showFullScreenControls {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 15) { // Match 
                            // Switch Camera Button
                            Button(action: {
                                viewModel.switchCamera()
                            }) {
                                Text("Switch")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(viewModel.isSwitchingCamera ? Color.white : Color("ButtonColor"))
                                    .frame(width: 85, height: 50) // Exact 
                                    .background(viewModel.isSwitchingCamera ? Color("ButtonColor") : Color("shade2"))
                                    .cornerRadius(8)
                            }
                            
                            // Mute Button
                            Button(action: {
                                viewModel.toggleMute()
                            }) {
                                Text("Mute")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(viewModel.isMuted ? Color.white : Color("ButtonColor"))
                                    .frame(width: 84.5, height: 50) // Exact 
                                    .background(viewModel.isMuted ? Color("ButtonColor") : Color("shade2"))
                                    .cornerRadius(8)
                            }
                            
                            // Video Toggle Button
                            Button(action: {
                                viewModel.toggleCamera()
                            }) {
                                Text("Video")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(viewModel.isCameraOn ? Color("ButtonColor") : Color.white)
                                    .frame(width: 85, height: 50) // Exact 
                                    .background(viewModel.isCameraOn ? Color("shade2") : Color("ButtonColor"))
                                    .cornerRadius(8)
                            }
                            
                            // End Call Button
                            Button(action: {
                                viewModel.showEndCallConfirmation = true
                            }) {
                                Text("End")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.white)
                                    .frame(width: 84.5, height: 50) // Exact 
                                    .background(Color("Here")) // Red color matching 
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.bottom, 20) // Match 
                        .padding(.horizontal, 15) // Match 
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear {
            AppLogger.log(tag: "LOG-APP: MakeVideoCallView", message: "Video call screen appeared")
            viewModel.onDismiss = {
                dismiss()
            }
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: MakeVideoCallView", message: "Video call screen disappeared")
            viewModel.leaveChannel()
        }
        .alert("End Call", isPresented: $viewModel.showEndCallConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) {
                viewModel.endCall()
            }
        } message: {
            Text("Are you sure you want to end the call?")
        }
        .gesture(
            // Prevent going back with swipe gesture during call
            DragGesture()
                .onEnded { _ in
                    // Do nothing - prevent back navigation
                }
        )
    }
}

// MARK: - Preview
struct MakeVideoCallView_Previews: PreviewProvider {
    static var previews: some View {
        MakeVideoCallView(
            otherUserId: "user123",
            otherUserName: "Jane Doe",
            otherUserProfileImage: "https://example.com/image.jpg",
            chatId: "video_call_channel_123"
        )
        .preferredColorScheme(.light)
        
        MakeVideoCallView(
            otherUserId: "user456",
            otherUserName: "John Smith",
            otherUserProfileImage: "",
            chatId: "video_call_channel_456"
        )
        .preferredColorScheme(.dark)
    }
}