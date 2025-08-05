import Foundation
import SQLite3

struct Chat {
    var ChatId : String
    var UserId : String
    var ProfileImage : String
    var Name: String
    var Lastsentby :  String
    var Gender : String
    var DeviceId : String
    var LastTimeStamp : Date
    var newmessage : Bool
    var inbox : Int // Maps directly to database Inbox field: 0 = regular chat, 1 = inbox chat
    var type: String
    var lastMessageSentByUserId: String? // Android parity: user_last_msg_user_id
    
    // Computed property for inbox status (Android parity)
    var isInbox: Bool {
        return inbox == 1  // Direct mapping to database Inbox field
    }
}



class ChatsDB {
    
    // CRITICAL FIX: Make ChatsDB a proper singleton to prevent multiple instances
    static let shared = ChatsDB()
    
    private init() {
        // Table creation will be handled by ensureTablesCreated() when called from DatabaseManager
        AppLogger.log(tag: "LOG-APP: ChatsDB", message: "init() - ChatsDB singleton initialized")
    }
    
    deinit {
        AppLogger.log(tag: "LOG-APP: ChatsDB", message: "deinit() - ChatsDB singleton cleanup")
        // Clean up any resources if needed
    }
    
    // Public method to ensure tables are created when database becomes ready
    func ensureTablesCreated() {
        // CRITICAL FIX: Use DatabaseManager's centralized queue for all operations
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard db != nil else {
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "ensureTablesCreated() - Database connection is nil")
                return
            }
            
            self.createtable(db: db)
            self.migrateToAddLastMessageSentByUserId(db: db)
        }
    }
    
    private func createtable(db: OpaquePointer?) {
        guard let db = db else {
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "createtable() - Database connection is nil")
            return
        }
        
        // ANDROID PARITY: Create table only if it doesn't exist to preserve existing data
        let createTableString = """
        CREATE TABLE IF NOT EXISTS ChatTable (
            ChatId TEXT PRIMARY KEY NOT NULL,
            UserId TEXT,
            Image TEXT,
            UserName TEXT,
            Gender TEXT,
            Lastsentby TEXT,
            DeviceId TEXT,
            LastTimeStamp INT,
            Inbox INT,
            NewMessage INT,
            Type TEXT,
            LastMessageSentByUserId TEXT);
        """
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "createtable() - ChatTable created successfully or already exists")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "createtable() - Failed to create ChatTable: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    func DeleteChatTable(ChatId: String) {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "DeleteChatTable() - Database connection is nil")
                return
            }
            
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "DeleteChatTable() - Deleting chat and all related data: \(ChatId)")
            
            // Delete messages for this chat from MessagesDB
            MessagesDB.shared.deleteMessage(chatId: ChatId, db: db)
            
            // Delete AI training messages for this chat from AITrainingMessagesDB
            AITrainingMessagesDB.shared.deleteAITrainingMessages(forChatId: ChatId, db: db)
            
            // Delete the chat itself
            var deleteStatement: OpaquePointer?
            let deleteStatementString = "DELETE FROM ChatTable WHERE ChatId = ?"
            if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(deleteStatement, 1, (ChatId as NSString).utf8String, -1, nil)
                if sqlite3_step(deleteStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "DeleteChatTable() - Successfully deleted chat: \(ChatId)")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "DeleteChatTable() - Failed to delete chat: \(ChatId), error: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "DeleteChatTable() - Failed to prepare statement for chat: \(ChatId), error: \(errorMsg)")
            }
            sqlite3_finalize(deleteStatement)
            
            // CRITICAL FIX: Update view models on main thread with proper serialization
            let chatData = self.queryInternal(db: db)
            let inboxData = self.inboxqueryInternal(db: db)
            
            DispatchQueue.main.async {
                // MODERN SWIFTUI PATTERN: Use NotificationCenter instead of global view models
                // Notify SwiftUI views that chat data has changed
                NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
                NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "DeleteChatTable() - Posted data change notifications for SwiftUI views")
            }
        }
    }
    
    func DeleteChatTable() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "DeleteChatTable() - Database not ready")
                return
            }
            
            let deleteStatementString = "DELETE FROM ChatTable"
            var deleteStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
                if sqlite3_step(deleteStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "DeleteChatTable() - Successfully deleted all chats")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "DeleteChatTable() - Failed to delete chats, error: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "DeleteChatTable() - Failed to prepare statement, error: \(errorMsg)")
            }
            sqlite3_finalize(deleteStatement)
            
            // MODERN SWIFTUI PATTERN: Use NotificationCenter instead of global view models
            DispatchQueue.main.async {
                // Notify SwiftUI views that chat data has changed
                NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
                NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "DeleteChatTable() - Posted data change notifications for SwiftUI views")
            }
        }
    }
   
    func query() -> [Chat] {
        return DatabaseManager.shared.executeOnDatabaseQueue { db in
            return self.queryInternal(db: db)
        }
    }
    
    private func queryInternal(db: OpaquePointer?) -> [Chat] {
        // ANDROID PARITY: Exclude inbox chats from regular chats query (matching Android's WHERE inbox = 0)
        let queryStatementString = "SELECT * FROM ChatTable WHERE Inbox = 0 ORDER BY LastTimeStamp DESC"
        
        AppLogger.log(tag: "LOG-APP: ChatsDB", message: "queryInternal() - Starting chat query with SQL: \(queryStatementString)")
        
        let result = DatabaseManager.shared.executeReadQuery(
            sql: queryStatementString,
            parameters: []
        ) { statement in
            var psns: [Chat] = []
            var rowCount = 0
            
            while sqlite3_step(statement) == SQLITE_ROW {
                rowCount += 1
                // Safe string extraction with null checks
                guard let idPtr = sqlite3_column_text(statement, 0),
                      let documentidPtr = sqlite3_column_text(statement, 1),
                      let profileimagePtr = sqlite3_column_text(statement, 2),
                      let titlePtr = sqlite3_column_text(statement, 3),
                      let genderPtr = sqlite3_column_text(statement, 4),
                      let lastsentbyPtr = sqlite3_column_text(statement, 5),
                      let deviceIdPtr = sqlite3_column_text(statement, 6),
                      let typePtr = sqlite3_column_text(statement, 10) else {
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "queryInternal() - Skipping row \(rowCount) with NULL values")
                    continue
                }
                
                let id = String(cString: idPtr)
                let documentid = String(cString: documentidPtr)
                let profileimage = String(cString: profileimagePtr)
                let title = String(cString: titlePtr)
                let gender = String(cString: genderPtr)
                let lastsentby = String(cString: lastsentbyPtr)
                let deviceId = String(cString: deviceIdPtr)
                let type = String(cString: typePtr)
                
                // Read LastMessageSentByUserId (can be NULL)
                var lastMessageSentByUserId: String? = nil
                if let lastMessageSentByUserIdPtr = sqlite3_column_text(statement, 11) {
                    lastMessageSentByUserId = String(cString: lastMessageSentByUserIdPtr)
                }
                
                let aDates = TimeInterval(sqlite3_column_int(statement, 7))
                let inbox = Int(sqlite3_column_int(statement, 8))  // Read Inbox field from database
                let newmess = Int(sqlite3_column_int(statement, 9))
                let aDate = NSDate(timeIntervalSince1970: aDates)
                
                var newmes = false
                if newmess == 1 {
                    newmes = true
                }
                
                // Direct mapping: database Inbox field → Chat.inbox field
                let userdata =  Chat(ChatId : id, UserId: documentid, ProfileImage : profileimage, Name: title , Lastsentby : lastsentby, Gender : gender , DeviceId : deviceId, LastTimeStamp : aDate as Date, newmessage: newmes, inbox: inbox, type: type, lastMessageSentByUserId: lastMessageSentByUserId)
                psns.append(userdata)
            }
            
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "queryInternal() - Successfully loaded \(psns.count) chats from \(rowCount) rows")
            return psns
        }
        
        switch result {
        case .success(let chats):
            return chats
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "queryInternal() - Failed to execute query: \(error)")
            return []
        }
    }
    
    func inboxquery() -> [Chat] {
        return DatabaseManager.shared.executeOnDatabaseQueue { db in
            return self.inboxqueryInternal(db: db)
        }
    }
    
    private func inboxqueryInternal(db: OpaquePointer?) -> [Chat] {
        let queryStatementString = "SELECT * FROM ChatTable WHERE Inbox = 1 ORDER BY LastTimeStamp DESC"
        
        AppLogger.log(tag: "LOG-APP: ChatsDB", message: "inboxqueryInternal() - Starting inbox query")
        
        let result = DatabaseManager.shared.executeReadQuery(
            sql: queryStatementString,
            parameters: []
        ) { statement in
            var psns: [Chat] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                // Safe string extraction with null checks
                guard let idPtr = sqlite3_column_text(statement, 0),
                      let documentidPtr = sqlite3_column_text(statement, 1),
                      let profileimagePtr = sqlite3_column_text(statement, 2),
                      let titlePtr = sqlite3_column_text(statement, 3),
                      let genderPtr = sqlite3_column_text(statement, 4),
                      let lastsentbyPtr = sqlite3_column_text(statement, 5),
                      let deviceIdPtr = sqlite3_column_text(statement, 6),
                      let typePtr = sqlite3_column_text(statement, 10) else {
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "inboxqueryInternal() - Skipping row with NULL values")
                    continue
                }
                
                let id = String(cString: idPtr)
                let documentid = String(cString: documentidPtr)
                let profileimage = String(cString: profileimagePtr)
                let title = String(cString: titlePtr)
                let gender = String(cString: genderPtr)
                let lastsentby = String(cString: lastsentbyPtr)
                let deviceId = String(cString: deviceIdPtr)
                let type = String(cString: typePtr)
                
                // Read LastMessageSentByUserId (can be NULL)
                var lastMessageSentByUserId: String? = nil
                if let lastMessageSentByUserIdPtr = sqlite3_column_text(statement, 11) {
                    lastMessageSentByUserId = String(cString: lastMessageSentByUserIdPtr)
                }
                
                let aDates = TimeInterval(sqlite3_column_int(statement, 7))
                let inbox = Int(sqlite3_column_int(statement, 8))  // Read Inbox field from database
                let newmess = Int(sqlite3_column_int(statement, 9))
                let aDate = NSDate(timeIntervalSince1970: aDates)
                
                var newmes = false
                if newmess == 1 {
                    newmes = true
                }
                
                // Direct mapping: database Inbox field → Chat.inbox field (should be 1 for inbox chats)
                let userdata =  Chat(ChatId : id, UserId: documentid, ProfileImage : profileimage, Name: title , Lastsentby : lastsentby, Gender : gender , DeviceId : deviceId, LastTimeStamp : aDate as Date, newmessage: newmes, inbox: inbox, type: type, lastMessageSentByUserId: lastMessageSentByUserId)
                psns.append(userdata)
            }
            
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "inboxqueryInternal() - Completed, returning \(psns.count) inbox chats")
            return psns
        }
        
        switch result {
        case .success(let chats):
            return chats
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "inboxqueryInternal() - Failed to execute query: \(error)")
            return []
        }
    }
    
    func singlequary(ChatId : String) -> [Chat] {
        let queryStatementString = "SELECT * FROM ChatTable WHERE ChatId = ? ORDER BY LastTimeStamp DESC"
        
        AppLogger.log(tag: "LOG-APP: ChatsDB", message: "singlequary() - Querying chat: \(ChatId)")
        
        let result = DatabaseManager.shared.executeReadQuery(
            sql: queryStatementString,
            parameters: [ChatId]
        ) { statement in
            var psns: [Chat] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                // Safe string extraction with null checks
                guard let idPtr = sqlite3_column_text(statement, 0),
                      let documentidPtr = sqlite3_column_text(statement, 1),
                      let profileimagePtr = sqlite3_column_text(statement, 2),
                      let titlePtr = sqlite3_column_text(statement, 3),
                      let genderPtr = sqlite3_column_text(statement, 4),
                      let lastsentbyPtr = sqlite3_column_text(statement, 5),
                      let deviceIdPtr = sqlite3_column_text(statement, 6),
                      let typePtr = sqlite3_column_text(statement, 10) else {
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "singlequary() - Skipping row with NULL values")
                    continue
                }
                
                let id = String(cString: idPtr)
                let documentid = String(cString: documentidPtr)
                let profileimage = String(cString: profileimagePtr)
                let title = String(cString: titlePtr)
                let gender = String(cString: genderPtr)
                let lastsentby = String(cString: lastsentbyPtr)
                let deviceId = String(cString: deviceIdPtr)
                let type = String(cString: typePtr)
                
                // Read LastMessageSentByUserId (can be NULL)
                var lastMessageSentByUserId: String? = nil
                if let lastMessageSentByUserIdPtr = sqlite3_column_text(statement, 11) {
                    lastMessageSentByUserId = String(cString: lastMessageSentByUserIdPtr)
                }
                
                let aDates = TimeInterval(sqlite3_column_int(statement, 7))
                let inbox = Int(sqlite3_column_int(statement, 8))
                let newmess = Int(sqlite3_column_int(statement, 9))
                let aDate = NSDate(timeIntervalSince1970: aDates)
                
                var newmes = false
                if newmess == 1 {
                    newmes = true
                }
                if  inbox == 0 {
                    let userdata =  Chat(ChatId : id, UserId: documentid, ProfileImage : profileimage, Name: title , Lastsentby : lastsentby, Gender : gender , DeviceId : deviceId, LastTimeStamp : aDate as Date, newmessage: newmes, inbox: 0, type: type, lastMessageSentByUserId: lastMessageSentByUserId)
                    psns.append(userdata)
                }
            }
            
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "singlequary() - Completed, returning \(psns.count) chats")
            return psns
        }
        
        switch result {
        case .success(let chats):
            return chats
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "singlequary() - Failed to execute query: \(error)")
            return []
        }
    }
    
    func inboxnewquery() -> Chat? {
        let queryStatementString = "SELECT * FROM ChatTable WHERE Inbox = 1 AND NewMessage = 1 ORDER BY LastTimeStamp DESC LIMIT 1"
        
        AppLogger.log(tag: "LOG-APP: ChatsDB", message: "inboxnewquery() - Starting new inbox message query")
        
        let result = DatabaseManager.shared.executeReadQuery(
            sql: queryStatementString,
            parameters: []
        ) { statement in
            var psns: Chat? = nil
            
            while sqlite3_step(statement) == SQLITE_ROW {
                // Safe string extraction with null checks
                guard let idPtr = sqlite3_column_text(statement, 0),
                      let documentidPtr = sqlite3_column_text(statement, 1),
                      let profileimagePtr = sqlite3_column_text(statement, 2),
                      let titlePtr = sqlite3_column_text(statement, 3),
                      let genderPtr = sqlite3_column_text(statement, 4),
                      let lastsentbyPtr = sqlite3_column_text(statement, 5),
                      let deviceIdPtr = sqlite3_column_text(statement, 6),
                      let typePtr = sqlite3_column_text(statement, 10) else {
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "inboxnewquery() - Skipping row with NULL values")
                    continue
                }
                
                let id = String(cString: idPtr)
                let documentid = String(cString: documentidPtr)
                let profileimage = String(cString: profileimagePtr)
                let title = String(cString: titlePtr)
                let gender = String(cString: genderPtr)
                let lastsentby = String(cString: lastsentbyPtr)
                let deviceId = String(cString: deviceIdPtr)
                let type = String(cString: typePtr)
                
                // Read LastMessageSentByUserId (can be NULL)
                var lastMessageSentByUserId: String? = nil
                if let lastMessageSentByUserIdPtr = sqlite3_column_text(statement, 11) {
                    lastMessageSentByUserId = String(cString: lastMessageSentByUserIdPtr)
                }
                
                let aDates = TimeInterval(sqlite3_column_int(statement, 7))
                let inbox = Int(sqlite3_column_int(statement, 8))  // Read Inbox field from database
                let newmess = Int(sqlite3_column_int(statement, 9))
                let aDate = NSDate(timeIntervalSince1970: aDates)
                
                if  newmess == 1 {
                    // Direct mapping: database Inbox field → Chat.inbox field (should be 1 for inbox chats)
                    psns =  Chat(ChatId : id, UserId: documentid, ProfileImage : profileimage, Name: title , Lastsentby : lastsentby, Gender : gender , DeviceId : deviceId, LastTimeStamp : aDate as Date, newmessage: true, inbox: inbox, type: type, lastMessageSentByUserId: lastMessageSentByUserId)
                }
            }
            
            return psns
        }
        
        switch result {
        case .success(let chat):
            return chat
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "inboxnewquery() - Failed to execute query: \(error)")
            return nil
        }
    }
    
    func insert(ChatId : String, UserId : String, Image : String, UserName : String, Gender : String, Lastsentby : String, DeviceId : String, LastTimeStamp : Date, NewMessage : Int, Group : Int, Inbox : Int, Type: String, LastMessageSentByUserId: String? = nil) {
        // CRITICAL FIX: Validate essential chat data before insertion
        guard !ChatId.isEmpty && ChatId != "null" && 
              !UserId.isEmpty && UserId != "null" &&
              !UserName.isEmpty && UserName != "null" && UserName.trimmingCharacters(in: .whitespaces) != "" else {
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insert() REJECTING invalid chat data - ChatId: '\(ChatId)', UserId: '\(UserId)', UserName: '\(UserName)'")
            return
        }
        
        // Additional validation: Check for meaningful user name
        if UserName.trimmingCharacters(in: .whitespaces).isEmpty {
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insert() REJECTING chat with empty/whitespace-only UserName: '\(UserName)'")
            return
        }
        
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insert() - Database not ready")
                return
            }
            
            var insertStatement: OpaquePointer?
            let insertStatementString = "INSERT INTO ChatTable (ChatId, UserId, Image, UserName, Gender, Lastsentby, DeviceId, LastTimeStamp, Inbox, NewMessage, Type, LastMessageSentByUserId) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insert() - Inserting chat: \(ChatId)")
            
            if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
                let Chatid : NSString = ChatId as NSString
                let Userid : NSString = UserId as NSString
                let image : NSString = Image as NSString
                let Username : NSString = UserName as NSString
                let gender : NSString = Gender as NSString
                let lastsentby : NSString = Lastsentby as NSString
                let Deviceid : NSString = DeviceId as NSString
                let type : NSString = Type as NSString
                
                sqlite3_bind_text(insertStatement, 1, Chatid.utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 2, Userid.utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 3, image.utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 4, Username.utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 5, gender.utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 6, lastsentby.utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 7, Deviceid.utf8String, -1, nil)
                sqlite3_bind_int(insertStatement, 8, Int32(LastTimeStamp.timeIntervalSince1970))
                sqlite3_bind_int(insertStatement, 9, Int32(Inbox))
                sqlite3_bind_int(insertStatement, 10, Int32(NewMessage))
                sqlite3_bind_text(insertStatement, 11, type.utf8String, -1, nil)
                
                // Bind LastMessageSentByUserId (can be NULL)
                if let lastMessageSentByUserId = LastMessageSentByUserId {
                    sqlite3_bind_text(insertStatement, 12, (lastMessageSentByUserId as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertStatement, 12)
                }
                
                if sqlite3_step(insertStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insert() - Successfully inserted chat: \(ChatId)")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insert() - Failed to insert chat: \(ChatId), error: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insert() - Failed to prepare statement for chat: \(ChatId), error: \(errorMsg)")
            }
            sqlite3_finalize(insertStatement)
            
            // CRITICAL FIX: Update view models on main thread with proper serialization
            let chatData = self.queryInternal(db: db)
            let inboxData = (Inbox == 1) ? self.inboxqueryInternal(db: db) : []
            
            DispatchQueue.main.async {
                // MODERN SWIFTUI PATTERN: Use NotificationCenter instead of global view models
                // Notify SwiftUI views that chat data has changed
                NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insert() - Posted chatTableDataChanged notification for SwiftUI views")
                
                if Inbox == 1 {
                    NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insert() - Posted inboxTableDataChanged notification for SwiftUI views")
                }
            }
        }
    }
    
    func update(LastTimeStamp : Date, NewMessage : Int, ChatId : String, Lastsentby : String, Inbox : Int, LastMessageSentByUserId: String? = nil) {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "update() - Database not ready")
                return
            }
            
            var updateStatement: OpaquePointer?
            let lasttime = Int32(LastTimeStamp.timeIntervalSince1970)
            
            // Use parameterized query to prevent SQL injection and syntax errors
            let updateStatementString = "UPDATE ChatTable SET LastTimeStamp = ?, Lastsentby = ?, NewMessage = ?, Inbox = ?, LastMessageSentByUserId = ? WHERE ChatId = ?"
            
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "update() - Updating chat: \(ChatId)")
            
            if sqlite3_prepare_v2(db, updateStatementString, -1, &updateStatement, nil) == SQLITE_OK {
                // Bind parameters safely
                sqlite3_bind_int(updateStatement, 1, lasttime)
                sqlite3_bind_text(updateStatement, 2, (Lastsentby as NSString).utf8String, -1, nil)
                sqlite3_bind_int(updateStatement, 3, Int32(NewMessage))
                sqlite3_bind_int(updateStatement, 4, Int32(Inbox))
                
                // Bind LastMessageSentByUserId (can be NULL)
                if let lastMessageSentByUserId = LastMessageSentByUserId {
                    sqlite3_bind_text(updateStatement, 5, (lastMessageSentByUserId as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(updateStatement, 5)
                }
                
                sqlite3_bind_text(updateStatement, 6, (ChatId as NSString).utf8String, -1, nil)
                
                if sqlite3_step(updateStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "update() - Successfully updated chat: \(ChatId)")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "update() - Failed to update chat: \(ChatId), error: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "update() - Failed to prepare statement for chat: \(ChatId), error: \(errorMsg)")
            }
            sqlite3_finalize(updateStatement)
            
            // CRITICAL FIX: Update view models on main thread with proper serialization
            let chatData = self.queryInternal(db: db)
            let inboxData = self.inboxqueryInternal(db: db)
            
            DispatchQueue.main.async {
                // MODERN SWIFTUI PATTERN: Use NotificationCenter instead of global view models
                // Notify SwiftUI views that chat data has changed
                NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
                NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "update() - Posted data change notifications for SwiftUI views")
            }
        }
    }
    
    func delete(ChatId : String) {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "delete() - Database not ready")
                return
            }
            
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "delete() - Deleting chat: \(ChatId)")
            var deleteStatement: OpaquePointer?
            let deleteStatementString = "DELETE FROM ChatTable WHERE ChatId = ?"
            if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(deleteStatement, 1, (ChatId as NSString).utf8String, -1, nil)
                if sqlite3_step(deleteStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "delete() - Successfully deleted chat: \(ChatId)")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "delete() - Failed to delete chat: \(ChatId), error: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "delete() - Failed to prepare statement for chat: \(ChatId), error: \(errorMsg)")
            }
            sqlite3_finalize(deleteStatement)
            
            // CRITICAL FIX: Update view models on main thread with proper serialization
            let chatData = self.queryInternal(db: db)
            let inboxData = self.inboxqueryInternal(db: db)
            
            DispatchQueue.main.async {
                // MODERN SWIFTUI PATTERN: Use NotificationCenter instead of global view models
                // Notify SwiftUI views that chat data has changed
                NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
                NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "delete() - Posted data change notifications for SwiftUI views")
            }
        }
    }
        



    


    // Migration to add LastMessageSentByUserId column to existing databases
    private func migrateToAddLastMessageSentByUserId(db: OpaquePointer?) {
        // This method must be called from the dbQueue
        let tableName = "ChatTable"
        let columnName = "LastMessageSentByUserId"
        
        // Check if column already exists
        let checkColumnQuery = "PRAGMA table_info(\(tableName))"
        var checkStatement: OpaquePointer?
        var columnExists = false
        
        if sqlite3_prepare_v2(db, checkColumnQuery, -1, &checkStatement, nil) == SQLITE_OK {
            while sqlite3_step(checkStatement) == SQLITE_ROW {
                if let columnNamePtr = sqlite3_column_text(checkStatement, 1) {
                    let existingColumnName = String(cString: columnNamePtr)
                    if existingColumnName == columnName {
                        columnExists = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(checkStatement)
        
        // Add column if it doesn't exist
        if !columnExists {
            let addColumnQuery = "ALTER TABLE \(tableName) ADD COLUMN \(columnName) TEXT"
            var addColumnStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, addColumnQuery, -1, &addColumnStatement, nil) == SQLITE_OK {
                if sqlite3_step(addColumnStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "migrateToAddLastMessageSentByUserId() - Successfully added \(columnName) column")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "migrateToAddLastMessageSentByUserId() - Failed to add column: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "migrateToAddLastMessageSentByUserId() - Failed to prepare statement: \(errorMsg)")
            }
            sqlite3_finalize(addColumnStatement)
        } else {
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "migrateToAddLastMessageSentByUserId() - Column already exists")
        }
    }

    // MARK: - ENHANCEMENT: Bulk Operations using new DatabaseManager capabilities
    
    /// Bulk insert chats using JSON1 for improved performance
    func bulkInsertChats(_ chats: [Chat]) -> Bool {
        guard !chats.isEmpty else { return true }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Convert Chat objects to Codable format for JSON encoding
        struct ChatData: Codable {
            let ChatId: String
            let UserId: String
            let Image: String
            let UserName: String
            let Gender: String
            let Lastsentby: String
            let DeviceId: String
            let LastTimeStamp: Int
            let Inbox: Int
            let NewMessage: Int
            let GroupDetail: Int
            let ChatType: String
            let LastMessageSentByUserId: String
        }
        
        let chatData = chats.map { chat in
            ChatData(
                ChatId: chat.ChatId,
                UserId: chat.UserId,
                Image: chat.ProfileImage,
                UserName: chat.Name,
                Gender: chat.Gender,
                Lastsentby: chat.Lastsentby,
                DeviceId: chat.DeviceId,
                LastTimeStamp: Int(chat.LastTimeStamp.timeIntervalSince1970),
                Inbox: chat.inbox,
                NewMessage: chat.newmessage ? 1 : 0,
                GroupDetail: chat.inbox,
                ChatType: chat.type,
                LastMessageSentByUserId: chat.lastMessageSentByUserId ?? ""
            )
        }
        
        let columns = [
            "ChatId", "UserId", "Image", "UserName", "Gender", "Lastsentby", 
            "DeviceId", "LastTimeStamp", "Inbox", "NewMessage", "GroupDetail", 
            "Type", "LastMessageSentByUserId"
        ]
        
        let result = DatabaseManager.shared.bulkInsert(
            items: chatData,
            table: "ChatTable",
            columns: columns
        )
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        switch result {
        case .success:
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "bulkInsertChats() - Successfully inserted \(chats.count) chats in \(String(format: "%.4f", executionTime))s")
            
            // Update ViewModels on main thread
            DispatchQueue.main.async {
                _ = self.query()
                _ = self.inboxquery()
                
                // MODERN SWIFTUI PATTERN: Use NotificationCenter instead of global view models
                // Notify SwiftUI views that chat data has changed
                NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
                NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
            }
            
            return true
            
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "bulkInsertChats() - Failed to insert chats: \(error)")
            return false
        }
    }
    
    /// Bulk update chats using JSON1 for improved performance
    func bulkUpdateChats(_ chats: [Chat]) -> Bool {
        guard !chats.isEmpty else { return true }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Convert Chat objects to Codable format for JSON encoding
        struct ChatUpdateData: Codable {
            let ChatId: String
            let UserId: String
            let Image: String
            let UserName: String
            let Gender: String
            let Lastsentby: String
            let DeviceId: String
            let LastTimeStamp: Int
            let Inbox: Int
            let NewMessage: Int
            let GroupDetail: Int
            let ChatType: String
            let LastMessageSentByUserId: String
        }
        
        let chatData = chats.map { chat in
            ChatUpdateData(
                ChatId: chat.ChatId,
                UserId: chat.UserId,
                Image: chat.ProfileImage,
                UserName: chat.Name,
                Gender: chat.Gender,
                Lastsentby: chat.Lastsentby,
                DeviceId: chat.DeviceId,
                LastTimeStamp: Int(chat.LastTimeStamp.timeIntervalSince1970),
                Inbox: chat.inbox,
                NewMessage: chat.newmessage ? 1 : 0,
                GroupDetail: chat.inbox,
                ChatType: chat.type,
                LastMessageSentByUserId: chat.lastMessageSentByUserId ?? ""
            )
        }
        
        let updateColumns = [
            "UserId", "Image", "UserName", "Gender", "Lastsentby", 
            "DeviceId", "LastTimeStamp", "Inbox", "NewMessage", "GroupDetail", 
            "Type", "LastMessageSentByUserId"
        ]
        
        let result = DatabaseManager.shared.bulkUpdate(
            items: chatData,
            table: "ChatTable",
            keyColumn: "ChatId",
            updateColumns: updateColumns
        )
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        switch result {
        case .success:
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "bulkUpdateChats() - Successfully updated \(chats.count) chats in \(String(format: "%.4f", executionTime))s")
            
            // Update ViewModels on main thread
            DispatchQueue.main.async {
                _ = self.query()
                _ = self.inboxquery()
                
                // MODERN SWIFTUI PATTERN: Use NotificationCenter instead of global view models
                // Notify SwiftUI views that chat data has changed
                NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
                NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
            }
            
            return true
            
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "bulkUpdateChats() - Failed to update chats: \(error)")
            return false
        }
    }
    
    /// Bulk delete chats using JSON1 for improved performance
    func bulkDeleteChats(_ chatIds: [String]) -> Bool {
        guard !chatIds.isEmpty else { return true }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = DatabaseManager.shared.bulkDelete(
            ids: chatIds,
            table: "ChatTable",
            keyColumn: "ChatId"
        )
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        switch result {
        case .success:
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "bulkDeleteChats() - Successfully deleted \(chatIds.count) chats in \(String(format: "%.4f", executionTime))s")
            
            // Update ViewModels on main thread
            DispatchQueue.main.async {
                _ = self.query()
                _ = self.inboxquery()
                
                // MODERN SWIFTUI PATTERN: Use NotificationCenter instead of global view models
                // Notify SwiftUI views that chat data has changed
                NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
                NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
            }
            
            return true
            
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "bulkDeleteChats() - Failed to delete chats: \(error)")
            return false
        }
    }
    
    /// Enhanced insert with transaction support
    func insertChatWithTransaction(_ chat: Chat) -> Bool {
        let result = DatabaseManager.shared.executeInTransaction { db in
            guard let db = db else { throw DatabaseError.connectionError }
            
            let insertSQL = """
            INSERT OR REPLACE INTO ChatTable 
            (ChatId, UserId, Image, UserName, Gender, Lastsentby, DeviceId, LastTimeStamp, Inbox, NewMessage, GroupDetail, Type, LastMessageSentByUserId) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            let prepareResult = sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil)
            
            guard prepareResult == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insertChatWithTransaction() - Failed to prepare statement: \(error)")
                throw DatabaseError.statementError
            }
            
            defer { sqlite3_finalize(statement) }
            
            // Bind parameters
            sqlite3_bind_text(statement, 1, chat.ChatId, -1, nil)
            sqlite3_bind_text(statement, 2, chat.UserId, -1, nil)
            sqlite3_bind_text(statement, 3, chat.ProfileImage, -1, nil)
            sqlite3_bind_text(statement, 4, chat.Name, -1, nil)
            sqlite3_bind_text(statement, 5, chat.Gender, -1, nil)
            sqlite3_bind_text(statement, 6, chat.Lastsentby, -1, nil)
            sqlite3_bind_text(statement, 7, chat.DeviceId, -1, nil)
            sqlite3_bind_int64(statement, 8, Int64(chat.LastTimeStamp.timeIntervalSince1970))
            sqlite3_bind_int(statement, 9, Int32(chat.inbox))
            sqlite3_bind_int(statement, 10, chat.newmessage ? 1 : 0)
            sqlite3_bind_int(statement, 11, Int32(chat.inbox))
            sqlite3_bind_text(statement, 12, chat.type, -1, nil)
            
            if let lastMessageUserId = chat.lastMessageSentByUserId {
                sqlite3_bind_text(statement, 13, lastMessageUserId, -1, nil)
            } else {
                sqlite3_bind_null(statement, 13)
            }
            
            let stepResult = sqlite3_step(statement)
            if stepResult != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insertChatWithTransaction() - Failed to execute: \(error)")
                throw DatabaseError.executionError
            }
            
            return true
        }
        
        switch result {
        case .success(let success):
            if success {
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insertChatWithTransaction() - Successfully inserted chat: \(chat.ChatId)")
                
                // Update ViewModels on main thread
                DispatchQueue.main.async {
                    let allChats = self.query()
                    let inboxChats = self.inboxquery()
                    
                    // MODERN SWIFTUI PATTERN: Use NotificationCenter instead of global view models
                    // Notify SwiftUI views that chat data has changed
                    NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
                    NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
                }
            }
            return success
            
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "insertChatWithTransaction() - Failed to insert chat: \(error)")
            return false
        }
    }
    
    /// Perform database maintenance for chat tables
    func performMaintenance() {
        AppLogger.log(tag: "LOG-APP: ChatsDB", message: "performMaintenance() - Starting chat table maintenance")
        
        // Schedule background checkpoint
        DatabaseManager.shared.scheduleBackgroundCheckpoint()
        
        // Clean up old chats (older than 30 days) in background
        DispatchQueue.global(qos: .background).async {
            self.cleanupOldChats()
        }
    }
    
    private func cleanupOldChats() {
        let thirtyDaysAgo = Date().timeIntervalSince1970 - (30 * 24 * 60 * 60)
        
        let result = DatabaseManager.shared.executeInTransaction { db in
            guard let db = db else { throw DatabaseError.connectionError }
            
            let deleteSQL = "DELETE FROM ChatTable WHERE LastTimeStamp < ? AND Type != 'important'"
            
            var statement: OpaquePointer?
            let prepareResult = sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil)
            
            guard prepareResult == SQLITE_OK else {
                throw DatabaseError.statementError
            }
            
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_int64(statement, 1, Int64(thirtyDaysAgo))
            
            let stepResult = sqlite3_step(statement)
            if stepResult != SQLITE_DONE {
                throw DatabaseError.executionError
            }
            
            let deletedCount = sqlite3_changes(db)
            return Int(deletedCount)
        }
        
        switch result {
        case .success(let deletedCount):
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "cleanupOldChats() - Cleaned up \(deletedCount) old chats")
            
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: ChatsDB", message: "cleanupOldChats() - Failed to cleanup old chats: \(error)")
        }
    }

    /// Clean up empty or invalid chats from the database
    /// This should be called during app initialization to remove any existing empty chats
    func cleanupEmptyChats() {
        AppLogger.log(tag: "LOG-APP: ChatsDB", message: "cleanupEmptyChats() Starting cleanup of empty/invalid chats")
        
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "cleanupEmptyChats() - Database not ready")
                return
            }
            
            var deleteStatement: OpaquePointer?
            // Delete chats with empty or null usernames, or invalid IDs
            let deleteStatementString = """
                DELETE FROM ChatTable WHERE 
                UserName IS NULL OR 
                UserName = '' OR 
                UserName = 'null' OR 
                TRIM(UserName) = '' OR
                ChatId IS NULL OR 
                ChatId = '' OR 
                ChatId = 'null' OR
                UserId IS NULL OR 
                UserId = '' OR 
                UserId = 'null'
            """
            
            if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
                if sqlite3_step(deleteStatement) == SQLITE_DONE {
                    let deletedCount = sqlite3_changes(db)
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "cleanupEmptyChats() - Successfully deleted \(deletedCount) empty/invalid chats")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    AppLogger.log(tag: "LOG-APP: ChatsDB", message: "cleanupEmptyChats() - Failed to delete empty chats, error: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "cleanupEmptyChats() - Failed to prepare cleanup statement, error: \(errorMsg)")
            }
            sqlite3_finalize(deleteStatement)
            
            // Update view models on main thread after cleanup
            let chatData = self.queryInternal(db: db)
            let inboxData = self.inboxqueryInternal(db: db)
            
            DispatchQueue.main.async {
                // MODERN SWIFTUI PATTERN: Use NotificationCenter instead of global view models
                // Notify SwiftUI views that chat data has changed
                NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
                NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
                AppLogger.log(tag: "LOG-APP: ChatsDB", message: "cleanupEmptyChats() - Posted data change notifications for SwiftUI views")
            }
        }
    }
}


