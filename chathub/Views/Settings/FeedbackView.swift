import SwiftUI

/// Full-Screen Feedback View - Android parity implementation
struct FeedbackView: View {
    @ObservedObject private var ratingService = RatingService.shared
    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @State private var textHeight: CGFloat = 120
    @State private var showSuccessMessage = false
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    // Character limits (matching Android implementation)
    private let minCharacters = 10
    private let maxCharacters = 500
    
    // Calculate text height dynamically
    private func updateTextHeight(for text: String) {
        let baseHeight: CGFloat = 120
        let maxHeight: CGFloat = 200
        let font = UIFont.systemFont(ofSize: 16)
        let textWidth = UIScreen.main.bounds.width - 48
        
        let textRect = text.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [NSAttributedString.Key.font: font],
            context: nil
        )
        
        let newHeight = max(baseHeight, min(maxHeight, textRect.height + 24))
        if abs(newHeight - textHeight) > 1 {
            textHeight = newHeight
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color("Background Color")
                .ignoresSafeArea()
            
            if showSuccessMessage {
                // Success state
                successView
            } else {
                // Main feedback form
                feedbackForm
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onTapGesture {
            // Dismiss keyboard when tapping outside text editor
            hideKeyboard()
        }
        .onAppear {
            updateTextHeight(for: feedbackText)
        }
        .onDisappear {
            // Clean up when user navigates back
            if showSuccessMessage {
                AppLogger.log(tag: "LOG-APP: FeedbackView", message: "user navigated back from success view")
            } else {
                AppLogger.log(tag: "LOG-APP: FeedbackView", message: "user navigated back from feedback form")
            }
            // Reset the navigation state when leaving the view
            RatingService.shared.navigateToFeedback = false
        }
    }
    
    // MARK: - Feedback Form
    
    private var feedbackForm: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                headerSection
                
                // Rating Display (if came from rating)
                if ratingService.rating > 0 {
                    ratingSection
                }
                
                // Feedback Text Input
                textInputSection
                
                // Submit Button (full-width for mobile)
                submitButtonSection
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // App Icon or Feedback Icon
            Image(systemName: "message.badge.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color("ColorAccent"))
            
            // Title and Description
            VStack(spacing: 6) {
                Text("We Value Your Feedback")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.center)
                
                Text("Help us improve ChatHub by sharing your thoughts, suggestions, or reporting any issues you've encountered.")
                    .font(.system(size: 15))
                    .foregroundColor(Color("shade_700"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(1.5)
            }
        }
    }
    
    // MARK: - Rating Section
    
    private var ratingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(starColor(for: Int(ratingService.rating)))
                    .font(.system(size: 18))
                
                Text("Your Rating")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color("dark"))
                
                Spacer()
                
                Text("\(Int(ratingService.rating))/5")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(starColor(for: Int(ratingService.rating)))
            }
            
            // Star display
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= Int(ratingService.rating) ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundColor(star <= Int(ratingService.rating) ? 
                                       starColor(for: Int(ratingService.rating)) : 
                                       Color("grey_400"))
                }
                
                Spacer()
            }
            
            // Rating message (matching Android)
            if !ratingService.ratingMessage.isEmpty {
                HStack {
                    Text(ratingService.ratingMessage)
                        .font(.system(size: 14))
                        .foregroundColor(Color("shade_700"))
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("shade1"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("shade3"), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Text Input Section
    
    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                
                // Character counter
                Text("\(feedbackText.count)/\(maxCharacters)")
                    .font(.system(size: 14))
                    .foregroundColor(getCharacterCountColor())
            }
            
            // Text input container
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("shade1"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color("shade3"), lineWidth: 1)
                    )
                    .frame(height: textHeight)
                
                if feedbackText.isEmpty {
                    Text("Write your feedback here (min \(minCharacters) characters)")
                        .font(.system(size: 16))
                        .foregroundColor(Color("shade6"))
                        .padding(.leading, 16)
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
                
                Group {
                    if #available(iOS 16.0, *) {
                        TextEditor(text: $feedbackText)
                            .font(.system(size: 16))
                            .foregroundColor(Color("dark"))
                            .frame(height: textHeight)
                            .padding(.leading, 12)
                            .padding(.trailing, 12)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                            .scrollContentBackground(.hidden)
                            .onChange(of: feedbackText) { newText in
                                if newText.count > maxCharacters {
                                    feedbackText = String(newText.prefix(maxCharacters))
                                } else {
                                    updateTextHeight(for: newText)
                                }
                            }
                    } else {
                        TextEditor(text: $feedbackText)
                            .font(.system(size: 16))
                            .foregroundColor(Color("dark"))
                            .frame(height: textHeight)
                            .padding(.leading, 12)
                            .padding(.trailing, 12)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                            .onChange(of: feedbackText) { newText in
                                if newText.count > maxCharacters {
                                    feedbackText = String(newText.prefix(maxCharacters))
                                } else {
                                    updateTextHeight(for: newText)
                                }
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Submit Button Section
    
    private var submitButtonSection: some View {
        VStack(spacing: 16) {
            // Validation message
            if !isValidFeedback() && !feedbackText.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(Color("orange_500"))
                        .font(.system(size: 14))
                    
                    Text("Please write at least \(minCharacters) characters")
                        .font(.system(size: 14))
                        .foregroundColor(Color("orange_500"))
                    
                    Spacer()
                }
            }
            
            // Submit button
            Button(action: submitFeedback) {
                HStack(spacing: 12) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    
                    Text(isSubmitting ? "Submitting..." : "Submit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isValidFeedback() && !isSubmitting ? 
                              LinearGradient(
                                colors: [Color("ColorAccent"), Color("ColorAccent").opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                              ) : 
                              LinearGradient(
                                colors: [Color("grey_500"), Color("grey_500")],
                                startPoint: .leading,
                                endPoint: .trailing
                              )
                        )
                )
            }
            .disabled(!isValidFeedback() || isSubmitting)
            .opacity((isValidFeedback() && !isSubmitting) ? 1.0 : 0.6)
        }
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 0) {
            // Top spacing
            Spacer(minLength: 60)
            
            // Success content container
            VStack(spacing: 20) {
                // Success icon - appropriately sized for mobile
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color("green_500"))
                    .scaleEffect(showSuccessMessage ? 1.0 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showSuccessMessage)
                
                // Success message
                VStack(spacing: 8) {
                    Text("Thank You!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color("dark"))
                    
                    Text("Your feedback has been submitted successfully. We appreciate you taking the time to help us improve ChatHub.")
                        .font(.system(size: 15))
                        .foregroundColor(Color("shade_700"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1.5)
                        .padding(.horizontal, 16)
                }
            }
            
            // Bottom spacing
            Spacer(minLength: 40)
            
            // Close button
            Button(action: {
                AppLogger.log(tag: "LOG-APP: FeedbackView", message: "user manually closed feedback view")
                RatingService.shared.navigateToFeedback = false
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("ColorAccent"))
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Helper Methods
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func isValidFeedback() -> Bool {
        return feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).count >= minCharacters
    }
    
    private func getCharacterCountColor() -> Color {
        let trimmedCount = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).count
        
        if trimmedCount >= minCharacters {
            return Color("green_500")
        } else if feedbackText.count >= maxCharacters {
            return Color("red_500")
        } else {
            return Color("shade_600")
        }
    }
    
    private func starColor(for rating: Int) -> Color {
        switch rating {
        case 1, 2: return Color("red_500")
        case 3: return Color("orange_500")
        case 4, 5: return Color("green_500")
        default: return Color("grey_500")
        }
    }
    
    private func submitFeedback() {
        let trimmedFeedback = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedFeedback.count >= minCharacters else {
            AppLogger.log(tag: "LOG-APP: FeedbackView", message: "feedback too short (minimum \(minCharacters) characters required)")
            return
        }
        
        isSubmitting = true
        
        AppLogger.log(tag: "LOG-APP: FeedbackView", message: "submitting feedback - length: \(trimmedFeedback.count)")
        
        // Simulate network delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Save feedback using RatingService (Android parity)
            ratingService.saveAppFeedback(trimmedFeedback)
            
            // Show success state
            isSubmitting = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showSuccessMessage = true
            }
        }
    }
}

#Preview {
    FeedbackView()
} 