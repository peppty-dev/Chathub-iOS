import Foundation
import SQLite3

// MARK: - MessageData Structure
struct MessageData {
    let messageId: String
    let chatId: String
    let message: String
    let senderId: String
    let image: String
    let sendDate: Int
    let docId: String
    let adAvailable: Int
    let premium: Int
}

class MessagesDB {
    
    // CRITICAL FIX: Make MessagesDB a proper singleton to prevent multiple instances
    static let shared = MessagesDB()
    
    private init() {
        // Table creation will be handled by ensureTableCreated() when called from DatabaseManager
        AppLogger.log(tag: "LOG-APP: MessagesDB", message: "init() - MessagesDB singleton initialized")
    }
    
    // Public method to ensure table is created when database becomes ready
    func ensureTableCreated() {
        // CRITICAL FIX: Use DatabaseManager's centralized queue for all operations
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard db != nil else {
                AppLogger.log(tag: "LOG-APP: MessagesDB", message: "ensureTableCreated() - Database connection is nil")
                return
            }
            
            self.createMessageTable(db: db)
        }
    }
    
    func createMessageTable(db: OpaquePointer?) {
        // This method is called from the dbQueue during initialization.
        // It must NOT contain a readiness check, as that causes a race condition.
        
        guard let db = db else {
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "createMessageTable() - Database connection is nil")
            return
        }
        
        // ANDROID PARITY: Create table only if it doesn't exist to preserve existing data
        let createTableString = """
        CREATE TABLE IF NOT EXISTS Message (
            MessageId TEXT PRIMARY KEY NOT NULL,
            ChatId TEXT,
            Message TEXT,
            SenderId TEXT,
            Image TEXT,
            SendDate INT,
            DocId TEXT,
            AdAvailable INT,
            premium INT);
        """
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: MessagesDB", message: "createMessageTable() - Message table created successfully or already exists")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "createMessageTable() - Failed to create Message table: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    func deleteMessageTable(db: OpaquePointer?) {
        guard let db = db else {
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "deleteMessageTable() - Database connection is nil")
            return
        }
        
        let dropTableString = "DROP TABLE IF EXISTS Message"
        var dropTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: MessagesDB", message: "deleteMessageTable() - Message table deleted successfully")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "deleteMessageTable() - Failed to delete Message table: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(dropTableStatement)
    }
    
    public func deleteMessage(chatId: String, db: OpaquePointer?) {
        guard let db = db else {
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "deleteMessage() - Database not ready")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: MessagesDB", message: "deleteMessage() - Deleting messages for chat: \(chatId)")
        var deleteStatement: OpaquePointer?
        let deleteStatementString = "DELETE FROM Message WHERE ChatId = ?"
        if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteStatement, 1, (chatId as NSString).utf8String, -1, nil)
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: MessagesDB", message: "deleteMessage() - Successfully deleted messages for chat: \(chatId)")
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: MessagesDB", message: "deleteMessage() - Failed to delete messages for chat: \(chatId), error: \(errorMsg)")
            }
        } else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "deleteMessage() - Failed to prepare statement for chat: \(chatId), error: \(errorMsg)")
        }
        sqlite3_finalize(deleteStatement)
    }
    
    // Insert a message into the Message table (for local DB sync)
    func insertMessage(messageId: String, chatId: String, message: String, senderId: String, image: String, sendDate: Int, docId: String, adAvailable: Int, premium: Int, db: OpaquePointer?) {
        guard let db = db else {
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "insertMessage() - Database not ready")
            return
        }
        
        var insertStatement: OpaquePointer?
        let insertStatementString = "INSERT INTO Message (MessageId, ChatId, Message, SenderId, Image, SendDate, DocId, AdAvailable, premium) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
        
        AppLogger.log(tag: "LOG-APP: MessagesDB", message: "insertMessage() - Inserting message: \(messageId)")
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            let MessageId: NSString = messageId as NSString
            let ChatId: NSString = chatId as NSString
            let Message: NSString = message as NSString
            let SenderId: NSString = senderId as NSString
            let Image: NSString = image as NSString
            let DocId: NSString = docId as NSString
            
            sqlite3_bind_text(insertStatement, 1, MessageId.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, ChatId.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, Message.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 4, SenderId.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 5, Image.utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 6, Int32(sendDate))
            sqlite3_bind_text(insertStatement, 7, DocId.utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 8, Int32(adAvailable))
            sqlite3_bind_int(insertStatement, 9, Int32(premium))
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: MessagesDB", message: "insertMessage() - Successfully inserted message: \(messageId)")
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: MessagesDB", message: "insertMessage() - Failed to insert message: \(messageId), error: \(errorMsg)")
            }
        } else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "insertMessage() - Failed to prepare statement for message: \(messageId), error: \(errorMsg)")
        }
        sqlite3_finalize(insertStatement)
    }
    
    // Select messages by chatId for message limit checking
    func selectMessagesByChatId(_ chatId: String) -> [MessageData] {
        let queryStatementString = "SELECT * FROM Message WHERE ChatId = ? ORDER BY SendDate DESC"
        
        AppLogger.log(tag: "LOG-APP: MessagesDB", message: "selectMessagesByChatId() - Starting query for chat: \(chatId)")
        AppLogger.log(tag: "LOG-APP: MessagesDB", message: "selectMessagesByChatId() - SQL: \(queryStatementString)")
        
        let result = DatabaseManager.shared.executeReadQuery(
            sql: queryStatementString,
            parameters: [chatId]
        ) { statement in
            var messages: [MessageData] = []
            var rowCount = 0
            
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "selectMessagesByChatId() - Starting to process rows")
            
            while sqlite3_step(statement) == SQLITE_ROW {
                rowCount += 1
                AppLogger.log(tag: "LOG-APP: MessagesDB", message: "selectMessagesByChatId() - Processing row \(rowCount)")
                
                // Safe string extraction with null checks
                guard let messageIdPtr = sqlite3_column_text(statement, 0),
                      let chatIdPtr = sqlite3_column_text(statement, 1),
                      let messagePtr = sqlite3_column_text(statement, 2),
                      let senderIdPtr = sqlite3_column_text(statement, 3),
                      let imagePtr = sqlite3_column_text(statement, 4),
                      let docIdPtr = sqlite3_column_text(statement, 6) else {
                    AppLogger.log(tag: "LOG-APP: MessagesDB", message: "selectMessagesByChatId() - Skipping row \(rowCount) with NULL values")
                    continue
                }
                
                let messageId = String(cString: messageIdPtr)
                let chatId = String(cString: chatIdPtr)
                let message = String(cString: messagePtr)
                let senderId = String(cString: senderIdPtr)
                let image = String(cString: imagePtr)
                let sendDate = Int(sqlite3_column_int(statement, 5))
                let docId = String(cString: docIdPtr)
                let adAvailable = Int(sqlite3_column_int(statement, 7))
                let premium = Int(sqlite3_column_int(statement, 8))
                
                AppLogger.log(tag: "LOG-APP: MessagesDB", message: "selectMessagesByChatId() - Row \(rowCount): messageId=\(messageId), chatId=\(chatId), message=\(message.prefix(20))..., senderId=\(senderId)")
                
                let msgData = MessageData(
                    messageId: messageId,
                    chatId: chatId,
                    message: message,
                    senderId: senderId,
                    image: image,
                    sendDate: sendDate,
                    docId: docId,
                    adAvailable: adAvailable,
                    premium: premium
                )
                messages.append(msgData)
            }
            
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "selectMessagesByChatId() - Processed \(rowCount) total rows, returning \(messages.count) messages")
            return messages
        }
        
        switch result {
        case .success(let messages):
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "selectMessagesByChatId() - SUCCESS: Returning \(messages.count) messages for chat: \(chatId)")
            return messages
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "selectMessagesByChatId() - FAILURE: Failed to execute query for chat: \(chatId), error: \(error)")
            return []
        }
    }
    
    // Debug method to check total message count in database
    func getTotalMessageCount() -> Int {
        let queryStatementString = "SELECT COUNT(*) FROM Message"
        
        AppLogger.log(tag: "LOG-APP: MessagesDB", message: "getTotalMessageCount() - Checking total messages in database")
        
        let result = DatabaseManager.shared.executeReadQuery(
            sql: queryStatementString,
            parameters: []
        ) { statement in
            var count = 0
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
            return count
        }
        
        switch result {
        case .success(let count):
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "getTotalMessageCount() - Total messages in database: \(count)")
            return count
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "getTotalMessageCount() - Failed to get count: \(error)")
            return 0
        }
    }
    
    // Debug method to get all chat IDs in database
    func getAllChatIds() -> [String] {
        let queryStatementString = "SELECT DISTINCT ChatId FROM Message"
        
        AppLogger.log(tag: "LOG-APP: MessagesDB", message: "getAllChatIds() - Getting all chat IDs from database")
        
        let result = DatabaseManager.shared.executeReadQuery(
            sql: queryStatementString,
            parameters: []
        ) { statement in
            var chatIds: [String] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let chatIdPtr = sqlite3_column_text(statement, 0) {
                    let chatId = String(cString: chatIdPtr)
                    chatIds.append(chatId)
                }
            }
            
            return chatIds
        }
        
        switch result {
        case .success(let chatIds):
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "getAllChatIds() - Found chat IDs: \(chatIds)")
            return chatIds
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: MessagesDB", message: "getAllChatIds() - Failed to get chat IDs: \(error)")
            return []
        }
    }
} 