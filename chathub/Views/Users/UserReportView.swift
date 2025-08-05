import SwiftUI
import FirebaseFirestore

struct UserReportView: View {
    @Binding var isPresented: Bool
    let reportedUser: OnlineUser
    let onReportSubmitted: (() -> Void)?
    
    @State private var selectedReason = "Inappropriate Content"
    @State private var customReason = ""
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let reportReasons = [
        "Inappropriate Content",
        "Spam",
        "Harassment",
        "Fake Profile",
        "Underage User",
        "Other"
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            VStack(spacing: 0) {
                // Main Content Card
                VStack(spacing: 0) {
                    // Header Section
                    VStack(spacing: 5) {
                        // Title
                        Text("What's wrong?")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(Color.primary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                        
                        // Description
                        Text("Let us know what's going on")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(Color.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Subtitle
                        Text("We use your feedback to help us learn about this user and take appropriate action.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 5)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                    
                    // Report Buttons Section
                    VStack(spacing: 10) {
                        // Harmful dangerous acts
                        ReportReasonButton(
                            title: "    Harmful dangerous acts    ",
                            isSelected: selectedReason == "Harmful dangerous acts"
                        ) {
                            selectedReason = "Harmful dangerous acts"
                        }
                        
                        // Sexual content (missing from 
                        ReportReasonButton(
                            title: "    Sexual or adult content    ",
                            isSelected: selectedReason == "Sexual or adult content"
                        ) {
                            selectedReason = "Sexual or adult content"
                        }
                        
                        // Violent or repulsive content
                        ReportReasonButton(
                            title: "    Violent or repulsive content    ",
                            isSelected: selectedReason == "Violent or repulsive content"
                        ) {
                            selectedReason = "Violent or repulsive content"
                        }
                        
                        // Child Abuse
                        ReportReasonButton(
                            title: "    Child Abuse    ",
                            isSelected: selectedReason == "Child Abuse"
                        ) {
                            selectedReason = "Child Abuse"
                        }
                        
                        // Promotes Terrorism
                        ReportReasonButton(
                            title: "    Promotes Terrorism    ",
                            isSelected: selectedReason == "Promotes Terrorism"
                        ) {
                            selectedReason = "Promotes Terrorism"
                        }
                        
                        // Hateful or abusive content
                        ReportReasonButton(
                            title: "    Hateful or abusive content    ",
                            isSelected: selectedReason == "Hateful or abusive content"
                        ) {
                            selectedReason = "Hateful or abusive content"
                        }
                        
                        // Spam or misleading
                        ReportReasonButton(
                            title: "    Spam or misleading    ",
                            isSelected: selectedReason == "Spam or misleading"
                        ) {
                            selectedReason = "Spam or misleading"
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 100) // Space before report button
                    
                    // Report Button
                    Button(action: {
                        submitReport()
                    }) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                                    .scaleEffect(0.8)
                            }
                            Text("Report user")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(isSubmitting)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .background(Color("Background Color"))
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
                
                // Cancel Button (positioned outside the card, like 
                Button(action: {
                    dismissPopup()
                }) {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color("ButtonColor"))
                }
                .padding(.top, 20)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadUserSession()
        }
        .overlay(
            // Toast notification
            Group {
                if showingAlert {
                    VStack {
                        Spacer()
                        HStack {
                            Text(alertMessage)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.8))
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
    
    private func loadUserSession() {
        // Implementation of loadUserSession()
    }
    
    private func submitReport() {
        isSubmitting = true
        
        let sessionManager = SessionManager.shared
        guard let userId = sessionManager.userId, !userId.isEmpty else {
            alertMessage = "User session not found. Please login again."
            showingAlert = true
            isSubmitting = false
            return
        }
        
        let reportedUserId = reportedUser.id ?? ""
        let reportReason = selectedReason == "Other" ? customReason : selectedReason
        
        // Check if user already reported this user
        let reportedUsers = sessionManager.reportedUsers ?? ""
        if reportedUsers.contains(reportedUserId) {
            alertMessage = "You have already reported this user."
            showingAlert = true
            isSubmitting = false
            return
        }
        
        // Add user to reported list
        let updatedReportedUsers = reportedUsers.isEmpty ? reportedUserId : reportedUsers + "," + reportedUserId
        sessionManager.reportedUsers = updatedReportedUsers
        sessionManager.blockedUsers = (sessionManager.blockedUsers ?? "") + "," + reportedUserId
        
        // Handle repeated reports tracking
        var repeatedUserReportsTimeArray = sessionManager.repeatedUserReportsTimeArray
        let currentTime = Date().timeIntervalSince1970
        repeatedUserReportsTimeArray.append(currentTime)
        sessionManager.repeatedUserReportsTimeArray = repeatedUserReportsTimeArray
        
        if sessionManager.repeatedUserReportsTimeArray.count >= 3 {
            let blockUntilTimestamp = currentTime + (24 * 60 * 60) // 24 hours
            sessionManager.repeatedUserReportsSBTime = blockUntilTimestamp
        }
        
        // Check if user is temporarily blocked from reporting
        let repeatedUserReportsSBTime = sessionManager.repeatedUserReportsSBTime
        if repeatedUserReportsSBTime > currentTime {
            // User is temporarily blocked, remove the block
            sessionManager.repeatedUserReportsSBTime = 0
        }
        
        // Submit report to server
        submitReportToServer(reportedUserId: reportedUserId, reportReason: reportReason)
    }
    
    private func submitReportToServer(reportedUserId: String, reportReason: String) {
        let sessionManager = SessionManager.shared
        
        let reportData: [String: Any] = [
            "reported_user_id": reportedUserId,
            "report_reason": reportReason,
            "reporter_user_id": sessionManager.userId ?? "",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Submit to Firestore
        UserReportingService.shared.submitUserReport(reportData: reportData) { success in
            DispatchQueue.main.async {
                isSubmitting = false
                if success {
                    alertMessage = "Report submitted successfully."
                    
                    // ANDROID PARITY: Refresh reports data after successful report (like Android GetReportsWorker)
                    GetReportsService.shared.refreshReportsData()
                    
                    onReportSubmitted?()
                } else {
                    alertMessage = "Failed to submit report. Please try again."
                }
                showingAlert = true
            }
        }
    }
    
    private func blockUser(reportedUserId: String) {
        let sessionManager = SessionManager.shared
        
        var putNotification: [String: Any] = [:]
        putNotification["notif_type"] = "user_blocked"
        putNotification["notif_sender_name"] = sessionManager.userName ?? ""
        putNotification["notif_sender_id"] = sessionManager.userId ?? ""
        putNotification["notif_sender_gender"] = sessionManager.userGender ?? ""
        putNotification["notif_sender_image"] = sessionManager.userProfilePhoto ?? ""
        putNotification["notif_body"] = "You have been blocked by \(sessionManager.userName ?? "a user")."
        putNotification["notif_time"] = Date().timeIntervalSince1970
        
        // Send notification to blocked user
        UserReportingService.shared.sendNotificationToUser(userId: reportedUserId, notificationData: putNotification)
    }
    
    private func reportToModerator(reportedUserId: String, reportReason: String) {
        let sessionManager = SessionManager.shared
        
        var putNotification: [String: Any] = [:]
        putNotification["notif_type"] = "user_reported"
        putNotification["notif_sender_name"] = sessionManager.userName ?? ""
        putNotification["notif_sender_id"] = sessionManager.userId ?? ""
        putNotification["notif_sender_gender"] = sessionManager.userGender ?? ""
        putNotification["notif_sender_image"] = sessionManager.userProfilePhoto ?? ""
        putNotification["notif_body"] = "User reported for: \(reportReason)"
        putNotification["notif_time"] = Date().timeIntervalSince1970
        putNotification["reported_user_id"] = reportedUserId
        
        // Send to moderation system
        UserReportingService.shared.sendModerationReport(reportData: putNotification)
    }
    
    private func dismissPopup() {
        isPresented = false
    }
}

// MARK: - Supporting Views

struct ReportReasonButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color("ButtonColor"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 40)
                .padding(.horizontal, 10)
                .background(isSelected ? Color.systemGray : Color.systemGray6)
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Color Extension
extension Color {
    static let systemGray = Color(UIColor.systemGray)
    static let systemGray6 = Color(UIColor.systemGray6)
}

// MARK: - Preview
struct UserReportView_Previews: PreviewProvider {
    static var previews: some View {
        UserReportView(
            isPresented: .constant(true),
            reportedUser: OnlineUser(
                id: "sample_user_id",
                name: "Sample User",
                age: "25",
                country: "Sample Country",
                gender: "male",
                isOnline: true,
                language: "English",
                lastTimeSeen: Date(),
                deviceId: "sample_device_id",
                profileImage: ""
            ),
            onReportSubmitted: nil
        )
    }
} 