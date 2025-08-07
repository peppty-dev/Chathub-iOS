import SwiftUI
import AgoraRtcKit
import SDWebImageSwiftUI

struct MakeAudioCallView: View {
    // MARK: - Properties
    let otherUserId: String
    let otherUserName: String
    let otherUserProfileImage: String
    let otherUserGender: String
    let chatId: String
    
    @StateObject private var viewModel: MakeAudioCallViewModel
    
    init(otherUserId: String, otherUserName: String, otherUserProfileImage: String, otherUserGender: String, chatId: String) {
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        self.otherUserProfileImage = otherUserProfileImage
        self.otherUserGender = otherUserGender
        self.chatId = chatId
        _viewModel = StateObject(wrappedValue: MakeAudioCallViewModel(otherUserId: otherUserId, otherUserName: otherUserName, channelId: chatId))
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 32) {
            // Profile Image
            if !otherUserProfileImage.isEmpty, let url = URL(string: otherUserProfileImage) {
                WebImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } placeholder: {
                    Image(otherUserGender == "Male" ? "male" : "female")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                }
                .onSuccess { image, data, cacheType in
                    AppLogger.log(tag: "LOG-APP: MakeAudioCallView", message: "call profile image loaded")
                }
                .onFailure { error in
                    AppLogger.log(tag: "LOG-APP: MakeAudioCallView", message: "call profile image failed: \(error.localizedDescription)")
                }
            } else {
                Image(otherUserGender == "Male" ? "male" : "female")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            }
            
            // Name
            Text(otherUserName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.primary)
            
            // Status
            Text(viewModel.callStatus)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.gray)
            
            // Call Controls
            HStack(spacing: 40) {
                // Mute Button
                Button(action: {
                    viewModel.toggleMute()
                }) {
                    Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.isMuted ? .red : Color("blue"))
                }
                
                // End Call Button
                Button(action: {
                    viewModel.showEndCallAlert = true
                }) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .alert(isPresented: $viewModel.showEndCallAlert) {
                    Alert(
                        title: Text("End Call"),
                        message: Text("Are you sure you want to end the call?"),
                        primaryButton: .destructive(Text("End")) {
                            AppLogger.log(tag: "LOG-APP: MakeAudioCallView", message: "endCallTapped() Ending audio call")
                            viewModel.endCall()
                        },
                        secondaryButton: .cancel()
                    )
                }
                
                // Speaker Button
                Button(action: {
                    viewModel.toggleSpeaker()
                }) {
                    Image(systemName: viewModel.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.isSpeakerOn ? Color("blue") : .gray)
                }
            }
            .padding(.top, 32)
            
            Spacer()
        }
        .padding()
        .background(Color("Background Color").ignoresSafeArea())
        .onAppear {
            AppLogger.log(tag: "LOG-APP: MakeAudioCallView", message: "onAppear() Audio call screen loaded")
            viewModel.onDismiss = {
                // Handle dismissal
            }
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: MakeAudioCallView", message: "onDisappear() Leaving audio call screen")
            viewModel.endCall()
        }
    }
}

// MARK: - Preview
struct MakeAudioCallView_Previews: PreviewProvider {
    static var previews: some View {
        MakeAudioCallView(
            otherUserId: "user123",
            otherUserName: "John Doe",
            otherUserProfileImage: "",
            otherUserGender: "Male",
            chatId: "chat_abc"
        )
    }
} 