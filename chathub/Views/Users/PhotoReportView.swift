import SwiftUI
import FirebaseFirestore

/**
 * PhotoReportView
 * 
 * A comprehensive popup dialog for reporting inappropriate images.
 * Features multiple report categories, rate limiting, and Firebase integration.
 * 
 * Key Features:
 * - Multiple report reasons (harmful, sexual, violent, etc.)
 * - Rate limiting to prevent spam reporting
 * - Integration with Firebase for report tracking
 * - Toast notifications for user feedback
 * - Automatic image deletion after threshold is reached
 * 
 * This implementation maintains Android parity for the image reporting flow.
 */

struct PhotoReportView: View {
    let imageUrl: String
    let imageUserId: String
    @Binding var isPresented: Bool
    var onReportCompleted: (() -> Void)? = nil
    
    // Report reason states - Android Parity (8 checkboxes)
    @State private var sexual = false        // checkbox1 - Sexual content
    @State private var violent = false       // checkbox2 - Violent or repusive content
    @State private var hateful = false       // checkbox3 - Hatefull or abusive content
    @State private var harmful = false       // checkbox4 - Harmfull dangerous acts
    @State private var childAbuse = false    // checkbox5 - Child abuse
    @State private var infringes = false     // checkbox6 - Infringes my rights
    @State private var terrorism = false     // checkbox7 - Promotes terrorism
    @State private var spam = false          // checkbox8 - Spam or missleading
    
    // Loading and user session
    @State private var isLoading = false
    @State private var userId: String = ""
    @State private var imageDeviceId: String = ""
    @State private var imageName: String = ""
    
    // UI feedback
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay - adapts to theme
            Color("dark").opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            VStack(spacing: 0) {
                // Main Content Card
                VStack(spacing: 0) {
                    // Header Section - Android Parity
                    VStack(spacing: 10) {
                        // Title - matching Android exactly
                        Text("Report photo")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color("Red1")) // Theme-aware red
                            .multilineTextAlignment(.center)
                            .padding(.top, 24)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)
                    
                    // Report Checkboxes Section - Android Parity
                    VStack(alignment: .leading, spacing: 12) {
                        // Sexual Content (checkbox1 in Android)
                        CheckboxReportReason(
                            title: "Sexual content",
                            isSelected: $sexual
                        ) {
                            AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "Sexual checkbox tapped: \(sexual)")
                        }
                        
                        // Violent or repulsive content (checkbox2 in Android)
                        CheckboxReportReason(
                            title: "Violent or repusive content",
                            isSelected: $violent
                        ) {
                            AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "Violent checkbox tapped: \(violent)")
                        }
                        
                        // Hateful or abusive content (checkbox3 in Android)
                        CheckboxReportReason(
                            title: "Hatefull or abusive content",
                            isSelected: $hateful
                        ) {
                            AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "Hateful checkbox tapped: \(hateful)")
                        }
                        
                        // Harmful dangerous acts (checkbox4 in Android)
                        CheckboxReportReason(
                            title: "Harmfull dangerous acts",
                            isSelected: $harmful
                        ) {
                            AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "Harmful checkbox tapped: \(harmful)")
                        }
                        
                        // Child Abuse (checkbox5 in Android)
                        CheckboxReportReason(
                            title: "Child abuse",
                            isSelected: $childAbuse
                        ) {
                            AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "Child abuse checkbox tapped: \(childAbuse)")
                        }
                        
                        // Infringes my rights (checkbox6 in Android)
                        CheckboxReportReason(
                            title: "Infringes my rights",
                            isSelected: $infringes
                        ) {
                            AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "Infringes checkbox tapped: \(infringes)")
                        }
                        
                        // Promotes Terrorism (checkbox7 in Android)
                        CheckboxReportReason(
                            title: "Promotes terrorism",
                            isSelected: $terrorism
                        ) {
                            AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "Promotes checkbox tapped: \(terrorism)")
                        }
                        
                        // Spam or misleading (checkbox8 in Android)
                        CheckboxReportReason(
                            title: "Spam or missleading",
                            isSelected: $spam
                        ) {
                            AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "Spam checkbox tapped: \(spam)")
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer().frame(height: 20) // Android spacing
                    
                    // Report Button - Android Parity
                    Button(action: {
                        reportImage()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color("bright"))) // Theme-aware spinner
                                    .scaleEffect(0.8)
                            }
                            Text("REPORT")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color("bright")) // Theme-aware button text
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color("Red1")) // Theme-aware red button
                        .cornerRadius(8) // Android corner radius
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .background(Color("Background Color")) // Theme-aware background
                .cornerRadius(15)
                .shadow(color: Color("dark").opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadImageData()
        }
        .overlay(
            // Toast notification
            Group {
                if showToast {
                    VStack {
                        Spacer()
                        HStack {
                            Text(toastMessage)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("bright")) // Theme-aware text
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color("dark").opacity(0.9)) // Theme-aware background
                                .cornerRadius(25)
                        }
                        .padding(.bottom, 50)
                    }
                    .transition(.opacity)
                }
            }
        )
    }
    
    // MARK: - Helper Functions
    
    private func loadImageData() {
        loadUserSession()
        imageName = imageUrl.replacingOccurrences(of: "https://strangerchatuser.s3.amazonaws.com/user/\(imageUserId)/", with: "")
        
        AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "loadImageData() userId: \(userId), imageName: \(imageName)")
    }
    
    private func loadUserSession() {
        let sessionManager = SessionManager.shared
        userId = sessionManager.userId ?? ""
        
        AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "loadUserSession() User session loaded for: \(userId)")
    }
    
    private func reportImage() {
        AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "reportImage() attempting to report image using ReportPhotoService: \(imageName)")
        
        guard !imageUrl.isEmpty, !imageUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "reportImage() imageUrl or imageUserId is empty")
            return
        }
        
        // Build reason from selected checkboxes
        let reasons = buildReportReasons()
        let reasonString = reasons.isEmpty ? "Inappropriate content" : reasons.joined(separator: ", ")
        
        isLoading = true
        
        // Use ReportPhotoService instead of complex Firebase logic
        ReportPhotoService.shared.reportPhoto(
            imageUrl: imageUrl,
            otherUserId: imageUserId,
            reason: reasonString
        ) { success in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "reportImage() ReportPhotoService completed successfully")
                    
                    // ANDROID PARITY: Refresh reports data after successful photo report (like Android GetReportsWorker)
                    GetReportsService.shared.refreshReportsData()
                    
                    self.showToastMessage("Reported")
                    self.onReportCompleted?()
                    self.dismissAfterDelay()
                } else {
                    AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "reportImage() ReportPhotoService failed")
                    self.showToastMessage("Report failed")
                }
            }
        }
    }
    
    /// Build report reasons from selected checkboxes - Android parity
    private func buildReportReasons() -> [String] {
        var reasons: [String] = []
        
        if sexual { reasons.append("Sexual content") }
        if violent { reasons.append("Violence") }
        if hateful { reasons.append("Hate speech") }
        if harmful { reasons.append("Harmful content") }
        if childAbuse { reasons.append("Child abuse") }
        if infringes { reasons.append("Copyright infringement") }
        if terrorism { reasons.append("Promotes terrorism") }
        if spam { reasons.append("Spam") }
        
        return reasons
    }
    
    // Removed old reportUser method - now using ReportPhotoService.shared.reportPhoto() directly
    
    // All complex Firebase reporting methods removed - now using ReportPhotoService.shared.reportPhoto() which handles everything internally
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showToast = false
            }
        }
    }
    
    private func dismissAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismissPopup()
        }
    }
    
    private func dismissPopup() {
        AppLogger.log(tag: "LOG-APP: PhotoReportView", message: "dismissPopup() closing photo report popup")
        isPresented = false
    }
}

// MARK: - CheckboxReportReason Component (Android Parity)
struct CheckboxReportReason: View {
    let title: String
    @Binding var isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            isSelected.toggle()
            action()
        }) {
            HStack(spacing: 12) {
                // Checkbox - theme-aware colors
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? Color("Red1") : Color("shade6")) // Red when selected, gray when not
                
                // Title - theme-aware text color
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color("dark")) // Adapts to light/dark theme
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct PhotoReportView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoReportView(
            imageUrl: "https://strangerchatuser.s3.amazonaws.com/user/sample_user_id/sample_image.jpg",
            imageUserId: "sample_user_id",
            isPresented: .constant(true)
        )
    }
} 