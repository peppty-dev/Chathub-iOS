import Foundation
import FirebaseFirestore

/// InterestSuggestionManager
/// Bridges extraction with persistence and gating (existing interests, Firestore update, local cache).
final class InterestSuggestionManager {
    static let shared = InterestSuggestionManager()
    private init() {}

    private let defaults = UserDefaults.standard
    private enum Keys { 
        static let suggestedInterests = "suggested_interests_store"
        static let interestStates = "interest_states_store" // Track asked/selected status
    }
    
    // Configuration
    private let maxInterestPoolSize = 5
    
    struct InterestState: Codable {
        let phrase: String
        var isSelected: Bool
        var wasAsked: Bool
        var timestamp: TimeInterval // For LRU logic
        
        init(phrase: String) {
            self.phrase = phrase
            self.isSelected = false
            self.wasAsked = false
            self.timestamp = Date().timeIntervalSince1970
        }
    }

    /// Process a message and possibly return a suggestion phrase to show as a pill.
    func processOutgoingMessage(chatId: String, message: String) -> String? {
        let existing = SessionManager.shared.interestTags
        let suggestion = InterestExtractionService.shared.processMessage(chatId: chatId, text: message, existingInterests: existing)
        if let s = suggestion {
            appendSuggestedInterest(s)
        }
        return suggestion
    }

    /// Accept an interest: persist to Firestore and local SessionManager.
    func acceptInterest(_ phrase: String, chatId: String, completion: ((Bool) -> Void)? = nil) {
        var tags = SessionManager.shared.interestTags
        if !tags.contains(where: { $0.caseInsensitiveCompare(phrase) == .orderedSame }) {
            tags.append(phrase)
        }

        let userId = UserSessionManager.shared.userId ?? ""
        let interestsRef = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("interests")

        let userData: [String: Any] = [
            "tags": tags,
            "updated_at": FieldValue.serverTimestamp()
        ]

        interestsRef.setData(userData, merge: true) { [weak self] error in
            if error == nil {
                SessionManager.shared.interestTags = tags
                SessionManager.shared.synchronize()
                InterestExtractionService.shared.markAccepted(chatId: chatId, phrase: phrase)
                completion?(true)
            } else {
                completion?(false)
            }
        }
    }

    /// Reject an interest: do not persist; tell extractor to cool down the candidate.
    func rejectInterest(_ phrase: String, chatId: String) {
        InterestExtractionService.shared.markDisliked(chatId: chatId, phrase: phrase)
        
        // Check if this suggestion should be permanently removed after multiple rejections
        let dislikedCount = InterestExtractionService.shared.getDislikedCount(chatId: chatId, phrase: phrase)
        let maxDislikes = 2 // Keep in sync with InterestExtractionService.Config.maxDislikesBeforePermanentRemoval
        
        if dislikedCount >= maxDislikes {
            // Remove from suggested interests list to prevent it from appearing in other chats
            removeSuggestedInterest(phrase)
            AppLogger.log(tag: "InterestSuggestion", message: "Permanently removed '\(phrase)' after \(dislikedCount) rejections")
        }
    }

    /// Remove an accepted interest and sync to Firestore (dedicated subdocument path)
    func removeInterest(_ phrase: String, completion: ((Bool) -> Void)? = nil) {
        var tags = SessionManager.shared.interestTags
        tags.removeAll { $0.caseInsensitiveCompare(phrase) == .orderedSame }

        let userId = UserSessionManager.shared.userId ?? ""
        let interestsRef = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("interests")

        let userData: [String: Any] = [
            "tags": tags,
            "updated_at": FieldValue.serverTimestamp()
        ]

        interestsRef.setData(userData, merge: true) { error in
            if error == nil {
                SessionManager.shared.interestTags = tags
                SessionManager.shared.synchronize()
                completion?(true)
            } else {
                completion?(false)
            }
        }
    }

    // MARK: - Remote Read (with migration fallback)

    /// Reads interests for a given user. Tries subdocument path first, falls back to legacy root fields.
    func getRemoteInterests(for userId: String, completion: @escaping ([String]) -> Void) {
        let interestsRef = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("interests")

        interestsRef.getDocument { doc, _ in
            if let doc = doc, doc.exists, let data = doc.data(), let tags = data["tags"] as? [String] {
                completion(tags)
            } else {
                // Legacy fallback: read from root user doc
                Firestore.firestore()
                    .collection("Users")
                    .document(userId)
                    .getDocument { userDoc, _ in
                        if let data = userDoc?.data(), let tags = data["interest_tags"] as? [String] {
                            completion(tags)
                        } else {
                            completion([])
                        }
                    }
            }
        }
    }

    // MARK: - Circular Buffer Interest Pool (Fixed Size: 10)

    func getSuggestedInterests() -> [String] {
        let states = getInterestStates()
        return states.map { $0.phrase }
    }
    
    /// Get the next unasked interest for the info gathering pill
    func getNextUnaskedInterest() -> String? {
        var states = getInterestStates()
        
        // Find first unasked interest
        for i in 0..<states.count {
            if !states[i].wasAsked && !states[i].isSelected {
                // Mark as asked and update timestamp
                states[i].wasAsked = true
                states[i].timestamp = Date().timeIntervalSince1970
                saveInterestStates(states)
                
                AppLogger.log(tag: "InterestSuggestion", message: "Asking interest: '\(states[i].phrase)'")
                return states[i].phrase
            }
        }
        
        // If all are asked, try to add a new interest to the pool
        if let newInterest = generateNewInterest(excludingStates: states) {
            addInterestToPool(newInterest)
            return getNextUnaskedInterest() // Recursive call to get the newly added interest
        }
        
        AppLogger.log(tag: "InterestSuggestion", message: "No unasked interests available")
        return nil
    }
    
    /// Mark an interest as selected (user said yes)
    func markInterestAsSelected(_ phrase: String) {
        var states = getInterestStates()
        
        for i in 0..<states.count {
            if states[i].phrase.caseInsensitiveCompare(phrase) == .orderedSame {
                states[i].isSelected = true
                states[i].timestamp = Date().timeIntervalSince1970
                saveInterestStates(states)
                
                AppLogger.log(tag: "InterestSuggestion", message: "Marked '\(phrase)' as selected")
                break
            }
        }
    }
    
    /// Mark an interest as rejected (user said no) - just update timestamp, keep in pool
    func markInterestAsRejected(_ phrase: String) {
        var states = getInterestStates()
        
        for i in 0..<states.count {
            if states[i].phrase.caseInsensitiveCompare(phrase) == .orderedSame {
                states[i].timestamp = Date().timeIntervalSince1970
                saveInterestStates(states)
                
                AppLogger.log(tag: "InterestSuggestion", message: "Marked '\(phrase)' as rejected (staying in pool)")
                break
            }
        }
    }

    func removeSuggestedInterest(_ phrase: String) {
        var list = getSuggestedInterests()
        list.removeAll { $0.caseInsensitiveCompare(phrase) == .orderedSame }
        defaults.set(list, forKey: Keys.suggestedInterests)
    }
    
    /// Clear all suggested interests and force re-seeding (for debugging)
    func clearSuggestedInterests() {
        defaults.removeObject(forKey: Keys.suggestedInterests)
        defaults.removeObject(forKey: Keys.interestStates)
        AppLogger.log(tag: "InterestSuggestion", message: "Cleared all interest data - will re-initialize pool on next access")
    }
    
    // MARK: - Internal Pool Management
    
    private func getInterestStates() -> [InterestState] {
        guard let data = defaults.data(forKey: Keys.interestStates),
              let states = try? JSONDecoder().decode([InterestState].self, from: data) else {
            // Initialize with seed interests if no states exist
            let initialStates = getInitialSuggestedInterests().prefix(maxInterestPoolSize).map { InterestState(phrase: $0) }
            let statesArray = Array(initialStates)
            saveInterestStates(statesArray)
            AppLogger.log(tag: "InterestSuggestion", message: "Initialized interest pool with \(statesArray.count) interests")
            return statesArray
        }
        return states
    }
    
    private func saveInterestStates(_ states: [InterestState]) {
        if let data = try? JSONEncoder().encode(states) {
            defaults.set(data, forKey: Keys.interestStates)
        }
    }
    
    private func addInterestToPool(_ newInterest: String) {
        var states = getInterestStates()
        
        // Check if already exists
        if states.contains(where: { $0.phrase.caseInsensitiveCompare(newInterest) == .orderedSame }) {
            return
        }
        
        if states.count < maxInterestPoolSize {
            // Pool not full, just add
            states.append(InterestState(phrase: newInterest))
            AppLogger.log(tag: "InterestSuggestion", message: "Added '\(newInterest)' to pool (size: \(states.count)/\(maxInterestPoolSize))")
        } else {
            // Pool is full, need to remove LRU item
            let unselectedStates = states.filter { !$0.isSelected }
            
            if !unselectedStates.isEmpty {
                // Remove oldest unselected item
                let oldestUnselected = unselectedStates.min(by: { $0.timestamp < $1.timestamp })!
                if let index = states.firstIndex(where: { $0.phrase == oldestUnselected.phrase }) {
                    states.remove(at: index)
                    AppLogger.log(tag: "InterestSuggestion", message: "Removed oldest unselected '\(oldestUnselected.phrase)' to make room")
                }
            } else {
                // All are selected, remove oldest selected item
                let oldestSelected = states.min(by: { $0.timestamp < $1.timestamp })!
                if let index = states.firstIndex(where: { $0.phrase == oldestSelected.phrase }) {
                    states.remove(at: index)
                    AppLogger.log(tag: "InterestSuggestion", message: "Removed oldest selected '\(oldestSelected.phrase)' to make room")
                }
            }
            
            // Add new interest
            states.append(InterestState(phrase: newInterest))
            AppLogger.log(tag: "InterestSuggestion", message: "Added '\(newInterest)' to full pool")
        }
        
        saveInterestStates(states)
    }
    
    private func generateNewInterest(excludingStates: [InterestState]) -> String? {
        let existingPhrases = Set(excludingStates.map { $0.phrase.lowercased() })
        let allPossibleInterests = getInitialSuggestedInterests()
        
        // Find interests not in current pool
        let availableInterests = allPossibleInterests.filter { !existingPhrases.contains($0.lowercased()) }
        
        return availableInterests.randomElement()
    }
    
    /// Debug method to check if a specific interest is blocked
    func debugInterestStatus(_ phrase: String) -> String {
        let states = getInterestStates()
        let state = states.first { $0.phrase.caseInsensitiveCompare(phrase) == .orderedSame }
        
        let poolStatus = if let state = state {
            "inPool=true, selected=\(state.isSelected), asked=\(state.wasAsked)"
        } else {
            "inPool=false"
        }
        
        return "Interest '\(phrase)': \(poolStatus), poolSize=\(states.count)/\(maxInterestPoolSize)"
    }

    private func appendSuggestedInterest(_ phrase: String) {
        var list = getSuggestedInterests()
        guard !list.contains(where: { $0.caseInsensitiveCompare(phrase) == .orderedSame }) else { return }
        list.insert(phrase, at: 0)
        if list.count > 50 { list = Array(list.prefix(50)) }
        defaults.set(list, forKey: Keys.suggestedInterests)
    }
    
    /// Get initial set of popular interests to seed the suggestions list
    private func getInitialSuggestedInterests() -> [String] {
        // Curated list of popular interests from different categories
        return [
            // Social and relationships
            "friendship", "dating", "romance", "love", "relationships",
            
            // Entertainment
            "music", "movies", "dancing", "singing", "reading", "books", "art", "photography",
            
            // Activities and hobbies
            "cooking", "travel", "gaming", "sports", "fitness", "yoga", "hiking", "swimming",
            
            // Creative pursuits
            "writing", "painting", "crafts", "fashion", "design", "creativity",
            
            // Technology and learning
            "technology", "programming", "science", "learning", "languages", "education",
            
            // Lifestyle
            "food", "coffee", "wine", "pets", "gardening", "nature", "adventure",
            
            // Social activities
            "parties", "concerts", "theater", "festivals", "volunteering", "humor"
        ].shuffled() // Randomize the order to provide variety
    }
}


