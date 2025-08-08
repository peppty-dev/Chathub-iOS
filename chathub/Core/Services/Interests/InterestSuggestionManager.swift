import Foundation
import FirebaseFirestore

/// InterestSuggestionManager
/// Bridges extraction with persistence and gating (existing interests, Firestore update, local cache).
final class InterestSuggestionManager {
    static let shared = InterestSuggestionManager()
    private init() {}

    private let defaults = UserDefaults.standard
    private enum Keys { static let suggestedInterests = "suggested_interests_store" }

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
        // Keep suggestion for now; could also remove if desired
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

    // MARK: - Suggested Store (UserDefaults)

    func getSuggestedInterests() -> [String] {
        (defaults.stringArray(forKey: Keys.suggestedInterests) ?? [])
    }

    func removeSuggestedInterest(_ phrase: String) {
        var list = getSuggestedInterests()
        list.removeAll { $0.caseInsensitiveCompare(phrase) == .orderedSame }
        defaults.set(list, forKey: Keys.suggestedInterests)
    }

    private func appendSuggestedInterest(_ phrase: String) {
        var list = getSuggestedInterests()
        guard !list.contains(where: { $0.caseInsensitiveCompare(phrase) == .orderedSame }) else { return }
        list.insert(phrase, at: 0)
        if list.count > 50 { list = Array(list.prefix(50)) }
        defaults.set(list, forKey: Keys.suggestedInterests)
    }
}


