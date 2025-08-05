import SwiftUI
import FirebaseFirestore

struct UpdateView: View {
    @State private var updateContent: String = ""
    @State private var isMandatory: Bool = true
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App Icon
            Image("app_icon") // Assuming you have an app icon in assets
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color("shade2").opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Title
            Text("Update Available")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.center)
            
            // Update Content
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    Text("Loading update information...")
                        .font(.body)
                        .foregroundColor(Color("shade6"))
                }
                .frame(maxHeight: 200)
                
            } else if let errorMessage = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(Color("Red1"))
                    Text("Unable to load update information")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("dark"))
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(Color("shade6"))
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: 200)
                
            } else {
                ScrollView {
                    Text(updateContent)
                        .font(.body)
                        .foregroundColor(Color("dark"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                }
                .frame(maxHeight: 200)
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 16) {
                // Update Button
                Button(action: {
                    AppLogger.log(tag: "LOG-APP: UpdateView", message: "updateButtonTapped() - Opening App Store")
                    openAppStore()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.app.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Update Now")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("ButtonColor"))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Cancel Button (only shown if update is not mandatory)
                if !isMandatory {
                    Button(action: {
                        AppLogger.log(tag: "LOG-APP: UpdateView", message: "cancelButtonTapped() - Update dismissed")
                        dismiss()
                    }) {
                        Text("Later")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("shade6"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                                                         .background(
                                 RoundedRectangle(cornerRadius: 12)
                                     .fill(Color("Background Color"))
                             )
                             .overlay(
                                 RoundedRectangle(cornerRadius: 12)
                                     .stroke(Color("shade3"), lineWidth: 1)
                             )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background Color"))
        .onAppear {
            AppLogger.log(tag: "LOG-APP: UpdateView", message: "onAppear() - Update view appeared")
            fetchUpdateInformation()
        }
        .interactiveDismissDisabled(isMandatory) // Prevent swipe-to-dismiss if mandatory
    }
    
    private func fetchUpdateInformation() {
        AppLogger.log(tag: "LOG-APP: UpdateView", message: "fetchUpdateInformation() - Fetching update info from Firebase")
        
        Firestore.firestore().collection("VersionControle").document("LiveAppVersion").getDocument { (document, error) in
            DispatchQueue.main.async {
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: UpdateView", message: "fetchUpdateInformation() - Firebase error: \(error.localizedDescription)")
                    self.errorMessage = "Failed to load update information"
                    self.isLoading = false
                    return
                }
                
                guard let document = document, document.exists else {
                    AppLogger.log(tag: "LOG-APP: UpdateView", message: "fetchUpdateInformation() - Document does not exist")
                    self.errorMessage = "Update information not available"
                    self.isLoading = false
                    return
                }
                
                guard let data = document.data() else {
                    AppLogger.log(tag: "LOG-APP: UpdateView", message: "fetchUpdateInformation() - No data in document")
                    self.errorMessage = "Update information not available"
                    self.isLoading = false
                    return
                }
                
                let updateMandatory = data["ios_update_mandatory"] as? Bool ?? true
                let updateDetails = data["ios_update_details"] as? String ?? "A new version of the app is available. Please update to continue using the app."
                
                AppLogger.log(tag: "LOG-APP: UpdateView", message: "fetchUpdateInformation() - Update mandatory: \(updateMandatory), details: \(updateDetails)")
                
                self.isMandatory = updateMandatory
                self.updateContent = updateDetails
                self.isLoading = false
            }
        }
    }
    
    private func openAppStore() {
        let appStoreURL = "https://apps.apple.com/us/app/chathub-stranger-chat-app/id1539272301"
        
        guard let url = URL(string: appStoreURL) else {
            AppLogger.log(tag: "LOG-APP: UpdateView", message: "openAppStore() - Invalid App Store URL")
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                AppLogger.log(tag: "LOG-APP: UpdateView", message: "openAppStore() - App Store opened successfully: \(success)")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: UpdateView", message: "openAppStore() - Cannot open App Store URL")
        }
    }
}

#Preview {
    UpdateView()
} 