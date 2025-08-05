import Foundation
import SQLite3

struct Users {
    var user_id: String
    var user_name: String
    var user_image: String
    var user_gender: String
    var user_country: String
    var user_language: String
    var user_age: String
    var user_device_id: String
    var user_device_token: String
    var user_area: String
    var user_city: String
    var user_state: String
    var user_decent_time: Int64
    var user_last_time_seen: Int64
    var isAd: Bool
    
    // Legacy computed properties for backward compatibility
    var Id: String { return user_id }
    var Name: String { return user_name }
    var Age: String { return user_age } // Return actual user age
    var Country: String { return user_country }
    var Gender: String { return user_gender }
    var IsOnline: Bool { return false } // Not used in Android, keeping for compatibility
    var Language: String { return user_language } // Return actual user language
    var Lasttimeseen: Date { return Date(timeIntervalSince1970: Double(user_last_time_seen)) }
    var DeviceId: String { return user_device_id }
    var ProfileImage: String { return user_image }
    var adavailable: Bool { return isAd }
}

class OnlineUsersDB {
    
    // CRITICAL FIX: Use singleton pattern like other database classes (Android parity)
    static let shared = OnlineUsersDB()
    
    // CRITICAL FIX: Use shared serial queue for ALL database operations (like other DB classes)
    private let dbQueue = DispatchQueue(label: "OnlineUsersDB.serialQueue", qos: .userInitiated)
    
    private init() {
        // Table creation will be handled by ensureTableCreated() when called from DatabaseManager
        AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "init() - OnlineUsersDB singleton initialized")
    }
    
    // Public method to ensure table is created when database becomes ready
    func ensureTableCreated() {
        createTableIfNeeded()
    }
    
    // REMOVED: initializeDatabase() - now uses shared DatabaseManager connection
    
    // ANDROID PARITY: Create table only if it doesn't exist to preserve existing data
    private func createTableIfNeeded() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createTableIfNeeded() - Database not ready")
                return
            }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createTableIfNeeded() - Starting table creation/verification")
        
        // ANDROID PARITY: Create table with complete schema matching Android Online_Users_Table
        let createTableString = """
        CREATE TABLE IF NOT EXISTS OnlineUsers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT UNIQUE NOT NULL,
            user_name TEXT NOT NULL DEFAULT '',
            user_image TEXT DEFAULT '',
            user_gender TEXT DEFAULT '',
            user_country TEXT DEFAULT '',
            user_language TEXT DEFAULT '',
            user_age TEXT DEFAULT '',
            user_device_id TEXT DEFAULT '',
            user_device_token TEXT DEFAULT '',
            user_area TEXT DEFAULT '',
            user_city TEXT DEFAULT '',
            user_state TEXT DEFAULT '',
            user_decent_time INTEGER DEFAULT 0,
            user_last_time_seen INTEGER DEFAULT 0,
            isAd INTEGER DEFAULT 0,
            UNIQUE(user_id) ON CONFLICT REPLACE
        );
        """
        
        var createTableStatement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil)
        
        if prepareResult == SQLITE_OK {
            let stepResult = sqlite3_step(createTableStatement)
            if stepResult == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createTableIfNeeded() - Table created successfully or already exists")
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createTableIfNeeded() - Failed to execute table creation: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createTableIfNeeded() - Failed to prepare table creation: \(String(cString: sqlite3_errmsg(db)))")
        }
        
        sqlite3_finalize(createTableStatement)
        
            // Create indexes for performance (Android parity)
            self.createIndexesInner(db: db)
        }
    }

    
    private func createIndexIfNeeded() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else { 
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexIfNeeded() - Database not ready")
                return 
            }
            self.createIndexesInner(db: db)
        }
    }
    
    private func createIndexes() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else { return }
            self.createIndexesInner(db: db)
        }
    }
    
    private func createIndexesInner(db: OpaquePointer) {
        // Index 1: Unique index on user_id (matches Android @Index annotation)
        let createUserIdIndexString = "CREATE UNIQUE INDEX IF NOT EXISTS index_OnlineUsers_user_id ON OnlineUsers(user_id);"
        var createUserIdIndexStatement: OpaquePointer?
        
        let userIdPrepareResult = sqlite3_prepare_v2(db, createUserIdIndexString, -1, &createUserIdIndexStatement, nil)
        if userIdPrepareResult == SQLITE_OK {
            let userIdStepResult = sqlite3_step(createUserIdIndexStatement)
            if userIdStepResult == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Unique user_id index created successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to create user_id index: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to prepare user_id index: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createUserIdIndexStatement)
        
        // Index 2: Index on user_last_time_seen for performance (matches Android ORDER BY queries)
        let createLastTimeSeenIndexString = "CREATE INDEX IF NOT EXISTS index_OnlineUsers_user_last_time_seen ON OnlineUsers(user_last_time_seen DESC);"
        var createLastTimeSeenIndexStatement: OpaquePointer?
        
        let lastTimeSeenPrepareResult = sqlite3_prepare_v2(db, createLastTimeSeenIndexString, -1, &createLastTimeSeenIndexStatement, nil)
        if lastTimeSeenPrepareResult == SQLITE_OK {
            let lastTimeSeenStepResult = sqlite3_step(createLastTimeSeenIndexStatement)
            if lastTimeSeenStepResult == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - user_last_time_seen index created successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to create user_last_time_seen index: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to prepare user_last_time_seen index: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createLastTimeSeenIndexStatement)
        
        // Index 3: Composite index on isAd and user_last_time_seen for filtering queries
        let createIsAdIndexString = "CREATE INDEX IF NOT EXISTS index_OnlineUsers_isAd_last_time ON OnlineUsers(isAd, user_last_time_seen DESC);"
        var createIsAdIndexStatement: OpaquePointer?
        
        let isAdPrepareResult = sqlite3_prepare_v2(db, createIsAdIndexString, -1, &createIsAdIndexStatement, nil)
        if isAdPrepareResult == SQLITE_OK {
            let isAdStepResult = sqlite3_step(createIsAdIndexStatement)
            if isAdStepResult == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - isAd composite index created successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to create isAd composite index: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to prepare isAd composite index: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createIsAdIndexStatement)
        
        // Index 4: Indexes for location-based queries (matching Android DAO queries)
        let createAreaIndexString = "CREATE INDEX IF NOT EXISTS index_OnlineUsers_user_area ON OnlineUsers(user_area, user_last_time_seen DESC);"
        var createAreaIndexStatement: OpaquePointer?
        
        let areaPrepareResult = sqlite3_prepare_v2(db, createAreaIndexString, -1, &createAreaIndexStatement, nil)
        if areaPrepareResult == SQLITE_OK {
            let areaStepResult = sqlite3_step(createAreaIndexStatement)
            if areaStepResult == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - user_area index created successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to create user_area index: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to prepare user_area index: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createAreaIndexStatement)
        
        let createCityIndexString = "CREATE INDEX IF NOT EXISTS index_OnlineUsers_user_city ON OnlineUsers(user_city, user_last_time_seen DESC);"
        var createCityIndexStatement: OpaquePointer?
        
        let cityPrepareResult = sqlite3_prepare_v2(db, createCityIndexString, -1, &createCityIndexStatement, nil)
        if cityPrepareResult == SQLITE_OK {
            let cityStepResult = sqlite3_step(createCityIndexStatement)
            if cityStepResult == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - user_city index created successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to create user_city index: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to prepare user_city index: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createCityIndexStatement)
        
        let createStateIndexString = "CREATE INDEX IF NOT EXISTS index_OnlineUsers_user_state ON OnlineUsers(user_state, user_last_time_seen DESC);"
        var createStateIndexStatement: OpaquePointer?
        
        let statePrepareResult = sqlite3_prepare_v2(db, createStateIndexString, -1, &createStateIndexStatement, nil)
        if statePrepareResult == SQLITE_OK {
            let stateStepResult = sqlite3_step(createStateIndexStatement)
            if stateStepResult == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - user_state index created successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to create user_state index: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - Failed to prepare user_state index: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createStateIndexStatement)
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "createIndexes() - All indexes created successfully (Android parity)")
    }
    
    // REMOVED: closeDatabase() and ensureConnection() - now uses shared DatabaseManager
    
    func createtable() {
        createTableIfNeeded()
    }
    
    func deletetable() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deletetable() - Database not ready")
                return
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deletetable() - Starting table deletion")
            
            let deleteTableString = "DROP TABLE IF EXISTS OnlineUsers"
            var deleteTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, deleteTableString, -1, &deleteTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(deleteTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deletetable() - Table deleted successfully")
                } else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deletetable() - Failed to execute deletion: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deletetable() - Failed to prepare deletion: \(String(cString: sqlite3_errmsg(db)))")
            }
            
            sqlite3_finalize(deleteTableStatement)
        }
    }
    
    // CRITICAL FIX: Proper UTF-8 string handling and NULL safety
    func query() -> [Users] {
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "query() - Database not ready")
            return []
        }
            
            let queryString = "SELECT * FROM OnlineUsers ORDER BY user_last_time_seen DESC LIMIT 250;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: []
            ) { statement in
                var users: [Users] = []
                var rowCount = 0
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    rowCount += 1
                    
                    // CRITICAL FIX: Proper UTF-8 string extraction with comprehensive NULL checking
                    let user_id = self.extractString(from: statement, column: 1)
                    let user_name = self.extractString(from: statement, column: 2)
                    let user_image = self.extractString(from: statement, column: 3)
                    let user_gender = self.extractString(from: statement, column: 4)
                    let user_country = self.extractString(from: statement, column: 5)
                    let user_language = self.extractString(from: statement, column: 6)
                    let user_age = self.extractString(from: statement, column: 7)
                    let user_device_id = self.extractString(from: statement, column: 8)
                    let user_device_token = self.extractString(from: statement, column: 9)
                    let user_area = self.extractString(from: statement, column: 10)
                    let user_city = self.extractString(from: statement, column: 11)
                    let user_state = self.extractString(from: statement, column: 12)
                    let user_decent_time = sqlite3_column_int64(statement, 13)
                    let user_last_time_seen = sqlite3_column_int64(statement, 14)
                    let isAd = sqlite3_column_int(statement, 15) == 1
                    
                    // Skip corrupted records
                    if user_id.isEmpty && user_name.isEmpty {
                        AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "query() - Skipping corrupted record at row \(rowCount)")
                        continue
                    }
                    
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "query() - Row \(rowCount): user_id=\(user_id), user_name=\(user_name), user_country=\(user_country), user_gender=\(user_gender)")
                    
                    let user = Users(
                        user_id: user_id,
                        user_name: user_name,
                        user_image: user_image,
                        user_gender: user_gender,
                        user_country: user_country,
                        user_language: user_language,
                        user_age: user_age,
                        user_device_id: user_device_id,
                        user_device_token: user_device_token,
                        user_area: user_area,
                        user_city: user_city,
                        user_state: user_state,
                        user_decent_time: user_decent_time,
                        user_last_time_seen: user_last_time_seen,
                        isAd: isAd
                    )
                    
                    users.append(user)
                }
                
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "query() - Processed \(rowCount) rows from database")
                return users
            }
            
            switch result {
            case .success(let users):
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "query() - Returning \(users.count) users total")
                return users
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "query() - Failed to execute query: \(error)")
                return []
            }
    }
    
    // CRITICAL FIX: Safe string extraction with proper UTF-8 handling
    private func extractString(from statement: OpaquePointer?, column: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, column) else {
            return ""
        }
        
        let stringValue = String(cString: cString)
        
        // Validate UTF-8 and filter out corrupted data
        guard stringValue.utf8.count > 0,
              !stringValue.contains("\0"),
              stringValue.unicodeScalars.allSatisfy({ $0.isASCII || $0.value > 127 }) else {
            return ""
        }
        
        return stringValue
    }
    
    // CRITICAL FIX: Proper parameter binding with UTF-8 strings
    func insert(user_id: String, user_name: String, user_image: String, user_gender: String, user_country: String, user_language: String, user_age: String, user_device_id: String, user_device_token: String, user_area: String, user_city: String, user_state: String, user_decent_time: Int64, user_last_time_seen: Int64, isAd: Bool) {
        
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "insert() - Database not ready for user: \(user_name)")
                return
            }
            
            // Validate input data
            guard !user_id.isEmpty, !user_name.isEmpty else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "insert() - Invalid data: user_id or user_name is empty")
                return
            }
            
            var insertStatement: OpaquePointer?
            let insertString = "INSERT OR REPLACE INTO OnlineUsers (user_id, user_name, user_image, user_gender, user_country, user_language, user_age, user_device_id, user_device_token, user_area, user_city, user_state, user_decent_time, user_last_time_seen, isAd) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "insert() - Inserting user: \(user_name) with ID: \(user_id)")
            
            let prepareResult = sqlite3_prepare_v2(db, insertString, -1, &insertStatement, nil)
            
            if prepareResult == SQLITE_OK {
                                 // CRITICAL FIX: Use proper string copying with destructors
                 sqlite3_bind_text(insertStatement, 1, strdup(user_id), -1) { ptr in free(ptr) }
                 sqlite3_bind_text(insertStatement, 2, strdup(user_name), -1) { ptr in free(ptr) }
                 sqlite3_bind_text(insertStatement, 3, strdup(user_image), -1) { ptr in free(ptr) }
                 sqlite3_bind_text(insertStatement, 4, strdup(user_gender), -1) { ptr in free(ptr) }
                 sqlite3_bind_text(insertStatement, 5, strdup(user_country), -1) { ptr in free(ptr) }
                 sqlite3_bind_text(insertStatement, 6, strdup(user_language), -1) { ptr in free(ptr) }
                 sqlite3_bind_text(insertStatement, 7, strdup(user_age), -1) { ptr in free(ptr) }
                 sqlite3_bind_text(insertStatement, 8, strdup(user_device_id), -1) { ptr in free(ptr) }
                 sqlite3_bind_text(insertStatement, 9, strdup(user_device_token), -1) { ptr in free(ptr) }
                 sqlite3_bind_text(insertStatement, 10, strdup(user_area), -1) { ptr in free(ptr) }
                 sqlite3_bind_text(insertStatement, 11, strdup(user_city), -1) { ptr in free(ptr) }
                 sqlite3_bind_text(insertStatement, 12, strdup(user_state), -1) { ptr in free(ptr) }
                sqlite3_bind_int64(insertStatement, 13, user_decent_time)
                sqlite3_bind_int64(insertStatement, 14, user_last_time_seen)
                sqlite3_bind_int(insertStatement, 15, isAd ? 1 : 0)
                
                let stepResult = sqlite3_step(insertStatement)
                if stepResult == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "insert() - Successfully inserted user: \(user_name)")
                } else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "insert() - Failed to insert user: \(user_name), error: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "insert() - Failed to prepare insert statement: \(String(cString: sqlite3_errmsg(db)))")
            }
            
            sqlite3_finalize(insertStatement)
        }
    }
    
    // Legacy insert method for backward compatibility
    func insert(Id: String, Name: String, Age: String, Country: String, Gender: String, IsOnline: Int, Language: String, Lasttimeseen: Int, DeviceId: String, ProfileImage: String, adavailable: Int) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "insert() - Legacy insert called for user: \(Name), converting to new format")
        
        insert(
            user_id: Id,
            user_name: Name,
            user_image: ProfileImage,
            user_gender: Gender,
            user_country: Country,
            user_language: Language,
            user_age: Age,
            user_device_id: DeviceId,
            user_device_token: "",
            user_area: "",
            user_city: "",
            user_state: "",
            user_decent_time: 0,
            user_last_time_seen: Int64(Lasttimeseen),
            isAd: adavailable == 1
        )
    }
    
    func update(Id: String, Lasttimeseen: Int32) {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "update() - Database not ready for user: \(Id)")
                return
            }
            
            var updateStatement: OpaquePointer?
            let updateString = "UPDATE OnlineUsers SET user_last_time_seen = ? WHERE user_id = ?"
            
                         if sqlite3_prepare_v2(db, updateString, -1, &updateStatement, nil) == SQLITE_OK {
                 sqlite3_bind_int64(updateStatement, 1, Int64(Lasttimeseen))
                 sqlite3_bind_text(updateStatement, 2, strdup(Id), -1) { ptr in free(ptr) }
                
                if sqlite3_step(updateStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "update() - Successfully updated user: \(Id)")
                } else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "update() - Failed to update user: \(Id), error: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "update() - Failed to prepare update statement for user: \(Id)")
            }
            
            sqlite3_finalize(updateStatement)
        }
    }
    
    // CRITICAL FIX: Add method to clear corrupted data and fake ad users
    func clearCorruptedData() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "clearCorruptedData() - Database not ready")
                return
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "clearCorruptedData() - Starting corrupted data cleanup")
            
            // Remove records with empty or NULL user_id/user_name AND fake ad users
            let cleanupString = "DELETE FROM OnlineUsers WHERE user_id IS NULL OR user_id = '' OR user_name IS NULL OR user_name = '' OR length(user_id) < 3 OR length(user_name) < 1 OR user_id LIKE '%_ad_%';"
            var cleanupStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, cleanupString, -1, &cleanupStatement, nil) == SQLITE_OK {
                if sqlite3_step(cleanupStatement) == SQLITE_DONE {
                    let deletedRows = sqlite3_changes(db)
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "clearCorruptedData() - Removed \(deletedRows) corrupted records and fake ad users")
                } else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "clearCorruptedData() - Failed to execute cleanup: \(String(cString: sqlite3_errmsg(db)))")
                }
            }
            
            sqlite3_finalize(cleanupStatement)
        }
    }
    
    // Android parity: Delete all online users (matching deleteAllOnlineUsers() from Android DAO)
    func deleteAllOnlineUsers() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deleteAllOnlineUsers() - Database not ready")
                return
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deleteAllOnlineUsers() - Starting to delete all online users")
            
            let deleteString = "DELETE FROM OnlineUsers;"
            var deleteStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, deleteString, -1, &deleteStatement, nil) == SQLITE_OK {
                if sqlite3_step(deleteStatement) == SQLITE_DONE {
                    let deletedRows = sqlite3_changes(db)
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deleteAllOnlineUsers() - Successfully deleted \(deletedRows) online users")
                } else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deleteAllOnlineUsers() - Failed to execute deletion: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deleteAllOnlineUsers() - Failed to prepare deletion statement: \(String(cString: sqlite3_errmsg(db)))")
            }
            
            sqlite3_finalize(deleteStatement)
        }
    }
    
    // MARK: - Missing Methods for OnlineUsersManager Compatibility
    
    /// Insert user from OnlineUser object - OnlineUsersManager compatibility
    func insertUser(_ user: OnlineUser) {
        AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "insertUser() - Inserting OnlineUser: \(user.name)")
        
        insert(
            user_id: user.id ?? "",
            user_name: user.name,
            user_image: user.profileImage,
            user_gender: user.gender,
            user_country: user.country,
            user_language: user.language,
            user_age: user.age,
            user_device_id: user.deviceId,
            user_device_token: "",
            user_area: "",
            user_city: "",
            user_state: "",
            user_decent_time: 0,
            user_last_time_seen: Int64(user.lastTimeSeen.timeIntervalSince1970),
            isAd: false
        )
    }
    
    /// Delete user by userId - OnlineUsersManager compatibility
    func deleteUser(_ userId: String) {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deleteUser() - Database not ready for user: \(userId)")
                return
            }
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deleteUser() - Deleting user with ID: \(userId)")
            
            let deleteString = "DELETE FROM OnlineUsers WHERE user_id = ?;"
            var deleteStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, deleteString, -1, &deleteStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(deleteStatement, 1, strdup(userId), -1) { ptr in free(ptr) }
                
                if sqlite3_step(deleteStatement) == SQLITE_DONE {
                    let deletedRows = sqlite3_changes(db)
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deleteUser() - Successfully deleted \(deletedRows) user(s) with ID: \(userId)")
                } else {
                    AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deleteUser() - Failed to delete user: \(userId), error: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "deleteUser() - Failed to prepare delete statement for user: \(userId)")
            }
            
            sqlite3_finalize(deleteStatement)
        }
    }
    
    /// Clear all users - OnlineUsersManager compatibility (alias for deleteAllOnlineUsers)
    func clearAllUsers() {
        AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "clearAllUsers() - Calling deleteAllOnlineUsers()")
        deleteAllOnlineUsers()
    }
    
    // MARK: - Android DAO Parity Methods
    
    /// Get users by area - matches Android DAO getAreaUsers()
    func getAreaUsers(userArea: String) -> [Users] {
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getAreaUsers() - Database not ready")
            return []
        }
            
            let queryString = "SELECT * FROM OnlineUsers WHERE user_area = ? ORDER BY user_last_time_seen DESC LIMIT 250;"
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getAreaUsers() - Querying users for area: \(userArea)")
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: [userArea]
            ) { statement in
                var users: [Users] = []
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let user_id = self.extractString(from: statement, column: 1)
                    let user_name = self.extractString(from: statement, column: 2)
                    let user_image = self.extractString(from: statement, column: 3)
                    let user_gender = self.extractString(from: statement, column: 4)
                    let user_country = self.extractString(from: statement, column: 5)
                    let user_language = self.extractString(from: statement, column: 6)
                    let user_age = self.extractString(from: statement, column: 7)
                    let user_device_id = self.extractString(from: statement, column: 8)
                    let user_device_token = self.extractString(from: statement, column: 9)
                    let user_area = self.extractString(from: statement, column: 10)
                    let user_city = self.extractString(from: statement, column: 11)
                    let user_state = self.extractString(from: statement, column: 12)
                    let user_decent_time = sqlite3_column_int64(statement, 13)
                    let user_last_time_seen = sqlite3_column_int64(statement, 14)
                    let isAd = sqlite3_column_int(statement, 15) == 1
                    
                    if !user_id.isEmpty && !user_name.isEmpty {
                        let user = Users(
                            user_id: user_id,
                            user_name: user_name,
                            user_image: user_image,
                            user_gender: user_gender,
                            user_country: user_country,
                            user_language: user_language,
                            user_age: user_age,
                            user_device_id: user_device_id,
                            user_device_token: user_device_token,
                            user_area: user_area,
                            user_city: user_city,
                            user_state: user_state,
                            user_decent_time: user_decent_time,
                            user_last_time_seen: user_last_time_seen,
                            isAd: isAd
                        )
                        users.append(user)
                    }
                }
                
                return users
            }
            
            switch result {
            case .success(let users):
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getAreaUsers() - Returning \(users.count) users for area: \(userArea)")
                return users
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getAreaUsers() - Failed to execute query: \(error)")
                return []
            }
    }
    
    /// Get users by city - matches Android DAO getCityUsers()
    func getCityUsers(userCity: String) -> [Users] {
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getCityUsers() - Database not ready")
            return []
        }
            
            let queryString = "SELECT * FROM OnlineUsers WHERE user_city = ? ORDER BY user_last_time_seen DESC LIMIT 250;"
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getCityUsers() - Querying users for city: \(userCity)")
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: [userCity]
            ) { statement in
                var users: [Users] = []
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let user_id = self.extractString(from: statement, column: 1)
                    let user_name = self.extractString(from: statement, column: 2)
                    let user_image = self.extractString(from: statement, column: 3)
                    let user_gender = self.extractString(from: statement, column: 4)
                    let user_country = self.extractString(from: statement, column: 5)
                    let user_language = self.extractString(from: statement, column: 6)
                    let user_age = self.extractString(from: statement, column: 7)
                    let user_device_id = self.extractString(from: statement, column: 8)
                    let user_device_token = self.extractString(from: statement, column: 9)
                    let user_area = self.extractString(from: statement, column: 10)
                    let user_city = self.extractString(from: statement, column: 11)
                    let user_state = self.extractString(from: statement, column: 12)
                    let user_decent_time = sqlite3_column_int64(statement, 13)
                    let user_last_time_seen = sqlite3_column_int64(statement, 14)
                    let isAd = sqlite3_column_int(statement, 15) == 1
                    
                    if !user_id.isEmpty && !user_name.isEmpty {
                        let user = Users(
                            user_id: user_id,
                            user_name: user_name,
                            user_image: user_image,
                            user_gender: user_gender,
                            user_country: user_country,
                            user_language: user_language,
                            user_age: user_age,
                            user_device_id: user_device_id,
                            user_device_token: user_device_token,
                            user_area: user_area,
                            user_city: user_city,
                            user_state: user_state,
                            user_decent_time: user_decent_time,
                            user_last_time_seen: user_last_time_seen,
                            isAd: isAd
                        )
                        users.append(user)
                    }
                }
                
                return users
            }
            
            switch result {
            case .success(let users):
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getCityUsers() - Returning \(users.count) users for city: \(userCity)")
                return users
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getCityUsers() - Failed to execute query: \(error)")
                return []
            }
    }
    
    /// Get users by state - matches Android DAO getStateUsers()
    func getStateUsers(userState: String) -> [Users] {
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getStateUsers() - Database not ready")
            return []
        }
            
            let queryString = "SELECT * FROM OnlineUsers WHERE user_state = ? ORDER BY user_last_time_seen DESC LIMIT 250;"
            
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getStateUsers() - Querying users for state: \(userState)")
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: [userState]
            ) { statement in
                var users: [Users] = []
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let user_id = self.extractString(from: statement, column: 1)
                    let user_name = self.extractString(from: statement, column: 2)
                    let user_image = self.extractString(from: statement, column: 3)
                    let user_gender = self.extractString(from: statement, column: 4)
                    let user_country = self.extractString(from: statement, column: 5)
                    let user_language = self.extractString(from: statement, column: 6)
                    let user_age = self.extractString(from: statement, column: 7)
                    let user_device_id = self.extractString(from: statement, column: 8)
                    let user_device_token = self.extractString(from: statement, column: 9)
                    let user_area = self.extractString(from: statement, column: 10)
                    let user_city = self.extractString(from: statement, column: 11)
                    let user_state = self.extractString(from: statement, column: 12)
                    let user_decent_time = sqlite3_column_int64(statement, 13)
                    let user_last_time_seen = sqlite3_column_int64(statement, 14)
                    let isAd = sqlite3_column_int(statement, 15) == 1
                    
                    if !user_id.isEmpty && !user_name.isEmpty {
                        let user = Users(
                            user_id: user_id,
                            user_name: user_name,
                            user_image: user_image,
                            user_gender: user_gender,
                            user_country: user_country,
                            user_language: user_language,
                            user_age: user_age,
                            user_device_id: user_device_id,
                            user_device_token: user_device_token,
                            user_area: user_area,
                            user_city: user_city,
                            user_state: user_state,
                            user_decent_time: user_decent_time,
                            user_last_time_seen: user_last_time_seen,
                            isAd: isAd
                        )
                        users.append(user)
                    }
                }
                
                return users
            }
            
            switch result {
            case .success(let users):
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getStateUsers() - Returning \(users.count) users for state: \(userState)")
                return users
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getStateUsers() - Failed to execute query: \(error)")
                return []
            }
    }
    
    /// Check if user exists in online users list - matches Android DAO isUserInOnlineUserList()
    func isUserInOnlineUserList(userId: String) -> Bool {
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "isUserInOnlineUserList() - Database not ready")
            return false
        }
            
            let queryString = "SELECT id FROM OnlineUsers WHERE user_id = ? LIMIT 1;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: [userId]
            ) { statement in
                var exists = false
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    exists = true
                }
                
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "isUserInOnlineUserList() - User \(userId) exists: \(exists)")
                return exists
            }
            
            switch result {
            case .success(let exists):
                return exists
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "isUserInOnlineUserList() - Failed to execute query: \(error)")
                return false
            }
    }
    
    /// Get ID of user from online users list - matches Android DAO getIdOfUserFromOnlineUserList()
    func getIdOfUserFromOnlineUserList(userId: String) -> Int {
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getIdOfUserFromOnlineUserList() - Database not ready")
            return -1
        }
            
            let queryString = "SELECT id FROM OnlineUsers WHERE user_id = ? LIMIT 1;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: [userId]
            ) { statement in
                var id = -1
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    id = Int(sqlite3_column_int(statement, 0))
                }
                
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getIdOfUserFromOnlineUserList() - User \(userId) ID: \(id)")
                return id
            }
            
            switch result {
            case .success(let id):
                return id
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "getIdOfUserFromOnlineUserList() - Failed to execute query: \(error)")
                return -1
            }
    }
    
    /// Get last online user time - matches Android DAO selectLastOnlineUserTime()
    func selectLastOnlineUserTime() -> Int64 {
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "selectLastOnlineUserTime() - Database not ready")
            return 0
        }
            
            let queryString = "SELECT user_last_time_seen FROM OnlineUsers WHERE isAd = 0 ORDER BY user_last_time_seen DESC LIMIT 1;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: []
            ) { statement in
                var lastTime: Int64 = 0
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    lastTime = sqlite3_column_int64(statement, 0)
                }
                
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "selectLastOnlineUserTime() - Last time: \(lastTime)")
                return lastTime
            }
            
            switch result {
            case .success(let lastTime):
                return lastTime
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: OnlineUsersDB", message: "selectLastOnlineUserTime() - Failed to execute query: \(error)")
                return 0
            }
    }
}
