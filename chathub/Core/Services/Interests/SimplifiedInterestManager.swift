import Foundation
import FirebaseFirestore
import NaturalLanguage

/// SimplifiedInterestManager
/// Clean, single-list approach to managing user interests with maximum 5 items.
/// Replaces the complex dual-storage system with a simple, predictable flow.
final class SimplifiedInterestManager {
    static let shared = SimplifiedInterestManager()
    private init() {}
    
    // MARK: - Configuration
    private let maxInterests = 5
    private let userDefaults = UserDefaults.standard
    private let storageKey = "user_interests_simplified"
    private let pendingSuggestionsKey = "pending_interest_suggestions"
    
    // MARK: - Data Structure
    struct InterestItem: Codable {
        let phrase: String
        let addedAt: TimeInterval
        
        init(phrase: String) {
            self.phrase = phrase
            self.addedAt = Date().timeIntervalSince1970
        }
    }
    
    // MARK: - Storage
    private var interests: [InterestItem] {
        get {
            guard let data = userDefaults.data(forKey: storageKey),
                  let items = try? JSONDecoder().decode([InterestItem].self, from: data) else {
                return []
            }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: storageKey)
                AppLogger.log(tag: "SimplifiedInterest", message: "Saved \(newValue.count) interests: \(newValue.map { $0.phrase })")
            }
        }
    }
    
    // Storage for pending suggestions (for InfoGatherPill timing integration)
    private var pendingSuggestions: [String] {
        get {
            return userDefaults.stringArray(forKey: pendingSuggestionsKey) ?? []
        }
        set {
            userDefaults.set(newValue, forKey: pendingSuggestionsKey)
            AppLogger.log(tag: "SimplifiedInterest", message: "Pending suggestions updated: \(newValue)")
        }
    }
    
    // MARK: - Public API
    
    /// Process a new message and add suggestion to queue for InfoGatherPill timing system
    /// - Parameter text: The message content to analyze
    func processNewMessage(_ text: String) {
        AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "processNewMessage() called with: '\(text)'")
        
        // Use existing Apple AI/ML extraction logic but simplified
        guard let suggestion = extractBestCandidate(from: text) else {
            AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "processNewMessage() no candidate extracted from '\(text)'")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "processNewMessage() extracted candidate: '\(suggestion)'")
        
        // Check if already exists in our list (case insensitive)
        let currentPhrases = interests.map { $0.phrase.lowercased() }
        if currentPhrases.contains(suggestion.lowercased()) {
            AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "Skipping '\(suggestion)' - already in current interests: \(currentPhrases)")
            return
        }
        
        // Check if already in pending suggestions queue
        if pendingSuggestions.contains(where: { $0.caseInsensitiveCompare(suggestion) == .orderedSame }) {
            AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "Skipping '\(suggestion)' - already in pending queue: \(pendingSuggestions)")
            return
        }
        
        // Add to pending suggestions queue
        var pending = pendingSuggestions
        pending.append(suggestion)
        pendingSuggestions = pending
        
        AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "Successfully added '\(suggestion)' to pending queue. Queue now: \(pendingSuggestions)")
    }
    
    /// User accepted an interest suggestion
    /// - Parameter phrase: The interest phrase to add
    func addInterest(_ phrase: String) {
        let newItem = InterestItem(phrase: phrase)
        var currentInterests = interests
        
        // Add to beginning (newest first)
        currentInterests.insert(newItem, at: 0)
        
        // Maintain maximum size - remove oldest if necessary
        if currentInterests.count > maxInterests {
            let removed = currentInterests.removeLast()
            AppLogger.log(tag: "SimplifiedInterest", message: "List full - removed oldest: '\(removed.phrase)'")
        }
        
        // Save to storage
        interests = currentInterests
        
        // Sync to existing systems
        syncToSessionAndFirestore()
        
        AppLogger.log(tag: "SimplifiedInterest", message: "Added '\(phrase)' to interests. Current list: \(getCurrentInterests())")
    }
    
    /// User rejected an interest suggestion
    /// - Parameter phrase: The interest phrase to reject (no-op in simplified system)
    func rejectInterest(_ phrase: String) {
        // In simplified system, we just discard - no storage or tracking needed
        AppLogger.log(tag: "SimplifiedInterest", message: "Rejected '\(phrase)' - discarded")
    }
    
    /// Get current interests for display
    /// - Returns: Array of interest phrases in newest-first order
    func getCurrentInterests() -> [String] {
        return interests.map { $0.phrase }
    }
    
    /// Remove a specific interest from the list
    /// - Parameter phrase: The interest phrase to remove
    func removeInterest(_ phrase: String) {
        var currentInterests = interests
        currentInterests.removeAll { $0.phrase.caseInsensitiveCompare(phrase) == .orderedSame }
        interests = currentInterests
        syncToSessionAndFirestore()
        
        AppLogger.log(tag: "SimplifiedInterest", message: "Removed '\(phrase)' from interests")
    }
    
    /// Check if an interest already exists in the list
    /// - Parameter phrase: The interest phrase to check
    /// - Returns: True if interest already exists
    func hasInterest(_ phrase: String) -> Bool {
        return interests.contains { $0.phrase.caseInsensitiveCompare(phrase) == .orderedSame }
    }
    
    /// Get the next pending suggestion for InfoGatherPill timing system
    /// - Returns: Next suggestion or nil if queue is empty
    func getNextPendingSuggestion() -> String? {
        guard !pendingSuggestions.isEmpty else {
            return nil
        }
        
        // Return first suggestion (FIFO)
        let suggestion = pendingSuggestions.first!
        AppLogger.log(tag: "SimplifiedInterest", message: "Retrieved pending suggestion: '\(suggestion)'")
        return suggestion
    }
    
    /// Remove a suggestion from the pending queue (called after user responds)
    /// - Parameter phrase: The suggestion phrase to remove
    func removePendingSuggestion(_ phrase: String) {
        var pending = pendingSuggestions
        pending.removeAll { $0.caseInsensitiveCompare(phrase) == .orderedSame }
        pendingSuggestions = pending
        
        AppLogger.log(tag: "SimplifiedInterest", message: "Removed '\(phrase)' from pending queue")
    }
    
    /// Clear all interests (for debugging/testing)
    func clearAllInterests() {
        interests = []
        syncToSessionAndFirestore()
        AppLogger.log(tag: "SimplifiedInterest", message: "Cleared all interests")
    }
    
    /// Debug method to check current state
    func debugCurrentState() -> String {
        let currentInterests = getCurrentInterests()
        let pending = pendingSuggestions
        return "Current interests: \(currentInterests), Pending: \(pending)"
    }
    
    // MARK: - Private Methods
    
    /// Extract the best interest candidate from text using existing Apple AI/ML logic
    private func extractBestCandidate(from text: String) -> String? {
        // Reuse the existing InterestExtractionService tokenization and ML logic
        // but simplified to just return the best candidate without complex scoring
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "extractBestCandidate() analyzing: '\(trimmed)'")
        
        guard !trimmed.isEmpty else { 
            AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "extractBestCandidate() text is empty")
            return nil 
        }
        
        // Use existing profanity check
        if containsProfanity(trimmed) {
            AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "extractBestCandidate() contains profanity, skipping")
            return nil
        }
        
        // Use existing tokenization
        let tokens = tokenize(text: trimmed)
        AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "extractBestCandidate() tokens: \(tokens)")
        
        if tokens.isEmpty { 
            AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "extractBestCandidate() no tokens found")
            return nil 
        }
        
        // Find best candidate using existing activity keywords and ML analysis
        var bestCandidate: String?
        var bestScore: Double = 0
        
        for token in tokens {
            let phrase = token
            if phrase.count < 3 || phrase.count > 20 { 
                AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "extractBestCandidate() skipping '\(phrase)' - invalid length")
                continue 
            }
            
            var score: Double = 1.0
            
            // Check against activity keywords (reuse existing list)
            if Self.activityKeywords.contains(phrase) {
                score += 2.0
                AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "extractBestCandidate() '\(phrase)' is activity keyword, score: \(score)")
            }
            
            // Use Apple ML for additional scoring
            let mlScore = calculateMLScore(for: phrase, in: trimmed)
            score += mlScore
            AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "extractBestCandidate() '\(phrase)' final score: \(score) (base: 1.0, ml: \(mlScore))")
            
            if score > bestScore {
                bestScore = score
                bestCandidate = phrase
                AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "extractBestCandidate() new best candidate: '\(phrase)' with score \(score)")
            }
        }
        
        // Only return if score meets threshold
        let result = bestScore >= 2.0 ? bestCandidate : nil
        AppLogger.log(tag: "LOG-APP: SimplifiedInterest", message: "extractBestCandidate() final result: '\(result ?? "nil")' (bestScore: \(bestScore), threshold: 2.0)")
        return result
    }
    
    /// Calculate ML-based score for a phrase using Apple's Natural Language framework
    private func calculateMLScore(for phrase: String, in text: String) -> Double {
        guard let wordRange = text.range(of: phrase, options: [.caseInsensitive]) else { return 0 }
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        
        let lexicalClass = tagger.tag(at: wordRange.lowerBound, unit: .word, scheme: .lexicalClass).0
        let nameType = tagger.tag(at: wordRange.lowerBound, unit: .word, scheme: .nameType).0
        
        var score: Double = 0
        
        // POS-based scoring
        if lexicalClass == .noun {
            score += 1.0
        } else if lexicalClass == .adjective {
            score += 0.5
        } else if lexicalClass == .verb && phrase.hasSuffix("ing") {
            score += 0.8
        }
        
        // Named entity bonus
        if let name = nameType, [.personalName, .placeName, .organizationName].contains(name) {
            score += 0.7
        }
        
        return score
    }
    
    /// Tokenize text using existing logic
    private func tokenize(text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var result: [String] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range]).lowercased()
            if token.range(of: "\\p{L}", options: .regularExpression) != nil {
                if !Self.commonWordsToSkip.contains(token) {
                    result.append(token)
                }
            }
            return true
        }
        return result
    }
    
    /// Check if text contains profanity using the centralized Firebase-based system
    private func containsProfanity(_ text: String) -> Bool {
        // Use the same centralized profanity system used throughout the app
        // This uses Firebase-fetched word lists via ProfanityService
        return Profanity.share.doesContainProfanity(text)
    }
    
    /// Sync interests to existing SessionManager and Firestore systems
    private func syncToSessionAndFirestore() {
        let interestPhrases = getCurrentInterests()
        
        // Update SessionManager (existing system)
        SessionManager.shared.interestTags = interestPhrases
        SessionManager.shared.synchronize()
        
        // Update Firestore (existing path)
        let userId = UserSessionManager.shared.userId ?? ""
        if !userId.isEmpty {
            let interestsRef = Firestore.firestore()
                .collection("Users")
                .document(userId)
                .collection("Profile")
                .document("interests")
            
            let userData: [String: Any] = [
                "tags": interestPhrases,
                "updated_at": FieldValue.serverTimestamp()
            ]
            
            interestsRef.setData(userData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "SimplifiedInterest", message: "Firestore sync failed: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "SimplifiedInterest", message: "Synced to Firestore: \(interestPhrases)")
                }
            }
        }
    }
    
    // MARK: - Static Data (reused from existing system)
    
    /// Common words to skip during tokenization
    private static let commonWordsToSkip: Set<String> = [
        "the", "a", "an", "and", "or", "but", "if", "then", "of", "to", "for", "with", "by", "from", "as", "at", "in", "on", "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "can", "this", "that", "these", "those", "i", "you", "he", "she", "we", "they", "me", "him", "her", "us", "them", "my", "your", "his", "her", "our", "their"
    ]
    
    /// Activity keywords that are likely to indicate interests
    private static let activityKeywords: Set<String> = [
        // Sports and physical activities
        "football", "soccer", "basketball", "tennis", "cricket", "baseball", "volleyball", "golf", "swimming", "running", "cycling", "hiking", "climbing", "skiing", "snowboarding", "surfing", "skateboarding", "boxing", "wrestling", "martial", "yoga", "pilates", "gym", "fitness", "workout", "exercise", "dance", "dancing",
        
        // Entertainment and media
        "movie", "movies", "film", "films", "cinema", "music", "song", "songs", "singing", "concert", "guitar", "piano", "drums", "violin", "books", "book", "reading", "novel", "poetry", "writing", "photography", "photo", "art", "painting", "drawing", "gaming", "games", "game",
        
        // Hobbies and crafts
        "cooking", "baking", "recipe", "recipes", "food", "wine", "coffee", "tea", "gardening", "plants", "flowers", "crafting", "crafts", "knitting", "sewing", "woodworking", "pottery", "jewelry", "collecting", "collection",
        
        // Travel and exploration
        "travel", "traveling", "trip", "vacation", "adventure", "exploring", "camping", "hiking", "sailing", "beach", "mountain", "culture", "language", "languages",
        
        // Technology and learning
        "programming", "coding", "technology", "science", "math", "learning", "studying", "education",
        
        // Social activities
        "volunteering", "charity", "community", "party", "celebration", "festival"
    ]
}


