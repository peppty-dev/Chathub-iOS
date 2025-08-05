import SwiftUI
import FirebaseFirestore

// MARK: - Interests Dialog View
// Complete match to Android interestsAndStatusDialog() functionality
struct InterestsDialogView: View {
    @State private var selectedInterests: [String] = []
    @State private var allInterests: [String] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Banner Ad Model & Mediator for dialog

    
    private let maxInterests = 5
    
    var body: some View {
        VStack(spacing: 0) {
            // Content Container (matching Android dialog structure)
            VStack(spacing: 16) {
                // Title
                Text("Select Interests")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.center)
                
                // Description text (matching Android)
                Text("Select up to 5 interests to let others know what kind of chats you're looking for")
                    .font(.system(size: 12))
                    .foregroundColor(Color("shade_800"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 25)
                
                // Interests List with fixed height (matching Android 300dp)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(allInterests, id: \.self) { interest in
                            InterestRowView(
                                interest: interest,
                                isSelected: selectedInterests.contains(interest),
                                onTap: {
                                    toggleInterest(interest)
                                }
                            )
                        }
                    }
                }
                .frame(height: 300) // Fixed height matching Android
                .padding(.horizontal, 10)
                .background(Color("Background Color"))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color("shade_400"), lineWidth: 0.5)
                )
                
                // Selection count (matching Android)
                Text("Selected: \(selectedInterests.count)/\(maxInterests)")
                    .font(.system(size: 12))
                    .foregroundColor(Color("shade_800"))
                
                // Save button (matching Android design)
                Button(action: saveInterests) {
                    Text("Save Interests")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(selectedInterests.count > 0 ? Color("colorAccent") : Color("shade_400"))
                        .cornerRadius(8)
                }
                .disabled(selectedInterests.count == 0)
                .padding(.horizontal, 25)
            }
            .padding(16)
        }
        .background(Color("shade_100"))
        .navigationTitle("Update Interests")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupInterests()
            AppLogger.log(tag: "LOG-APP: InterestsDialogView", message: "interestsAndStatusDialog() loaded")
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Functions (matching Android exactly)
    private func setupInterests() {
        // Get all interests from predefined categories (matching Android getPreDefinedInterests())
        var interests: [String] = []
        let categories = getPreDefinedInterests()
        
        for category in categories {
            for (_, interestList) in category {
                interests.append(contentsOf: interestList)
            }
        }
        
        // Sort interests alphabetically for easier selection (matching Android)
        allInterests = interests.sorted()
        
        // Restore previously selected interests (matching Android)
                    selectedInterests = SessionManager.shared.interestTags
        
        // Update interest time (matching Android)
                    SessionManager.shared.interestTime = Int(Date().timeIntervalSince1970)
    }
    
    private func toggleInterest(_ interest: String) {
        if let index = selectedInterests.firstIndex(of: interest) {
            selectedInterests.remove(at: index)
        } else {
            if selectedInterests.count >= maxInterests {
                alertMessage = "You can select up to 5 interests"
                showingAlert = true
            } else {
                selectedInterests.append(interest)
            }
        }
    }
    
    private func saveInterests() {
        if selectedInterests.count > 0 {
            saveInterestsDataToFirebase(selectedInterests)
            presentationMode.wrappedValue.dismiss()
        } else {
            alertMessage = "Please select at least one interest"
            showingAlert = true
        }
    }
    
    // MARK: - Firebase Save (matching Android exactly)
    private func saveInterestsDataToFirebase(_ tags: [String]) {
        AppLogger.log(tag: "LOG-APP: InterestsDialogView", message: "saveInterestsDataToFirebase()")
        
        let userData: [String: Any] = [
            "interest_tags": tags,
            "interest_sentence": NSNull() // Matching Android - not saving sentence anymore
        ]
        
        let db = Firestore.firestore()
        let userId = SessionManager.shared.userId ?? ""
        
        db.collection("Users").document(userId)
            .setData(userData, merge: true) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        alertMessage = "Failed to save interest"
                        showingAlert = true
                    }
                    AppLogger.log(tag: "LOG-APP: InterestsDialogView", message: "Failed to save interests: \(error)")
                } else {
                    DispatchQueue.main.async {
                        alertMessage = "Chat interest updated"
                        showingAlert = true
                    }
                    AppLogger.log(tag: "LOG-APP: InterestsDialogView", message: "Interests saved successfully")
                }
            }
        
        // Save to UserDefaults (matching Android SessionManager)
        let sessionManager = SessionManager.shared
        sessionManager.interestTags = tags
        sessionManager.interestSentence = ""
        sessionManager.synchronize()
    }
    
    // MARK: - Predefined Interests (matching Android exactly)
    private func getPreDefinedInterests() -> [[String: [String]]] {
        var categories: [[String: [String]]] = []
        
        // General Chat
        let generalChat = [
            "General Chat": [
                "Friendly Talk",
                "Make New Friends", "International Chat", "Fun Chat",
                "Casual Conversation", "Just Chat", "Meet People",
                "Deep Conversations", "Quick Chat", "Open Minded Chat"
            ]
        ]
        categories.append(generalChat)
        
        // Social & Friendship
        let socialFriendship = [
            "Social & Friendship": [
                "Find Friends", "Friendship", "Language Exchange",
                "Cultural Exchange", "Voice Call", "Video Chat",
                "Long Term Friends", "Pen Pals", "Night Life",
                "Party Chat", "Social Adventures", "Mature Friends"
            ]
        ]
        categories.append(socialFriendship)
        
        // Romance & Dating
        let romance = [
            "Romance & Dating": [
                "Dating Chat", "Flirting", "Romance",
                "Adult Dating", "Sweet Talk", "Romantic Chat",
                "Mature Dating", "Singles Chat", "Casual Dating"
            ]
        ]
        categories.append(romance)
        
        // Adult Interests
        let adultInterests = [
            "Adult Interests": [
                "Adult Chat", "Mature Chat", "Open Minded",
                "Role Play", "Fantasy Chat", "Adult Stories",
                "Mature Content", "Social Talk"
            ]
        ]
        categories.append(adultInterests)
        
        // Special Interests
        let specialInterests = [
            "Special Interests": [
                "Travel Talk", "Music Chat", "Movie Talk",
                "Gaming Chat", "Share Stories", "Life Discussion",
                "Night Chat", "Entertainment", "Food & Cooking",
                "Arts & Culture", "Sports Talk"
            ]
        ]
        categories.append(specialInterests)
        
        return categories
    }
    

    
    private func checkPremiumStatus() {
        if !PremiumAccessHelper.hasPremiumAccess {
            // Show premium popup
        }
    }
    
    private func loadInterests() {
        let sessionManager = SessionManager.shared
        selectedInterests = sessionManager.interestTags
        sessionManager.interestTime = Int(Date().timeIntervalSince1970)
    }
    
    private func showAdForNonPremiumUsers() {
        guard !PremiumAccessHelper.hasPremiumAccess else { return }
        // Show ad logic
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        InterestsDialogView()
    }
}

// MARK: - Interest Row View Component
struct InterestRowView: View {
    let interest: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Text(interest)
                .font(.system(size: 16))
                .foregroundColor(Color("dark"))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Checkmark icon (matching Android behavior)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color("colorAccent"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .background(
            isSelected ? Color("colorAccent").opacity(0.1) : Color.clear
        )
    }
} 