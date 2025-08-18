import Foundation
import SwiftUI
import StoreKit
import FirebaseFirestore
import FirebaseAnalytics

/// Service to handle app rating requests and feedback collection
/// Matches Android MainActivity.SubmitRating() and related logic exactly
class RatingService: ObservableObject {
    static let shared = RatingService()
    
    @Published var showRatingDialog = false
    @Published var navigateToFeedback = false // Navigation to feedback view
    @Published var rating: Float = 0
    @Published var feedbackText = ""
    @Published var ratingMessage = ""
    
    private let sessionManager = SessionManager.shared
    private let database = Firestore.firestore()
    private let appName = "ChatHub"
    
    private init() {}
    
    /// Check if rating dialog should be shown when returning from message activity
    /// Matches Android MainActivity.onActivityResult() logic exactly
    func checkAndShowRatingDialogIfNeeded() {
        AppLogger.log(tag: "LOG-APP: RatingService", message: "checkAndShowRatingDialogIfNeeded() checking conditions")
        
        let maxChatsForRequest = Int(sessionManager.maxChatsForRateUsRequest)
        let maxRateUsRequests = Int(sessionManager.maxRateUsRequests)
        let totalReceived = sessionManager.totalNoOfMessageReceived
        let totalSent = sessionManager.totalNoOfMessageSent
        let ratingTries = sessionManager.ratingTries
        
        AppLogger.log(tag: "LOG-APP: RatingService", message: "checkAndShowRatingDialogIfNeeded() maxChatsForRequest=\(maxChatsForRequest), totalReceived=\(totalReceived), totalSent=\(totalSent), ratingTries=\(ratingTries), maxRateUsRequests=\(maxRateUsRequests)")
        
        // Android condition: (sessionManager.getTotalNoOfMessagesRecieved() > sessionManager.getMaxChatsForRateUsRequest()) && 
        //                   (sessionManager.getTotalNoOfMessagesSent() > sessionManager.getMaxChatsForRateUsRequest()) && 
        //                   (sessionManager.getRatingTries() < sessionManager.getMaxRateUsRequests())
        if totalReceived > maxChatsForRequest && 
           totalSent > maxChatsForRequest && 
           ratingTries < maxRateUsRequests {
            AppLogger.log(tag: "LOG-APP: RatingService", message: "checkAndShowRatingDialogIfNeeded() conditions met, showing rating dialog")
            DispatchQueue.main.async {
                self.showRatingDialog = true
            }
        } else {
            AppLogger.log(tag: "LOG-APP: RatingService", message: "checkAndShowRatingDialogIfNeeded() conditions not met, skipping rating dialog")
        }
    }
    
    /// Submit rating - matches Android SubmitRating() logic exactly
    func submitRating() {
        AppLogger.log(tag: "LOG-APP: RatingService", message: "submitRating() rating: \(rating)")
        
        guard rating > 0 else {
            AppLogger.log(tag: "LOG-APP: RatingService", message: "submitRating() no rating selected")
            return
        }
        
        // Log analytics (matching Android exactly)
        Analytics.logEvent("app_events", parameters: [
            AnalyticsParameterItemName: "rating_\(appName)_\(Int(rating))"
        ])
        
        if rating >= 4 {
            // High rating - close custom popup and show App Store review prompt
            showRatingDialog = false
            showReviewPrompt()
        } else {
            // Low rating - increment tries and show feedback view
            sessionManager.ratingTries += 1
            
            ratingMessage = "Please let us know the reason for giving us \(Int(rating)) star rating."
            showRatingDialog = false
            navigateToFeedback = true
        }
        
        // Reset message counters (matching Android exactly)
        sessionManager.totalNoOfMessageReceived = 0
        sessionManager.totalNoOfMessageSent = 0
    }
    
    /// Show App Store review prompt - matches Android showReviewPrompt() logic
    private func showReviewPrompt() {
        AppLogger.log(tag: "LOG-APP: RatingService", message: "showReviewPrompt() launching review flow")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        if #available(iOS 14.0, *) {
            SKStoreReviewController.requestReview(in: windowScene)
        } else {
            // Fallback for older iOS versions
            if let url = URL(string: "itms-apps://itunes.apple.com/app/id1539272301?action=write-review") {
                UIApplication.shared.open(url)
            }
        }
        
        // Set rating counters to prevent future prompts (matching Android exactly)
        sessionManager.totalNoOfMessageReceived = -999999999
        sessionManager.totalNoOfMessageSent = -999999999
        
        // Log analytics with tries count (matching Android)
        Analytics.logEvent("app_events", parameters: [
            AnalyticsParameterItemName: "rating_\(appName)_\(Int(rating))_after_\(sessionManager.ratingTries)"
        ])
    }
    
    /// Save feedback to Firebase - matches Android saveAppFeedback() exactly
    func saveAppFeedback(_ feedback: String) {
        AppLogger.log(tag: "LOG-APP: RatingService", message: "saveAppFeedback() saving feedback")
        
        guard feedback.count >= 10 else {
            AppLogger.log(tag: "LOG-APP: RatingService", message: "saveAppFeedback() feedback too short")
            return
        }
        
        // Create feedback object (matching Android structure exactly)
        let feedbackData: [String: Any] = [
            "userId": sessionManager.userId ?? "",
            "gender": SessionManager.getKeyUserGender(),
            "country": sessionManager.userRetrievedCountry ?? "",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "feedback": feedback,
            "timestamp": Int(Date().timeIntervalSince1970),
            "rating": rating
        ]
        
        // Save to Firebase (matching Android collection structure exactly)
        database.collection("Feedback")
            .document(Bundle.main.bundleIdentifier ?? "com.peppty.ChatApp")
            .collection("Rating_Feedback")
            .document(String(Int(Date().timeIntervalSince1970)))
            .setData(feedbackData) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        AppLogger.log(tag: "LOG-APP: RatingService", message: "saveAppFeedback() failed: \(error)")
                    } else {
                        AppLogger.log(tag: "LOG-APP: RatingService", message: "saveAppFeedback() successful")
                    }
                    
                    // Clear feedback text but don't close the view - let user control navigation
                    self.feedbackText = ""
                }
            }
    }
    
    /// Cancel rating dialog - matches Android "Maybe Later" button
    func cancelRatingDialog() {
        AppLogger.log(tag: "LOG-APP: RatingService", message: "cancelRatingDialog() user chose maybe later")
        
        // Reset message counters (matching Android exactly)
        sessionManager.totalNoOfMessageReceived = 0
        sessionManager.totalNoOfMessageSent = 0
        
        showRatingDialog = false
        rating = 0
    }
    
    /// Get star color based on rating - matches Android updateRatingFeedback() logic
    func starColor(for rating: Int) -> Color {
        switch rating {
        case 1, 2: return Color("red_500")
        case 3: return Color("orange_500")
        case 4, 5: return Color("green_500")
        default: return Color("grey_500")
        }
    }
    
    /// Get rating description - matches Android updateRatingFeedback() logic
    func ratingDescription(for rating: Int) -> String {
        switch rating {
        case 1: return "Not meeting your expectations.\nHelp us improve!"
        case 2: return "Could be much better.\nTell us how!"
        case 3: return "It's okay, but needs improvement"
        case 4: return "Great! Rate us on App Store"
        case 5: return "Awesome! Share your love on App Store"
        default: return "Tap the stars to rate"
        }
    }
    
    /// Get rating emoji - matches Android updateRatingFeedback() logic
    func ratingEmoji(for rating: Int) -> String {
        switch rating {
        case 1: return "😞"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "😊"
        case 5: return "🤩"
        default: return "⭐"
        }
    }
}

// MARK: - SessionManager Extension for Rating Support (Android Parity)
extension SessionManager {
    /// Increment total messages received - Android setTotalNoOfMessageRecieved(count + 1)
    func incrementTotalNoOfMessageReceived() {
        totalNoOfMessageReceived += 1
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "incrementTotalNoOfMessageReceived() count: \(totalNoOfMessageReceived)")
    }
    
    /// Increment total messages sent - Android setTotalNoOfMessageSent(count + 1)
    func incrementTotalNoOfMessageSent() {
        totalNoOfMessageSent += 1
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "incrementTotalNoOfMessageSent() count: \(totalNoOfMessageSent)")
    }
} 