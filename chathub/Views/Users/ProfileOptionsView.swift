import SwiftUI
import FirebaseFirestore
import AVFoundation

struct ProfileOptionsView: View {
    let otherUserId: String
    let otherUserName: String
    let otherUserDevId: String
    let otherUserGender: String
    let chatId: String
    var onConversationCleared: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    @State private var isMuted: Bool = false
    @State private var allowCalls: Bool = true
    @State private var showReportDialog: Bool = false
    @State private var showDetailedReportDialog: Bool = false

    @State private var showBlockAlert: Bool = false
    @State private var showClearChatAlert: Bool = false
    @State private var showPermissionDialog: Bool = false
    @State private var isLoading: Bool = false
    @State private var showSuccessToast: Bool = false
    @State private var toastMessage: String = ""
    
    // Report dialog state
    @State private var reportSexual: Bool = false
    @State private var reportViolent: Bool = false
    @State private var reportHateful: Bool = false
    @State private var reportHarmful: Bool = false
    @State private var reportChild: Bool = false
    @State private var reportInfringes: Bool = false
    @State private var reportPromotes: Bool = false
    @State private var reportSpam: Bool = false
    
    // Session data
    @State private var currentUserId: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView {
                LazyVStack(spacing: 0) {
                                        // Communication Settings Section
                    if !chatId.isEmpty && chatId != "null" {
                        communicationSettingsSection
                        
                        // Section separator
                        Rectangle()
                            .fill(Color("shade3"))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }
                    
                    // Safety & Privacy Section
                    safetyPrivacySection
                    
                                            // Bottom spacing for better scroll experience
                        Spacer()
                            .frame(height: 100)
                }
            }
            .background(Color("Background Color"))
        }
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .overlay(
            // Success Toast Overlay
            showSuccessToast ? 
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text(toastMessage)
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.green)
                .cornerRadius(8)
                .padding(.bottom, 50)
            }
            .animation(.easeInOut(duration: 0.3), value: showSuccessToast)
            : nil
        )
        .sheet(isPresented: $showReportDialog) {
            simpleReportDialog
        }
        .sheet(isPresented: $showDetailedReportDialog) {
            detailedReportDialog
        }

        .alert("Block User", isPresented: $showBlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Are you sure you want to block \(otherUserName)? This will also clear your conversation and mute notifications.")
        }
        .alert("Clear Conversation", isPresented: $showClearChatAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearConversation()
            }
        } message: {
            Text("Are you sure you want to clear your conversation with \(otherUserName)? This action cannot be undone.")
        }
        .alert("Camera Permission Required", isPresented: $showPermissionDialog) {
            Button("Cancel", role: .cancel) {
                allowCalls = false
            }
            Button("Settings") {
                openAppSettings()
            }
        } message: {
            Text("Camera and microphone permissions are required to make calls. Please enable them in Settings.")
        }
        .task {
            await loadSessionData()
            loadPreferences()
        }
        .onAppear {
            AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "onAppear() Profile options loaded for user: \(otherUserName)")
        }
    }
    

    
    // MARK: - Communication Settings Section
    private var communicationSettingsSection: some View {
        VStack(spacing: 0) {
            // Options Container
            VStack(spacing: 0) {
                // Allow Calls Toggle
                ProfileOptionToggleRow(
                    icon: "phone.fill",
                    title: "Allow calls",
                    subtitle: "When turned on other person can make audio and video calls to you",
                    isOn: $allowCalls,
                    onChange: { setCallRequest(mode: $0) }
                )
                
                // Mute Notifications Toggle
                ProfileOptionToggleRow(
                    icon: "bell.slash.fill",
                    title: "Mute notifications",
                    subtitle: "Stop receiving notifications from this user",
                    isOn: $isMuted,
                    onChange: { muteUser(isChecked: $0) }
                )
            }
            .background(Color("Background Color"))
            .cornerRadius(12)
            .padding(.horizontal, 12)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Safety & Privacy Section
    private var safetyPrivacySection: some View {
        VStack(spacing: 0) {
            // Options Container
            VStack(spacing: 0) {
                // Report User
                ProfileOptionRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Report user",
                    subtitle: "Report inappropriate behavior or content",
                    titleColor: Color("Red1"),
                    action: { handleReportUser() }
                )
                
                // Block User
                ProfileOptionRow(
                    icon: "hand.raised.fill",
                    title: "Block user",
                    subtitle: "Block this user and clear conversation",
                    titleColor: Color("Red1"),
                    action: { showBlockAlert = true }
                )
                
                // Clear Conversation (only if chat exists)
                if !chatId.isEmpty && chatId != "null" {
                    ProfileOptionRow(
                        icon: "trash.fill",
                        title: "Clear conversation",
                        subtitle: "Delete all messages in this conversation",
                        titleColor: Color("Red1"),
                        action: { showClearChatAlert = true }
                    )
                }
            }
            .background(Color("Background Color"))
            .cornerRadius(12)
            .padding(.horizontal, 12)
        }
    }
    

    


    // MARK: - Session Management
    private func loadSessionData() async {
        let sessionManager = SessionManager.shared
        currentUserId = sessionManager.userId ?? ""
        
        AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "loadSessionData() loaded session for user: \(currentUserId)")
    }
    
    // MARK: - Preference Loading
    private func loadPreferences() {
        setCallPreference()
        setMutePreference() 
    }
    
    // MARK: - Action Handlers
    private func handleReportUser() {
        AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "handleReportUser() checking if user can report")
        
        let sessionManager = SessionManager.shared
        if sessionManager.getReportedUsers().contains(otherUserId) {
            showToast(message: "You have already reported this user")
        } else if !sessionManager.getCanReportSB() {
            showToast(message: "You have reached the report limit. Please try again later.")
        } else {
            showDetailedReportDialog = true
        }
    }
    
    private func blockUser() {
        AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "blockUser() blocking user: \(otherUserId)")
        
        isLoading = true
        
        // Add to reported users list
        let sessionManager = SessionManager.shared
        sessionManager.setReportedUsers(sessionManager.getReportedUsers() + " " + otherUserId)
        
        // Block user on Firebase
        let database = Firestore.firestore()
        let blockData: [String: Any] = [
            "blocked_users": FieldValue.arrayUnion([otherUserId])
        ]
        
        database.collection("Users").document(currentUserId).setData(blockData, merge: true) { error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "blockUser() error: \(error.localizedDescription)")
                    self.showToast(message: "Failed to block user")
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "blockUser() successfully blocked user")
                    
                    // Also mute the user
                    self.muteUser(isChecked: true)
                    
                    // Clear conversation
                    self.clearConversationInternal()
                    
                    self.showToast(message: "User blocked successfully")
                    
                    // NEW: Call the callback to notify parent views that conversation was cleared
                    // This allows proper navigation flow (skip MessagesView and go back to previous view)
                    // Dismiss after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.onConversationCleared?()
                        self.dismiss()
                    }
                }
            }
        }
    }
    
    private func clearConversation() {
        clearConversationInternal()
        showToast(message: "Conversation cleared")
        
        // NEW: Call the callback to notify parent views that conversation was cleared
        // This allows proper navigation flow (skip MessagesView and go back to previous view)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.onConversationCleared?()
            self.dismiss()
        }
    }
    
    private func clearConversationInternal() {
        AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "clearConversationInternal() clearing conversation: \(chatId) - Android parity implementation")
        
        // Use ClearConversationService for Android parity - only updates Users/{userId}/Chats/{otherUserId}
        // Does NOT delete from Messages collection (matches Android behavior)
        ClearConversationService.shared.clearConversation(
            myUserId: currentUserId,
            otherUserId: otherUserId,
            chatId: chatId
        ) { success in
            DispatchQueue.main.async {
                if success {
                    AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "clearConversationInternal() successfully cleared conversation using ClearConversationService")
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "clearConversationInternal() failed to clear conversation using ClearConversationService")
                }
            }
        }
    }
    
    private func showToast(message: String) {
        toastMessage = message
        showSuccessToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showSuccessToast = false
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    // MARK: - Communication Settings Handlers
    private func setCallRequest(mode: Bool) {
        AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "setCallRequest() setting call mode: \(mode)")
        
        if mode {
            // Check camera permission
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            
            if cameraStatus != .authorized || microphoneStatus != .authorized {
                showPermissionDialog = true
                allowCalls = false
                return
            }
        }
        
        // Update Firebase
        let database = Firestore.firestore()
        let callData: [String: Any] = [
            "call_requests.\(otherUserId)": mode
        ]
        
        database.collection("Users").document(currentUserId).setData(callData, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "setCallRequest() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "setCallRequest() successfully updated call preference")
            }
        }
    }
    
    private func muteUser(isChecked: Bool) {
        AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "muteUser() muting user: \(isChecked)")
        
        let database = Firestore.firestore()
        let muteData: [String: Any] = [
            "muted_users.\(otherUserId)": isChecked
        ]
        
        database.collection("Users").document(currentUserId).setData(muteData, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "muteUser() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "muteUser() successfully updated mute preference")
            }
        }
    }
    
    private func setCallPreference() {
        let database = Firestore.firestore()
        database.collection("Users").document(currentUserId).getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let callRequests = data["call_requests"] as? [String: Bool] {
                DispatchQueue.main.async {
                    self.allowCalls = callRequests[self.otherUserId] ?? true
                }
            }
        }
    }
    
    private func setMutePreference() {
        let database = Firestore.firestore()
        database.collection("Users").document(currentUserId).getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let mutedUsers = data["muted_users"] as? [String: Bool] {
                DispatchQueue.main.async {
                    self.isMuted = mutedUsers[self.otherUserId] ?? false
                }
            }
        }
    }

    // MARK: - Dialog Views
    private var simpleReportDialog: some View {
        VStack(spacing: 20) {
            Text("Report User")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color("dark"))
            
            Text("Are you sure you want to report \(otherUserName)?")
                .font(.system(size: 16))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    showReportDialog = false
                }
                .foregroundColor(Color("shade6"))
                
                Button("Report") {
                    submitSimpleReport()
                }
                .foregroundColor(Color("Red1"))
            }
        }
        .padding(24)
        .background(Color("Background Color"))
        .cornerRadius(16)
        .padding(.horizontal, 32)
    }
    
    private var detailedReportDialog: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text("Report \(otherUserName)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("dark"))
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 8) {
                        ReportCheckboxRow(title: "Sexual content", isChecked: $reportSexual)
                        ReportCheckboxRow(title: "Violent or repulsive content", isChecked: $reportViolent)
                        ReportCheckboxRow(title: "Hateful or abusive content", isChecked: $reportHateful)
                        ReportCheckboxRow(title: "Harmful or dangerous acts", isChecked: $reportHarmful)
                        ReportCheckboxRow(title: "Child abuse", isChecked: $reportChild)
                        ReportCheckboxRow(title: "Infringes my rights", isChecked: $reportInfringes)
                        ReportCheckboxRow(title: "Promotes terrorism", isChecked: $reportPromotes)
                        ReportCheckboxRow(title: "Spam or misleading", isChecked: $reportSpam)
                    }
                }
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        showDetailedReportDialog = false
                        resetReportFlags()
                    }
                    .foregroundColor(Color("shade6"))
                    .frame(maxWidth: .infinity)
                    
                    Button("Submit Report") {
                        submitDetailedReport()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color("Red1"))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color("Background Color"))
                 }
    }
    


    // MARK: - Report and Feedback Handlers
    private func submitSimpleReport() {
        AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "submitSimpleReport() reporting user: \(otherUserId)")
        
        let database = Firestore.firestore()
        let reportData: [String: Any] = [
            "reported_user_id": otherUserId,
            "reporter_id": currentUserId,
            "report_type": "general",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        database.collection("Reports").addDocument(data: reportData) { error in
            DispatchQueue.main.async {
                self.showReportDialog = false
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "submitSimpleReport() error: \(error.localizedDescription)")
                    self.showToast(message: "Failed to submit report")
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "submitSimpleReport() successfully submitted report")
                    
                    // Add to reported users list
                    let sessionManager = SessionManager.shared
                    sessionManager.setReportedUsers(sessionManager.getReportedUsers() + " " + self.otherUserId)
                    
                    self.showToast(message: "Report submitted successfully")
                }
            }
        }
    }
    
    private func submitDetailedReport() {
        AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "submitDetailedReport() reporting user with details: \(otherUserId)")
        
        let database = Firestore.firestore()
        let reportData: [String: Any] = [
            "reported_user_id": otherUserId,
            "reporter_id": currentUserId,
            "report_type": "detailed",
            "sexual": reportSexual,
            "violent": reportViolent,
            "hateful": reportHateful,
            "harmful": reportHarmful,
            "child": reportChild,
            "infringes": reportInfringes,
            "promotes": reportPromotes,
            "spam": reportSpam,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        database.collection("Reports").addDocument(data: reportData) { error in
            DispatchQueue.main.async {
                self.showDetailedReportDialog = false
                self.resetReportFlags()
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "submitDetailedReport() error: \(error.localizedDescription)")
                    self.showToast(message: "Failed to submit report")
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfileOptionsView", message: "submitDetailedReport() successfully submitted detailed report")
                    
                    // Add to reported users list
                    let sessionManager = SessionManager.shared
                    sessionManager.setReportedUsers(sessionManager.getReportedUsers() + " " + self.otherUserId)
                    
                    self.showToast(message: "Report submitted successfully")
                }
            }
        }
    }
    

    
    private func resetReportFlags() {
        reportSexual = false
        reportViolent = false
        reportHateful = false
        reportHarmful = false
        reportChild = false
        reportInfringes = false
        reportPromotes = false
        reportSpam = false
    }
}

// MARK: - Supporting Row Components

struct ProfileOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var titleColor: Color = Color("dark")
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with consistent styling and better contrast
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(titleColor == Color("Red1") ? Color("Red1") : Color("ColorAccent"))
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(titleColor)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color("shade6"))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color("Background Color"))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfileOptionToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let onChange: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with consistent styling and better contrast
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color("ColorAccent"))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.leading)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(Color("shade6"))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Toggle with better accessibility
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color("ColorAccent")))
                .accessibilityLabel(title)
                .onChange(of: isOn) { newValue in
                    onChange(newValue)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color("Background Color"))
    }
}

struct ReportCheckboxRow: View {
    let title: String
    @Binding var isChecked: Bool
    
    var body: some View {
        Button(action: {
            isChecked.toggle()
        }) {
            HStack(spacing: 16) {
                // Checkbox
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isChecked ? Color("colorAccent") : Color("shade5"))
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color("Background Color"))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileOptionsView(
        otherUserId: "test123",
        otherUserName: "TestUser",
        otherUserDevId: "device123",
        otherUserGender: "Male",
        chatId: "chat123",
        onConversationCleared: {
            print("Conversation cleared - navigation should go back")
        }
    )
} 