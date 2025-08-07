import Foundation
import FirebaseFirestore
import FirebaseCrashlytics
import SwiftUI

/// ClearConversationService - iOS equivalent of Android ClearConversationWorker
/// Provides conversation clearing functionality with 100% Android parity
class ClearConversationService {
    
    // MARK: - Singleton
    static let shared = ClearConversationService()
    private init() {}
    
    // MARK: - Properties (Android Parity)
    private let database = Firestore.firestore()
    private let sessionManager = SessionManager.shared
    
    // MARK: - Public Methods (Android Parity)
    
    /// Clears conversation between two users - Android doWork() equivalent
    /// - Parameters:
    ///   - myUserId: Current user's ID
    ///   - otherUserId: Other user's ID
    ///   - chatId: Chat ID for AI chat cleanup
    ///   - completion: Completion handler with success status
    func clearConversation(
        myUserId: String,
        otherUserId: String,
        chatId: String? = nil,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "clearConversation() myUserId: \(myUserId), otherUserId: \(otherUserId), chatId: \(chatId ?? "nil")")
        
        // Validate parameters - Android parity
        guard !myUserId.isEmpty && !otherUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "clearConversation() missing required parameters")
            completion(false)
            return
        }
        
        // Execute on background queue - Android parity
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            
            do {
                // Clear AI chat IDs if needed - Android parity
                if let chatId = chatId {
                    self.clearAIChatIds(chatId: chatId)
                }
                
                // Clear conversation for both users - Android parity
                try self.clearConversationForUser(userId: myUserId, otherUserId: otherUserId)
                try self.clearConversationForUser(userId: otherUserId, otherUserId: myUserId)
                
                AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "clearConversation() successfully cleared conversation")
                
                // Navigate to main app - Android parity
                DispatchQueue.main.async {
                    self.navigateToMainApp()
                    completion(true)
                }
                
            } catch {
                AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "clearConversation() error: \(error.localizedDescription)")
                Crashlytics.crashlytics().record(error: error)
                
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    /// Clears conversation with retry logic - Android WorkManager retry equivalent
    /// - Parameters:
    ///   - myUserId: Current user's ID
    ///   - otherUserId: Other user's ID
    ///   - chatId: Chat ID for AI chat cleanup
    ///   - maxRetries: Maximum number of retry attempts
    ///   - completion: Completion handler with success status
    func clearConversationWithRetry(
        myUserId: String,
        otherUserId: String,
        chatId: String? = nil,
        maxRetries: Int = 3,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "clearConversationWithRetry() starting with \(maxRetries) max retries")
        
        attemptClearConversation(
            myUserId: myUserId,
            otherUserId: otherUserId,
            chatId: chatId,
            attemptsRemaining: maxRetries,
            completion: completion
        )
    }
    
    // MARK: - Private Methods (Android Parity)
    
    /// Attempts to clear conversation with retry logic
    private func attemptClearConversation(
        myUserId: String,
        otherUserId: String,
        chatId: String?,
        attemptsRemaining: Int,
        completion: @escaping (Bool) -> Void
    ) {
        clearConversation(myUserId: myUserId, otherUserId: otherUserId, chatId: chatId) { [weak self] success in
            if success {
                AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "attemptClearConversation() succeeded")
                completion(true)
            } else if attemptsRemaining > 1 {
                AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "attemptClearConversation() failed, retrying. Attempts remaining: \(attemptsRemaining - 1)")
                
                // Exponential backoff - Android WorkManager equivalent
                let delay = TimeInterval(pow(2.0, Double(4 - attemptsRemaining))) // 2, 4, 8 seconds
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self?.attemptClearConversation(
                        myUserId: myUserId,
                        otherUserId: otherUserId,
                        chatId: chatId,
                        attemptsRemaining: attemptsRemaining - 1,
                        completion: completion
                    )
                }
            } else {
                AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "attemptClearConversation() failed after all retries")
                completion(false)
            }
        }
    }
    
    /// Clears conversation for a specific user - Android clearConversationForUser() equivalent
    /// Enhanced with two-timestamp strategy for optimal message filtering
    private func clearConversationForUser(userId: String, otherUserId: String) throws {
        AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "clearConversationForUser() userId: \(userId), otherUserId: \(otherUserId)")
        
        let clearTimestamp = Int64(Date().timeIntervalSince1970 * 1000)
        
        let messageExtraData: [String: Any] = [
            "fetch_message_after": String(clearTimestamp),
            "conversation_deleted": true,
            "last_message_timestamp": FieldValue.serverTimestamp()
        ]
        
        // Use synchronous write - Android Tasks.await() equivalent
        let semaphore = DispatchSemaphore(value: 0)
        var writeError: Error?
        
        database.collection("Users")
            .document(userId)
            .collection("Chats")
            .document(otherUserId)
            .setData(messageExtraData, merge: true) { error in
                writeError = error
                semaphore.signal()
            }
        
        // Wait for completion - Android Tasks.await() equivalent
        semaphore.wait()
        
        if let error = writeError {
            throw error
        }
        
        // 🎯 Update local timestamp for two-timestamp strategy optimization
        if userId == sessionManager.userId {
            sessionManager.setChatFetchMessageAfter(otherUserId: otherUserId, timestamp: clearTimestamp)
            AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "clearConversationForUser() Updated local fetch_message_after timestamp: \(clearTimestamp)")
        }
        
        AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "clearConversationForUser() completed for userId: \(userId)")
    }
    
    /// Clears AI chat IDs from session - Android parity
    private func clearAIChatIds(chatId: String) {
        AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "clearAIChatIds() clearing AI chat ID: \(chatId)")
        
        guard let aiChatIds = sessionManager.getAiChatIds(), !aiChatIds.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "clearAIChatIds() no AI chat IDs to clear")
            return
        }
        
        // Remove chat ID from comma-separated list - Android parity
        let itemList = aiChatIds.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        if itemList.contains(chatId.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let updatedList = itemList.filter { $0 != chatId.trimmingCharacters(in: .whitespacesAndNewlines) }
            let updatedAiChatIds = updatedList.joined(separator: ",")
            
            sessionManager.setAiChatIds(updatedAiChatIds)
            AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "clearAIChatIds() updated AI chat IDs: \(updatedAiChatIds)")
        }
    }
    
    /// Navigates to main app - Android Intent equivalent
    private func navigateToMainApp() {
        AppLogger.log(tag: "LOG-APP: ClearConversationService", message: "navigateToMainApp() navigating to main app")
        
        NavigationManager.shared.navigateToMainApp()
    }
}

// MARK: - SessionManager Extension for AI Chat IDs (Android Parity)
extension SessionManager {
    
    /// Sets AI chat IDs - Android setAiChatIds() equivalent
    func setAiChatIds(_ chatIds: String) {
        UserDefaults.standard.set(chatIds, forKey: "aiChatIds")
        synchronize()
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setAiChatIds() AI chat IDs updated: \(chatIds)")
    }
    
    /// Gets AI chat IDs - Android getAiChatIds() equivalent
    func getAiChatIds() -> String? {
        return UserDefaults.standard.string(forKey: "aiChatIds")
    }
} 