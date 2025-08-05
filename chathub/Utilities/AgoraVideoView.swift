import SwiftUI
import UIKit

// MARK: - UIKit Video View Bridge
struct AgoraVideoView: UIViewRepresentable {
    let viewModel: MakeVideoCallViewModel
    let isLocal: Bool
    
    func makeUIView(context: Context) -> UIView {
        if isLocal {
            return viewModel.setupLocalVideo() ?? UIView()
        } else if let uid = viewModel.remoteVideoUid {
            return viewModel.setupRemoteVideo(uid: uid) ?? UIView()
        }
        return UIView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Video views are managed by Agora SDK
    }
} 