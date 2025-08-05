import SwiftUI
import FirebaseFirestore
import UIKit

struct PhotoViewerView: View {
    let imageUrl: String
    let imageUserId: String
    let imageType: String // "profilemale", "profilefemale", or other types
    @Environment(\.dismiss) private var dismiss
    
    // State for photo reporting and options
    @State private var showPhotoReport = false
    @State private var showImageWarning = true
    @State private var warningClickCount = 0
    @State private var imageLoaded = false
    
    // Zoom and pan state
    @State private var currentZoom = 0.0
    @State private var totalZoom = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // User session data
    @State private var currentUserId: String = ""
    @State private var currentUserName: String = ""
    @State private var currentUserDeviceId: String = ""
    @State private var currentUserGender: String = ""
    @State private var currentUserProfilePhoto: String = ""
    
    @ViewBuilder
    private func imageContentView() -> some View {
        if imageLoaded {
            let baseImage = AsyncImage(url: URL(string: imageUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .frame(width: 50, height: 50)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "photo loaded successfully")
                        }
                case .failure(let error):
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .foregroundColor(.gray)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "photo loading failed: \(error.localizedDescription)")
                        }
                @unknown default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            baseImage
                .scaleEffect(currentZoom + totalZoom)
                .offset(offset)
                .clipped()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            currentZoom = value - 1
                        }
                        .onEnded { value in
                            totalZoom += currentZoom
                            currentZoom = 0
                            // Reset zoom if it goes below 1
                            if totalZoom < 1 {
                                totalZoom = 1
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                        .simultaneously(
                            with: DragGesture()
                                .onChanged { value in
                                    let newOffset = CGSize(
                                        width: value.translation.width + lastOffset.width,
                                        height: value.translation.height + lastOffset.height
                                    )
                                    offset = newOffset
                                }
                                .onEnded { value in
                                    lastOffset = offset
                                }
                        )
                )
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Image("loading")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var body: some View {
        ZStack {
            // Background color matching 
            Color("Background Color")
                .ignoresSafeArea()
            
            // Main image display (full screen with safe area constraints)
            VStack {
                Spacer().frame(height: 10) // Top padding matching 
                
                imageContentView()
                
                Spacer().frame(height: 10) // Bottom padding matching 
            }
            
            // Image Warning Dialog (Android Parity)
            if showImageWarning {
                PhotoImageWarningView(
                    onOpenImage: handleOpenImageTap,
                    onDismiss: { showImageWarning = false },
                    clickCount: warningClickCount
                )
            }
            
            // Photo Report Dialog
            if showPhotoReport {
                PhotoReportView(
                    imageUrl: imageUrl,
                    imageUserId: imageUserId,
                    isPresented: $showPhotoReport
                ) {
                    AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "Photo report completed successfully")
                }
            }
        }
        .navigationTitle("Photo")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Report") {
                    AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "Report button tapped")
                    showPhotoReport = true
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color("ButtonColor"))
            }
        }
        .onAppear {
            loadCurrentUserData()
            checkIfImageReported()
            enableScreenProtection()
            // Reset warning click count when view appears
            warningClickCount = 0
        }
        .onDisappear {
            disableScreenProtection()
        }

    }
    
    // MARK: - Helper Functions
    
    private func loadCurrentUserData() {
        let sessionManager = SessionManager.shared
        currentUserId = sessionManager.userId ?? ""
        currentUserName = sessionManager.userName ?? ""
        currentUserDeviceId = sessionManager.deviceId ?? ""
        currentUserGender = sessionManager.userGender ?? ""
        currentUserProfilePhoto = sessionManager.userProfilePhoto ?? ""
        
        AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "loadCurrentUserData() loaded user data for: \(currentUserId)")
    }
    
    private func checkIfImageReported() {
        AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "checkIfImageReported() checking using ReportPhotoService")
        
        // Use ReportPhotoService to check if image was already reported
        ReportPhotoService.shared.getReportStatus(imageUrl: imageUrl) { [self] exists in
            DispatchQueue.main.async {
                if exists {
                    AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "checkIfImageReported() image already reported via ReportPhotoService, hiding")
                    // Image is already reported, don't show it
                    self.showImageWarning = false
                    self.imageLoaded = false
                } else {
                    AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "checkIfImageReported() image not reported, showing warning")
                    // Show warning dialog first (Android parity)
                    self.showImageWarning = true
                }
            }
        }
    }
    
    private func handleOpenImageTap() {
        AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "handleOpenImageTap() called - current count: \(warningClickCount)")
        warningClickCount += 1
        AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "handleOpenImageTap() incremented count to: \(warningClickCount)")
        
        if warningClickCount >= 2 {
            // After 2 clicks, load the image and dismiss warning (Android parity)
            AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "handleOpenImageTap() 2 clicks reached - loading image")
            showImageWarning = false
            imageLoaded = true
            sendImageViewNotification()
        } else {
            AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "handleOpenImageTap() need \(2 - warningClickCount) more clicks")
        }
    }
    

    
    private func enableScreenProtection() {
        // Prevent screenshots and screen recording (Android FLAG_SECURE equivalent)
        AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "enableScreenProtection() enabling screen protection")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            // Add a protection overlay to prevent screenshots
            let protectionView = UIView()
            protectionView.backgroundColor = UIColor.clear
            protectionView.isUserInteractionEnabled = false // CRITICAL: Don't block touch events
            protectionView.tag = 9999 // Unique tag for identification
            window.addSubview(protectionView)
            protectionView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                protectionView.topAnchor.constraint(equalTo: window.topAnchor),
                protectionView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                protectionView.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                protectionView.bottomAnchor.constraint(equalTo: window.bottomAnchor)
            ])
        }
    }
    
    private func disableScreenProtection() {
        // Remove screen protection (Android FLAG_SECURE equivalent)
        AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "disableScreenProtection() disabling screen protection")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            // Remove the protection overlay
            window.subviews.forEach { view in
                if view.tag == 9999 {
                    view.removeFromSuperview()
                }
            }
        }
    }
    
    private func sendImageViewNotification() {
        // Only send notification if viewing someone else's image (matching UIKit logic)
        guard !imageUserId.isEmpty, imageUserId != currentUserId else {
            AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "sendImageViewNotification() skipping - viewing own image or empty userId")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "sendImageViewNotification() sending notification to user: \(imageUserId)")
        
        let unixTime = Int64(Date().timeIntervalSince1970)
        let parameters: [String: Any] = [
            "notif_sender_name": currentUserName,
            "notif_sender_id": currentUserId,
            "notif_sender_gender": currentUserGender,
            "notif_sender_image": currentUserProfilePhoto,
            "notif_token": currentUserDeviceId,
            "notif_other_id": imageUserId,
            "notif_time": unixTime,
            "notif_type": "image"
        ]
        
        let db = Firestore.firestore()
        db.collection("Notifications")
            .document(imageUserId)
            .collection("Notifications")
            .document(String(unixTime))
            .setData(parameters, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "sendImageViewNotification() error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: PhotoViewerView", message: "sendImageViewNotification() notification sent successfully")
                }
            }
    }
}



// MARK: - Preview
struct PhotoViewerView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoViewerView(
            imageUrl: "https://strangerchatuser.s3.amazonaws.com/user/sample_user_id/sample_image.jpg",
            imageUserId: "sample_user_id",
            imageType: "profilemale"
        )
    }
} 