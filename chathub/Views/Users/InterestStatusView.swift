import SwiftUI

struct InterestStatusView: View {
    @Binding var isPresented: Bool
    
    @State private var selectedInterests: [String] = []
    @State private var statusText: String = ""
    
    let interestOptions = [
        "Travel", "Music", "Movies", "Books", "Sports", "Technology",
        "Art", "Food", "Photography", "Gaming", "Fashion", "Fitness"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Set Your Interests & Status")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Interests Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select Your Interests")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                        ForEach(interestOptions, id: \.self) { interest in
                            Button(action: {
                                toggleInterest(interest)
                            }) {
                                Text(interest)
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedInterests.contains(interest) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedInterests.contains(interest) ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Status Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Status")
                        .font(.headline)
                    
                    TextField("What's on your mind?", text: $statusText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Save Button
                Button(action: {
                    saveInterestsAndStatus()
                }) {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close") {
                isPresented = false
            })
        }
        .onAppear {
            loadSavedData()
        }
    }
    
    private func toggleInterest(_ interest: String) {
        if selectedInterests.contains(interest) {
            selectedInterests.removeAll { $0 == interest }
        } else {
            selectedInterests.append(interest)
        }
    }
    
    private func loadSavedData() {
        let sessionManager = SessionManager.shared
        selectedInterests = sessionManager.interestTags
        statusText = sessionManager.interestSentence ?? ""
    }
    
    private func saveInterestsAndStatus() {
        let sessionManager = SessionManager.shared
        sessionManager.interestTags = selectedInterests
        sessionManager.interestSentence = statusText
        sessionManager.synchronize()
        
        isPresented = false
    }
}

struct InterestStatusView_Previews: PreviewProvider {
    static var previews: some View {
        InterestStatusView(isPresented: .constant(true))
    }
} 