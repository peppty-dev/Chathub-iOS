import Foundation
import SQLite3

struct AITrainingMessage {
    var id: String
    var chatId: String
    var userMessage: String
    var userName: String
    var replyMessage: String
    var replyName: String
    var messageTime: Int
}

class AITrainingMessagesDB {
    
    // CRITICAL FIX: Make AITrainingMessagesDB a proper singleton to prevent multiple instances
    static let shared = AITrainingMessagesDB()
    
    private init() {
        // Table creation will be handled by ensureTableCreated() when called from DatabaseManager
        AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "init() - AITrainingMessagesDB singleton initialized")
    }
    
    // Public method to ensure table is created when database becomes ready
    func ensureTableCreated() {
        // CRITICAL FIX: Use DatabaseManager's centralized queue for all operations
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard db != nil else {
                AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "ensureTableCreated() - Database connection is nil")
                return
            }
            
            self.createAITrainingMessagesTable(db: db)
        }
    }
    
    // Add AITrainingMessages table
    func createAITrainingMessagesTable(db: OpaquePointer?) {
        // This method must be called from the dbQueue
        
        guard let db = db else {
            AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "createAITrainingMessagesTable() - Database connection is nil")
            return
        }
        
        // ANDROID PARITY: Create table only if it doesn't exist to preserve existing data
        let createTableString = """
        CREATE TABLE IF NOT EXISTS AITrainingMessages (
            id TEXT PRIMARY KEY NOT NULL,
            chatId TEXT,
            userMessage TEXT,
            userName TEXT,
            replyMessage TEXT,
            replyName TEXT,
            messageTime INT
        );
        """
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "createAITrainingMessagesTable() - AITrainingMessages table created successfully or already exists")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "createAITrainingMessagesTable() - Failed to create AITrainingMessages table: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createTableStatement)
    }

    // Insert AI training message
    func insertAITrainingMessage(_ msg: AITrainingMessage, db: OpaquePointer?) {
        guard let db = db else {
            AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "insertAITrainingMessage() - Database not ready")
            return
        }
        
        let insertStatementString = "INSERT INTO AITrainingMessages (id, chatId, userMessage, userName, replyMessage, replyName, messageTime) VALUES (?, ?, ?, ?, ?, ?, ?)"
        var insertStatement: OpaquePointer?
        
        AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "insertAITrainingMessage() - Inserting AI training message: \(msg.id)")
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (msg.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (msg.chatId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, (msg.userMessage as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 4, (msg.userName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 5, (msg.replyMessage as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 6, (msg.replyName as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 7, Int32(msg.messageTime))
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "insertAITrainingMessage() - Successfully inserted AI training message: \(msg.id)")
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "insertAITrainingMessage() - Failed to insert AI training message: \(msg.id), error: \(errorMsg)")
            }
        } else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "insertAITrainingMessage() - Failed to prepare statement for AI training message: \(msg.id), error: \(errorMsg)")
        }
        sqlite3_finalize(insertStatement)
    }

    // Fetch AI training messages for a chat
    func fetchAITrainingMessages(forChatId chatId: String, db: OpaquePointer?) -> [AITrainingMessage] {
        guard DatabaseManager.shared.isDatabaseReadyInternal() else {
            AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "fetchAITrainingMessages() - Database not ready")
            return []
        }
        
        let queryStatementString = "SELECT * FROM AITrainingMessages WHERE chatId = ? ORDER BY messageTime DESC"
        
        let result = DatabaseManager.shared.executeReadQuery(
            sql: queryStatementString,
            parameters: [chatId]
        ) { statement in
            var messages: [AITrainingMessage] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let idPtr = sqlite3_column_text(statement, 0),
                      let chatIdPtr = sqlite3_column_text(statement, 1),
                      let userMessagePtr = sqlite3_column_text(statement, 2),
                      let userNamePtr = sqlite3_column_text(statement, 3),
                      let replyMessagePtr = sqlite3_column_text(statement, 4),
                      let replyNamePtr = sqlite3_column_text(statement, 5) else {
                    AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "fetchAITrainingMessages() - Skipping row with NULL values")
                    continue
                }
                
                let id = String(cString: idPtr)
                let chatId = String(cString: chatIdPtr)
                let userMessage = String(cString: userMessagePtr)
                let userName = String(cString: userNamePtr)
                let replyMessage = String(cString: replyMessagePtr)
                let replyName = String(cString: replyNamePtr)
                let messageTime = Int(sqlite3_column_int(statement, 6))
                
                let message = AITrainingMessage(
                    id: id,
                    chatId: chatId,
                    userMessage: userMessage,
                    userName: userName,
                    replyMessage: replyMessage,
                    replyName: replyName,
                    messageTime: messageTime
                )
                messages.append(message)
            }
            
            AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "fetchAITrainingMessages() - Found \(messages.count) AI training messages for chat: \(chatId)")
            return messages
        }
        
        switch result {
        case .success(let messages):
            return messages
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "fetchAITrainingMessages() - Failed to execute query: \(error)")
            return []
        }
    }

    // Delete AI training messages for a chat
    func deleteAITrainingMessages(forChatId chatId: String, db: OpaquePointer?) {
        guard let db = db else {
            AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "deleteAITrainingMessages() - Database not ready")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "deleteAITrainingMessages() - Deleting AI training messages for chat: \(chatId)")
        var deleteStatement: OpaquePointer?
        let deleteStatementString = "DELETE FROM AITrainingMessages WHERE chatId = ?"
        
        if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteStatement, 1, (chatId as NSString).utf8String, -1, nil)
            
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "deleteAITrainingMessages() - Successfully deleted AI training messages for chat: \(chatId)")
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "deleteAITrainingMessages() - Failed to delete AI training messages for chat: \(chatId), error: \(errorMsg)")
            }
        } else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "deleteAITrainingMessages() - Failed to prepare statement for chat: \(chatId), error: \(errorMsg)")
        }
        sqlite3_finalize(deleteStatement)
    }

    // Clear all AI training messages
    func clearAllAITrainingMessages(db: OpaquePointer?) {
        guard let db = db else {
            AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "clearAllAITrainingMessages() - Database not ready")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "clearAllAITrainingMessages() - Clearing all AI training messages")
        var deleteStatement: OpaquePointer?
        let deleteStatementString = "DELETE FROM AITrainingMessages"
        
        if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "clearAllAITrainingMessages() - Successfully cleared all AI training messages")
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "clearAllAITrainingMessages() - Failed to clear AI training messages, error: \(errorMsg)")
            }
        } else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            AppLogger.log(tag: "LOG-APP: AITrainingMessagesDB", message: "clearAllAITrainingMessages() - Failed to prepare statement, error: \(errorMsg)")
        }
        sqlite3_finalize(deleteStatement)
    }
} 