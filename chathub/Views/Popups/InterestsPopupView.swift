import SwiftUI
import FirebaseFirestore

// MARK: - Interests Popup View
// Clean popup overlay for interests selection (no ads) - following app's popup patterns
struct InterestsPopupView: View {
    @Binding var isPresented: Bool
    @State private var selectedInterests: [String] = []
    @State private var allInterests: [String] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // No ads needed for interests popup
    
    private let maxInterests = 5
    
    var body: some View {
        ZStack {
            // Background overlay - dark semi-transparent tap to dismiss (following guidelines)
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    AppLogger.log(tag: "LOG-APP: InterestsPopupView", message: "backgroundTapped() Dismissing popup")
                    isPresented = false
                }
            
            // Main popup container - following app's popup structure
            VStack {
                Spacer() // Center vertically
                
                // Popup content - following guidelines layout
                VStack(spacing: 0) {
                    // Title - following app's popup title pattern
                    Text("Select Interests")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color("dark"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16) // layout_marginTop="16dp"
                    
                    // Description text - following app's popup description pattern
                    Text("Select up to 5 interests to let others know what kind of chats you're looking for")
                        .font(.system(size: 14))
                        .foregroundColor(Color("shade_800"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4) // lineSpacingExtra="4dp"
                        .padding(.horizontal, 32) // layout_marginHorizontal="32dp"
                        .padding(.top, 16) // layout_marginTop="16dp"
                        .padding(.bottom, 16) // layout_marginBottom="16dp"
                    
                    // Selection count with visual prominence
                    HStack {
                        Text("Selected:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("dark"))
                        
                        Text("\(selectedInterests.count)/\(maxInterests)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(selectedInterests.count >= maxInterests ? Color("ErrorRed") : Color("ColorAccent"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    // Interests List with improved layout
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(allInterests, id: \.self) { interest in
                                InterestPopupRowView(
                                    interest: interest,
                                    isSelected: selectedInterests.contains(interest),
                                    onTap: {
                                        toggleInterest(interest)
                                    }
                                )
                            }
                        }
                    }
                    .frame(height: 280) // Adjusted height for better proportions
                    .background(Color("Background Color"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("shade_400"), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    // Save button - following app's primary button pattern
                    Button(action: saveInterests) {
                        HStack(spacing: 12) {
                            if selectedInterests.count > 0 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Save Interests")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(minHeight: 56) // minHeight="56dp" - following app pattern
                        .padding(.horizontal, 12) // Internal padding
                        .background(selectedInterests.count > 0 ? Color("ColorAccent") : Color("shade_600"))
                        .cornerRadius(12) // app:cornerRadius="12dp"
                    }
                    .disabled(selectedInterests.count == 0)
                    .padding(.horizontal, 24) // layout_marginHorizontal="24dp"
                    .padding(.bottom, 8) // layout_marginBottom="8dp"
                }
                .frame(maxWidth: .infinity) // Fill screen width per guidelines
                .padding(.top, 24)
                .padding(.bottom, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color("shade2"))
                )
                .padding(.horizontal, 24) // Horizontal spacing from screen edges
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
                
                Spacer() // Center vertically
            }
        }
        .onAppear {
            setupInterests()
            AppLogger.log(tag: "LOG-APP: InterestsPopupView", message: "interestsAndStatusDialog() loaded as popup")
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
        selectedInterests = UserSessionManager.shared.interestTags
        
        // Update interest time (matching Android)
        UserSessionManager.shared.interestTime = Date().timeIntervalSince1970
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
            isPresented = false
        } else {
            alertMessage = "Please select at least one interest"
            showingAlert = true
        }
    }
    
    // MARK: - Firebase Save (matching Android exactly)
    private func saveInterestsDataToFirebase(_ tags: [String]) {
        AppLogger.log(tag: "LOG-APP: InterestsPopupView", message: "saveInterestsDataToFirebase()")
        
        let userData: [String: Any] = [
            "interest_tags": tags,
            "interest_sentence": NSNull() // Matching Android - not saving sentence anymore
        ]
        
        let db = Firestore.firestore()
        let userId = UserSessionManager.shared.userId ?? ""
        
        db.collection("Users").document(userId)
            .setData(userData, merge: true) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        alertMessage = "Failed to save interest"
                        showingAlert = true
                    }
                    AppLogger.log(tag: "LOG-APP: InterestsPopupView", message: "Failed to save interests: \(error)")
                } else {
                    DispatchQueue.main.async {
                        alertMessage = "Chat interest updated"
                        showingAlert = true
                    }
                    AppLogger.log(tag: "LOG-APP: InterestsPopupView", message: "Interests saved successfully")
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
}

// MARK: - Interest Popup Row View Component
struct InterestPopupRowView: View {
    let interest: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Text(interest)
                .font(.system(size: 16))
                .foregroundColor(Color("dark"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundColor(isSelected ? Color("ColorAccent") : Color("shade_400"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16) // Increased touch target
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .background(
            isSelected ? Color("ColorAccent").opacity(0.1) : Color.clear
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(interest)
        .accessibilityHint(isSelected ? "Selected. Tap to deselect" : "Not selected. Tap to select")
    }
}

// MARK: - Preview
#Preview {
    InterestsPopupView(isPresented: .constant(true))
} 