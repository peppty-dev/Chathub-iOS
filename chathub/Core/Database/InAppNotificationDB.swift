import Foundation
import SQLite3

// MARK: - NotificationDetails Model
struct InAppNotificationDetails: Identifiable {
    let id: String // Required for Identifiable
    let NotificationName: String
    let NotificationId: String
    let NotificationTime: String
    let NotificationType: String
    let NotificationGender: String
    let NotificationImage: String
    let NotificationOtherId: String // Android parity: notif_other_id
    let NotificationSeen: Bool // Android parity: notif_seen
    // Removed IsAds - not needed in subscription model
    
    /// Notification types matching Android implementation
    enum NotificationType: String, CaseIterable {
        case profileview = "profileview"
    }
    
    init(NotificationName: String, NotificationId: String, NotificationTime: String, NotificationType: String, NotificationGender: String, NotificationImage: String, NotificationOtherId: String = "", NotificationSeen: Bool = false) {
        self.id = NotificationTime // Use NotificationTime as unique identifier
        self.NotificationName = NotificationName
        self.NotificationId = NotificationId
        self.NotificationTime = NotificationTime
        self.NotificationType = NotificationType
        self.NotificationGender = NotificationGender
        self.NotificationImage = NotificationImage
        self.NotificationOtherId = NotificationOtherId
        self.NotificationSeen = NotificationSeen
    }
    
    /// Firebase constructor for backward compatibility
    init(id: String, firebaseData: [String: Any]) {
        self.id = id // Use the provided id
        self.NotificationTime = id
        self.NotificationName = firebaseData["notif_sender_name"] as? String ?? ""
        self.NotificationId = firebaseData["notif_sender_id"] as? String ?? ""
        self.NotificationType = firebaseData["notif_type"] as? String ?? ""
        self.NotificationGender = firebaseData["notif_sender_gender"] as? String ?? ""
        self.NotificationImage = firebaseData["notif_sender_image"] as? String ?? ""
        self.NotificationOtherId = firebaseData["notif_other_id"] as? String ?? ""
        self.NotificationSeen = false // Default to unseen for Firebase data
    }
}

class InAppNotificationDB {
    
    // CRITICAL FIX: Make NotificationDB a proper singleton to prevent multiple instances
    static let shared = InAppNotificationDB()
    
    // CRITICAL FIX: Use a single serial queue for ALL database operations
    private let dbQueue = DispatchQueue(label: "NotificationDB.serialQueue", qos: .userInitiated)
    
    private init() {
        // Table creation will be handled by ensureTableCreated() when called from DatabaseManager
        AppLogger.log(tag: "LOG-APP: NotificationDB", message: "init() - NotificationDB singleton initialized")
    }
    
    // Public method to ensure table is created when database becomes ready
    func ensureTableCreated() {
        CreateNotification()
    }
    
    func deletetable() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "deletetable() - database not ready")
                return
            }
            
            let dropTableString = "DROP TABLE IF EXISTS Notification"
            var dropTableStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: NotificationDB", message: "deletetable() - Notification table deleted successfully")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    AppLogger.log(tag: "LOG-APP: NotificationDB", message: "deletetable() - Failed to execute DROP TABLE: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "deletetable() - Failed to prepare DROP TABLE statement: \(errorMsg)")
            }
            sqlite3_finalize(dropTableStatement)
        }
    }

    func CreateNotification() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Database not ready")
                return
            }
        
        // ANDROID PARITY: Check if table exists with correct schema before dropping
        let checkTableQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='Notification'"
        var checkStatement: OpaquePointer?
        var tableExists = false
        
        if sqlite3_prepare_v2(db, checkTableQuery, -1, &checkStatement, nil) == SQLITE_OK {
            if sqlite3_step(checkStatement) == SQLITE_ROW {
                tableExists = true
            }
        }
        sqlite3_finalize(checkStatement)
        
        if tableExists {
            // ANDROID PARITY: Check if table schema is compatible
            let checkSchemaQuery = "PRAGMA table_info(Notification)"
            var schemaStatement: OpaquePointer?
            var hasCorrectSchema = false
            var columnCount = 0
            var hasNotifType = false
            var hasNotifSenderName = false
            var hasNotifTime = false
            var hasNotifSeen = false
            
            if sqlite3_prepare_v2(db, checkSchemaQuery, -1, &schemaStatement, nil) == SQLITE_OK {
                while sqlite3_step(schemaStatement) == SQLITE_ROW {
                    columnCount += 1
                    let columnName = String(cString: sqlite3_column_text(schemaStatement, 1))
                    
                    switch columnName {
                    case "notif_type":
                        hasNotifType = true
                    case "notif_sender_name":
                        hasNotifSenderName = true
                    case "notif_time":
                        hasNotifTime = true
                    case "notif_seen":
                        hasNotifSeen = true
                    default:
                        break
                    }
                }
                
                // Check if we have the minimum required columns for Android parity
                hasCorrectSchema = (columnCount >= 8) && hasNotifType && hasNotifSenderName && hasNotifTime && hasNotifSeen
            }
            sqlite3_finalize(schemaStatement)
            
            if hasCorrectSchema {
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Table exists with correct Android parity schema, skipping creation")
                return
            } else {
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Table exists but schema is incompatible, dropping for migration")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Table does not exist, creating new Android parity schema")
        }
        
        // ANDROID PARITY: Only drop table if it exists and has incompatible schema
        if tableExists {
            let dropTableString = "DROP TABLE IF EXISTS Notification"
            var dropTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Successfully dropped incompatible table for schema migration")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Failed to drop incompatible table: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Failed to prepare DROP TABLE statement: \(errorMsg)")
            }
            sqlite3_finalize(dropTableStatement)
        }
        
        // SUBSCRIPTION MODEL: Create table without ads-related columns
        let createTableString = """
        CREATE TABLE Notification (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            notif_type TEXT NOT NULL,
            notif_sender_name TEXT NOT NULL,
            notif_sender_id TEXT NOT NULL,
            notif_sender_gender TEXT NOT NULL,
            notif_sender_image TEXT NOT NULL,
            notif_other_id TEXT NOT NULL,
            notif_time INTEGER NOT NULL,
            notif_seen INTEGER NOT NULL DEFAULT 0,
            UNIQUE(notif_time) ON CONFLICT REPLACE
        );
        """
        var createTableStatement: OpaquePointer?
        
        let prepareResult = sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil)
        if prepareResult == SQLITE_OK {
            let stepResult = sqlite3_step(createTableStatement)
            if stepResult == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Notification table created successfully with Android parity schema")
                
                // Debug: Verify table schema by querying column info
                let checkSchemaQuery = "PRAGMA table_info(Notification)"
                var checkStatement: OpaquePointer?
                if sqlite3_prepare_v2(db, checkSchemaQuery, -1, &checkStatement, nil) == SQLITE_OK {
                    AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Table schema verification:")
                    while sqlite3_step(checkStatement) == SQLITE_ROW {
                        let columnName = String(cString: sqlite3_column_text(checkStatement, 1))
                        let columnType = String(cString: sqlite3_column_text(checkStatement, 2))
                        AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Column: \(columnName) Type: \(columnType)")
                    }
                }
                sqlite3_finalize(checkStatement)
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Failed to execute CREATE TABLE: \(errorMsg)")
            }
        } else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            AppLogger.log(tag: "LOG-APP: NotificationDB", message: "CreateNotification() - Failed to prepare CREATE TABLE statement: \(errorMsg)")
            }
            sqlite3_finalize(createTableStatement)
        }
    }
    
    func query() -> [InAppNotificationDetails] {
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: NotificationDB", message: "query() - Database not ready")
            return []
        }
            
            let queryStatementString = "SELECT * FROM Notification ORDER BY notif_time DESC"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryStatementString,
                parameters: []
            ) { statement in
                var notifications: [InAppNotificationDetails] = []
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    // Extract data using Android parity column indices
                    let notifType = String(cString: sqlite3_column_text(statement, 1))
                    let notifSenderName = String(cString: sqlite3_column_text(statement, 2))
                    let notifSenderId = String(cString: sqlite3_column_text(statement, 3))
                    let notifSenderGender = String(cString: sqlite3_column_text(statement, 4))
                    let notifSenderImage = String(cString: sqlite3_column_text(statement, 5))
                    let notifOtherId = String(cString: sqlite3_column_text(statement, 6))
                    let notifTime = String(sqlite3_column_int64(statement, 7))
                    let notifSeen = sqlite3_column_int(statement, 8) == 1
                    
                    let notification = InAppNotificationDetails(
                        NotificationName: notifSenderName,
                        NotificationId: notifSenderId,
                        NotificationTime: notifTime,
                        NotificationType: notifType,
                        NotificationGender: notifSenderGender,
                        NotificationImage: notifSenderImage,
                        NotificationOtherId: notifOtherId,
                        NotificationSeen: notifSeen
                    )
                    notifications.append(notification)
                }
                
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "query() - Successfully retrieved \(notifications.count) notifications")
                return notifications
            }
            
            switch result {
            case .success(let notifications):
                return notifications
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "query() - Failed to execute query: \(error)")
                return []
            }
    }

    // SUBSCRIPTION MODEL: Insert method without ads-related parameters
    func insert(notifType: String, notifSenderName: String, notifSenderId: String, notifSenderGender: String, notifSenderImage: String, notifOtherId: String, notifTime: Int64, notifSeen: Bool = false) {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "insert() - Database not ready")
                return
            }
            
            // ANDROID PARITY: Check if notification already exists (like Android isNotificationInTable)
            let checkExistsQuery = "SELECT id FROM Notification WHERE notif_time = ? LIMIT 1"
            var checkStatement: OpaquePointer?
            var notificationExists = false
            var existingId: Int32 = 0
            
            if sqlite3_prepare_v2(db, checkExistsQuery, -1, &checkStatement, nil) == SQLITE_OK {
                sqlite3_bind_int64(checkStatement, 1, notifTime)
                if sqlite3_step(checkStatement) == SQLITE_ROW {
                    notificationExists = true
                    existingId = sqlite3_column_int(checkStatement, 0)
                }
            }
            sqlite3_finalize(checkStatement)
            
            if notificationExists {
                // ANDROID PARITY: Update existing notification (like Android update path)
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "insert() - Updating existing notification with id: \(existingId)")
                
                let updateQuery = """
                UPDATE Notification SET 
                    notif_type = ?, 
                    notif_sender_name = ?, 
                    notif_sender_id = ?, 
                    notif_sender_gender = ?, 
                    notif_sender_image = ?, 
                    notif_other_id = ?, 
                    notif_seen = ? 
                WHERE id = ?
                """
                var updateStatement: OpaquePointer?
                
                if sqlite3_prepare_v2(db, updateQuery, -1, &updateStatement, nil) == SQLITE_OK {
                    sqlite3_bind_text(updateStatement, 1, notifType, -1, nil)
                    sqlite3_bind_text(updateStatement, 2, notifSenderName, -1, nil)
                    sqlite3_bind_text(updateStatement, 3, notifSenderId, -1, nil)
                    sqlite3_bind_text(updateStatement, 4, notifSenderGender, -1, nil)
                    sqlite3_bind_text(updateStatement, 5, notifSenderImage, -1, nil)
                    sqlite3_bind_text(updateStatement, 6, notifOtherId, -1, nil)
                    sqlite3_bind_int(updateStatement, 7, notifSeen ? 1 : 0)
                    sqlite3_bind_int(updateStatement, 8, existingId)
                    
                    if sqlite3_step(updateStatement) == SQLITE_DONE {
                        AppLogger.log(tag: "LOG-APP: NotificationDB", message: "insert() - Successfully updated notification: \(notifSenderId)")
                    } else {
                        let errorMsg = String(cString: sqlite3_errmsg(db))
                        AppLogger.log(tag: "LOG-APP: NotificationDB", message: "insert() - Failed to update notification: \(errorMsg)")
                    }
                }
                sqlite3_finalize(updateStatement)
            } else {
                // ANDROID PARITY: Insert new notification (like Android insert path)
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "insert() - Adding new notification: \(notifSenderId)")
                
                let insertQuery = """
                INSERT INTO Notification (notif_type, notif_sender_name, notif_sender_id, notif_sender_gender, notif_sender_image, notif_other_id, notif_time, notif_seen) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """
                var insertStatement: OpaquePointer?
                
                if sqlite3_prepare_v2(db, insertQuery, -1, &insertStatement, nil) == SQLITE_OK {
                    sqlite3_bind_text(insertStatement, 1, notifType, -1, nil)
                    sqlite3_bind_text(insertStatement, 2, notifSenderName, -1, nil)
                    sqlite3_bind_text(insertStatement, 3, notifSenderId, -1, nil)
                    sqlite3_bind_text(insertStatement, 4, notifSenderGender, -1, nil)
                    sqlite3_bind_text(insertStatement, 5, notifSenderImage, -1, nil)
                    sqlite3_bind_text(insertStatement, 6, notifOtherId, -1, nil)
                    sqlite3_bind_int64(insertStatement, 7, notifTime)
                    sqlite3_bind_int(insertStatement, 8, notifSeen ? 1 : 0)
                    
                    if sqlite3_step(insertStatement) == SQLITE_DONE {
                        AppLogger.log(tag: "LOG-APP: NotificationDB", message: "insert() - Successfully inserted notification: \(notifSenderId)")
                    } else {
                        let errorMsg = String(cString: sqlite3_errmsg(db))
                        AppLogger.log(tag: "LOG-APP: NotificationDB", message: "insert() - Failed to insert notification: \(errorMsg)")
                    }
                }
                sqlite3_finalize(insertStatement)
            }
            
            // Notify UI of notification changes
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .notificationDataChanged, object: nil)
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "insert() - Posted notification data changed event")
            }
        }
    }

    // ANDROID PARITY: Get unread notifications count (like Android selectNotificationsCount)
    func getUnreadNotificationsCount() -> Int {
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: NotificationDB", message: "getUnreadNotificationsCount() - Database not ready")
            return 0
        }
            
            let countQuery = "SELECT COUNT(id) FROM Notification WHERE notif_seen = 0"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: countQuery,
                parameters: []
            ) { statement in
                var count = 0
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(statement, 0))
                }
                
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "getUnreadNotificationsCount() - Found \(count) unread notifications")
                return count
            }
            
            switch result {
            case .success(let count):
                return count
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "getUnreadNotificationsCount() - Failed to execute query: \(error)")
                return 0
            }
    }

    // ANDROID PARITY: Mark all notifications as seen (like Android setNotificationsSeen)
    func markAllNotificationsAsSeen() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "markAllNotificationsAsSeen() - Database not ready")
                return
            }
            
            let updateQuery = "UPDATE Notification SET notif_seen = 1 WHERE notif_seen = 0"
            var updateStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, updateQuery, -1, &updateStatement, nil) == SQLITE_OK {
                if sqlite3_step(updateStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: NotificationDB", message: "markAllNotificationsAsSeen() - Successfully marked all notifications as seen")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    AppLogger.log(tag: "LOG-APP: NotificationDB", message: "markAllNotificationsAsSeen() - Failed to mark notifications as seen: \(errorMsg)")
                }
            }
            sqlite3_finalize(updateStatement)
            
            // Notify UI of notification changes
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .notificationDataChanged, object: nil)
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "markAllNotificationsAsSeen() - Posted notification data changed event")
            }
        }
    }

    // ANDROID PARITY: Clear all notifications (like Android deleteAllNotificationsFromNotificationsTable)
    func clearAllNotifications() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "clearAllNotifications() - Database not ready")
                return
            }
            
            let deleteQuery = "DELETE FROM Notification"
            var deleteStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, deleteQuery, -1, &deleteStatement, nil) == SQLITE_OK {
                if sqlite3_step(deleteStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: NotificationDB", message: "clearAllNotifications() - Successfully cleared all notifications")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    AppLogger.log(tag: "LOG-APP: NotificationDB", message: "clearAllNotifications() - Failed to clear notifications: \(errorMsg)")
                }
            }
            sqlite3_finalize(deleteStatement)
            
            // Notify UI of notification changes
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .notificationDataChanged, object: nil)
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "clearAllNotifications() - Posted notification data changed event")
            }
        }
    }

    // ANDROID PARITY: Get last notification time (like Android selectLastNotification)
    func getLastNotificationTime() -> Int64 {
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: NotificationDB", message: "getLastNotificationTime() - Database not ready")
            return 0
        }
            
            let lastTimeQuery = "SELECT notif_time FROM Notification ORDER BY notif_time DESC LIMIT 1"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: lastTimeQuery,
                parameters: []
            ) { statement in
                var lastTime: Int64 = 0
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    lastTime = sqlite3_column_int64(statement, 0)
                }
                
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "getLastNotificationTime() - Last notification time: \(lastTime)")
                return lastTime
            }
            
            switch result {
            case .success(let lastTime):
                return lastTime
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: NotificationDB", message: "getLastNotificationTime() - Failed to execute query: \(error)")
                return 0
            }
    }

    // DEPRECATED: Legacy method for backward compatibility
    func insert(DocumentTime : String, NotificationName: String, NotificationId: String, NotificationType: String, NotificationGender: String, NotificationImage: String) {
        AppLogger.log(tag: "LOG-APP: NotificationDB", message: "insert() - DEPRECATED: Using legacy insert method, converting to new format")
        
        let notifTime = Int64(DocumentTime) ?? Int64(Date().timeIntervalSince1970)
        insert(
            notifType: NotificationType,
            notifSenderName: NotificationName,
            notifSenderId: NotificationId,
            notifSenderGender: NotificationGender,
            notifSenderImage: NotificationImage,
            notifOtherId: "",
            notifTime: notifTime,
            notifSeen: false
        )
    }

	func extractInt32(from string: String) -> Int32 {
	  let numbersString = string.components(separatedBy: CharacterSet.alphanumerics.inverted)
								 .joined()
		return Int32(numbersString) ?? 0
	}
}
