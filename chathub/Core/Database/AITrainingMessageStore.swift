import Foundation
import SQLite3

class AITrainingMessageStore {
    
    static let shared = AITrainingMessageStore()
    private let maxMessagesPerChat = 25 // Android parity: Keep only 25 messages per chat
    
    private init() {
        // Initialize if needed
    }
    
    // MARK: - Public Methods
    
    /// Insert a new AI training message
    func insert(messageId: String, chatId: String, userName: String, userMessage: String, replyName: String, replyMessage: String, messageTime: TimeInterval) {
        AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "insert() saving message with ID: \(messageId)")
        
        // CRITICAL FIX: Check database readiness before inserting
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "insert() Database not ready, skipping insert")
            return
        }
        
        let aiMessage = AITrainingMessage(
            id: messageId,
            chatId: chatId,
            userMessage: userMessage,
            userName: userName,
            replyMessage: replyMessage,
            replyName: replyName,
            messageTime: Int(messageTime)
        )
        
        // CRITICAL FIX: Use DatabaseManager to get connection and pass it to AITrainingMessagesDB
        DatabaseManager.shared.executeOnDatabaseQueue { db in
            AITrainingMessagesDB.shared.insertAITrainingMessage(aiMessage, db: db)
        }
        AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "insert() successfully saved message with ID: \(messageId)")
    }
    
    /// Get all AI training messages for a specific chat
    func getMessagesForChat(chatId: String) -> [AITrainingMessage] {
        AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "getMessagesForChat() fetching messages for chat: \(chatId)")
        
        // CRITICAL FIX: Check database readiness before querying
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "getMessagesForChat() Database not ready, returning empty array")
            return []
        }
        
        // CRITICAL FIX: Use DatabaseManager to get connection and pass it to AITrainingMessagesDB
        let messages = DatabaseManager.shared.executeOnDatabaseQueue { db in
            return AITrainingMessagesDB.shared.fetchAITrainingMessages(forChatId: chatId, db: db)
        }
        AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "getMessagesForChat() found \(messages.count) messages")
        return messages
    }
    
    /// Delete all AI training messages for a specific chat
    func deleteMessagesForChat(chatId: String) {
        DatabaseManager.shared.executeOnDatabaseQueue { db in
            AITrainingMessagesDB.shared.deleteAITrainingMessages(forChatId: chatId, db: db)
        }
    }
    
    /// Delete the oldest message for a specific chat
    func deleteOldestMessage(forChatId chatId: String) {
        AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "deleteOldestMessage() deleting oldest message for chat: \(chatId)")
        
        // Get the oldest message ID
        if let oldestMessageId = getOldestMessageId(forChatId: chatId) {
            deleteMessage(messageId: oldestMessageId)
            AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "deleteOldestMessage() deleted message ID: \(oldestMessageId)")
        } else {
            AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "deleteOldestMessage() no messages found for chat: \(chatId)")
        }
    }
    
    /// Get count of messages for a specific chat
    func getMessageCountForChat(chatId: String) -> Int {
        return DatabaseManager.shared.executeOnDatabaseQueue { db in
            var queryStatement: OpaquePointer?
            let queryStatementString = "SELECT COUNT(*) FROM AITrainingMessages WHERE chatId = ?;"
            var count = 0
            
            if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(queryStatement, 1, (chatId as NSString).utf8String, -1, nil)
                
                if sqlite3_step(queryStatement) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(queryStatement, 0))
                }
            }
            
            sqlite3_finalize(queryStatement)
            AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "getMessageCountForChat() chat \(chatId) has \(count) messages")
            return count
        }
    }
    
    /// Get formatted conversation history for AI prompts (Android parity)
    func getFormattedConversationHistory(forChatId chatId: String) -> String {
        AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "getFormattedConversationHistory() for chat: \(chatId)")
        
        let messages = getMessagesForChat(chatId: chatId)
        var formattedMessages = ""
        
        for message in messages.reversed() { // Reverse to get chronological order
            if !message.userName.isEmpty && !message.userMessage.isEmpty {
                formattedMessages += "\(message.userName)'s message: \(message.userMessage)\n"
            }
            if !message.replyName.isEmpty && !message.replyMessage.isEmpty {
                formattedMessages += "\(message.replyName)'s reply: \(message.replyMessage)\n"
            }
        }
        
        AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "getFormattedConversationHistory() formatted \(messages.count) messages")
        return formattedMessages
    }
    
    /// Clear all AI training messages from database
    func clearAllMessages() {
        // CRITICAL FIX: Use DatabaseManager instead of direct database access
        DatabaseManager.shared.executeOnDatabaseQueue { db in
            AITrainingMessagesDB.shared.clearAllAITrainingMessages(db: db)
        }
    }
    
    /// Clear all AI training messages synchronously - used by DatabaseCleanupService cleanup
    func clearAllMessagesSync() {
        AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "clearAllMessagesSync() clearing all AI training messages synchronously")
        
        DatabaseManager.shared.executeOnDatabaseQueue { db in
            AITrainingMessagesDB.shared.clearAllAITrainingMessages(db: db)
        }
    }
    
    /// Get total count of all AI training messages
    func getTotalMessageCount() -> Int {
        return DatabaseManager.shared.executeOnDatabaseQueue { db in
            var queryStatement: OpaquePointer?
            let queryStatementString = "SELECT COUNT(*) FROM AITrainingMessages;"
            var count = 0
            
            if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
                if sqlite3_step(queryStatement) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(queryStatement, 0))
                }
            }
            
            sqlite3_finalize(queryStatement)
            return count
        }
    }
    
    /// Check if a chat has any AI training messages
    func hasMessagesForChat(chatId: String) -> Bool {
        return getMessageCountForChat(chatId: chatId) > 0
    }
    
    // MARK: - Private Methods
    
    /// Delete a specific message by ID
    private func deleteMessage(messageId: String) {
        DatabaseManager.shared.executeOnDatabaseQueue { db in
            var deleteStatement: OpaquePointer?
            let deleteStatementString = "DELETE FROM AITrainingMessages WHERE id = ?;"
            
            if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(deleteStatement, 1, (messageId as NSString).utf8String, -1, nil)
                
                if sqlite3_step(deleteStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "deleteMessage() successfully deleted message: \(messageId)")
                } else {
                    AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "deleteMessage() failed to delete message: \(messageId)")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: AITrainingMessageStore", message: "deleteMessage() failed to prepare statement for message: \(messageId)")
            }
            
            sqlite3_finalize(deleteStatement)
        }
    }
    
    /// Get the ID of the oldest message for a specific chat
    private func getOldestMessageId(forChatId chatId: String) -> String? {
        return DatabaseManager.shared.executeOnDatabaseQueue { db in
            var queryStatement: OpaquePointer?
            let queryStatementString = "SELECT id FROM AITrainingMessages WHERE chatId = ? ORDER BY messageTime ASC LIMIT 1;"
            var oldestId: String?
            
            if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(queryStatement, 1, (chatId as NSString).utf8String, -1, nil)
                
                if sqlite3_step(queryStatement) == SQLITE_ROW {
                    if let idPtr = sqlite3_column_text(queryStatement, 0) {
                        oldestId = String(cString: idPtr)
                    }
                }
            }
            
            sqlite3_finalize(queryStatement)
            return oldestId
        }
    }
}