import Foundation
import UIKit
import SQLite3

/// iOS equivalent of Android's AsyncClass for database operations
/// Provides centralized database clearing functionality matching Android behavior
class DatabaseCleanupService {
    
    static let shared = DatabaseCleanupService()
    
    // CRITICAL FIX: Serial queue to prevent SQLite threading issues
    private let sqliteQueue = DispatchQueue(label: "DatabaseCleanupService.sqlite", qos: .userInitiated)
    
    // CRITICAL FIX: Prevent multiple cleanup operations from running simultaneously
    private var isCleanupInProgress = false
    private let cleanupLock = NSLock()
    
    private init() {}
    
    // MARK: - Complete Database Cleanup (Android Parity)
    
    /// Clears all database tables - matches Android's DeleteDatabaseAsyncTask
    /// Called during account operations, settings changes, warnings, etc.
    func deleteDatabase() {
        // CRITICAL FIX: Prevent multiple cleanup operations from running simultaneously
        cleanupLock.lock()
        defer { cleanupLock.unlock() }
        
        if isCleanupInProgress {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteDatabase() - cleanup already in progress, skipping")
            return
        }
        
        isCleanupInProgress = true
        defer { isCleanupInProgress = false }
        
        // OPTIMIZATION: Use higher priority queue for faster cleanup
        DispatchQueue.global(qos: .userInitiated).async {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteDatabase() - starting optimized database cleanup")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // OPTIMIZATION: Run SQLite and Core Data clearing in parallel with stricter timeouts
            let group = DispatchGroup()
            var sqliteCompleted = false
            var coreDataCompleted = false
            
            // Clear SQLite tables in background with timeout
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                let timeoutWorkItem = DispatchWorkItem {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteDatabase() - SQLite cleanup timed out")
                    if !sqliteCompleted {
                        sqliteCompleted = true
                        group.leave()
                    }
                }
                
                // 2 second timeout for SQLite cleanup
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2, execute: timeoutWorkItem)
                
                self.clearSQLiteTables()
                
                if !sqliteCompleted {
                    timeoutWorkItem.cancel()
                    sqliteCompleted = true
                    group.leave()
                }
            }
            
            // Clear UserDefaults cache data in parallel with timeout
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                let timeoutWorkItem = DispatchWorkItem {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteDatabase() - UserDefaults cleanup timed out")
                    if !coreDataCompleted {
                        coreDataCompleted = true
                        group.leave()
                    }
                }
                
                // 2 second timeout for UserDefaults cleanup
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2, execute: timeoutWorkItem)
                
                self.clearUserDefaultsCache()
                
                if !coreDataCompleted {
                    timeoutWorkItem.cancel()
                    coreDataCompleted = true
                    group.leave()
                }
            }
            
            // Wait for both operations to complete with overall timeout
            let result = group.wait(timeout: .now() + 3) // 3 second overall timeout
            
            // Clear UserDefaults for online users refresh time (matching Android)
            DispatchQueue.main.async {
                SessionManager.shared.onlineUsersRefreshTime = 0
                SessionManager.shared.synchronize()
                
                // Clear ViewModels to ensure UI is updated (Android parity)
                self.clearViewModels()
            }
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            if result == .timedOut {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteDatabase() - cleanup timed out after 3 seconds")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteDatabase() - cleanup completed in \(String(format: "%.2f", timeElapsed)) seconds")
            }
        }
    }
    
    /// Clears ViewModels to ensure UI reflects the cleared data (Android parity)
    private func clearViewModels() {
        AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearViewModels() - clearing all ViewModels")
        
        // Clear chat-related ViewModels
        // MODERN SWIFTUI PATTERN: Use NotificationCenter instead of global view models
        // Clear data and notify SwiftUI views that data has changed
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
            NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "Posted data change notifications for SwiftUI views")
        }
        
        AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearViewModels() - ViewModels cleared")
    }
    
    /// Clears only online users database - matches Android's DeleteOnlineUsersAsyncTask
    func deleteOnlineUsersOnly() {
        AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteOnlineUsersOnly() - Starting online users database clearing")
        
        DispatchQueue.global(qos: .background).async {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteOnlineUsersOnly() - Background thread started")
            
            let onlineUsersDB = OnlineUsersDB.shared
            
            // Check current database state before clearing
            let userCountBefore = onlineUsersDB.query().count
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteOnlineUsersOnly() - Users in database before clearing: \(userCountBefore)")
            
            // CRITICAL FIX: Clear corrupted data first, then recreate table
            onlineUsersDB.clearCorruptedData()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteOnlineUsersOnly() - Corrupted data cleared")
            
            onlineUsersDB.deletetable()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteOnlineUsersOnly() - Table deleted")
            
            onlineUsersDB.createtable()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteOnlineUsersOnly() - Table recreated")
            
            // Verify clearing worked
            let userCountAfter = onlineUsersDB.query().count
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteOnlineUsersOnly() - Users in database after clearing: \(userCountAfter)")
            
            // Reset refresh time (matching Android SessionManager.setOnlineUsersRefreshTime(0))
            DispatchQueue.main.async {
                SessionManager.shared.onlineUsersRefreshTime = 0
                SessionManager.shared.synchronize()
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteOnlineUsersOnly() - Reset refresh time in SessionManager")
            }
            
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "deleteOnlineUsersOnly() - Online users database clearing complete")
        }
    }
    
    /// Clears corrupted data from online users database without full recreation
    func clearCorruptedOnlineUsersData() {
        AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearCorruptedOnlineUsersData() - Starting corrupted data cleanup")
        
        DispatchQueue.global(qos: .background).async {
            let onlineUsersDB = OnlineUsersDB.shared
            
            // Check current database state before cleanup
            let userCountBefore = onlineUsersDB.query().count
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearCorruptedOnlineUsersData() - Users before cleanup: \(userCountBefore)")
            
            onlineUsersDB.clearCorruptedData()
            
            // Verify cleanup worked
            let userCountAfter = onlineUsersDB.query().count
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearCorruptedOnlineUsersData() - Users after cleanup: \(userCountAfter)")
            
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearCorruptedOnlineUsersData() - Corrupted data cleanup complete")
        }
    }
    
    // MARK: - Private Database Clearing Methods
    
    /// Clears SQLite database tables (matching Android Room database clearing)
    /// CRITICAL FIX: Use serial queue to prevent concurrent SQLite access
    private func clearSQLiteTables() {
        let tableList = [
            "OnlineUsers",
            "ChatTable", 
            "MessageTable",
            "AITrainingMessages",
            "GameTable",
            "RecentGameTable", 
            "Notification",
            "ProfileTable",
            "MyProfileData"
        ]
        
        // THREADING FIX: Execute all SQLite operations on serial queue with timeout protection
        sqliteQueue.sync {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTables() - Starting sequential table cleanup")
            
            for (index, tableName) in tableList.enumerated() {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTables() - Processing table \(index + 1)/\(tableList.count): \(tableName)")
                
                // Add small delay between operations to prevent overwhelming the database
                if index > 0 {
                    Thread.sleep(forTimeInterval: 0.01) // 10ms delay
                }
                
                clearSQLiteTable(tableName: tableName)
            }
            
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTables() - Completed sequential table cleanup")
        }
    }
    
    /// Clears individual SQLite table
    private func clearSQLiteTable(tableName: String) {
        // CRITICAL FIX: All database operations must be performed sequentially
        // This method is already called within sqliteQueue.sync, so no additional queuing needed
        
        AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTable() - Starting to clear table: \(tableName)")
        
        // For OnlineUsers, use the dedicated class but ensure it uses the global connection
        if tableName == "OnlineUsers" {
            // THREADING FIX: Instead of creating new OnlineUsersDB instance, use direct SQL
            clearOnlineUsersTableDirectly()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTable() - cleared table: \(tableName)")
            return
        }
        
        // For ChatTable and MessageTable, use ChatsDB but ensure sequential execution
        if tableName == "ChatTable" {
            clearChatTableDirectly()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTable() - cleared table: \(tableName)")
            return
        }
        
        if tableName == "MessageTable" {
            clearMessageTableDirectly()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTable() - cleared table: \(tableName)")
            return
        }
        
        // For AITrainingMessages, clear via AITrainingMessageStore synchronously
        if tableName == "AITrainingMessages" {
            AITrainingMessageStore.shared.clearAllMessagesSync()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTable() - cleared table: \(tableName)")
            return
        }
        
        // For ProfileTable, use ProfileDB but ensure sequential execution
        if tableName == "ProfileTable" {
            clearProfileTableDirectly()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTable() - cleared table: \(tableName)")
            return
        }
        
        // For GameTable, use GamesDB but ensure sequential execution
        if tableName == "GameTable" {
            clearGameTableDirectly()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTable() - cleared table: \(tableName)")
            return
        }
        
        if tableName == "RecentGameTable" {
            clearRecentGameTableDirectly()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTable() - cleared table: \(tableName)")
            return
        }
        
        // For Notification, use NotificationDB but ensure sequential execution
        if tableName == "Notification" {
            clearNotificationTableDirectly()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTable() - cleared table: \(tableName)")
            return
        }
        
        // For MyProfile-related tables
        if tableName == "MyProfileData" {
            clearMyProfileTableDirectly()
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearSQLiteTable() - cleared table: \(tableName)")
            return
        }
        
        // For other tables that don't have dedicated classes yet, use generic SQLite clearing
        clearGenericSQLiteTable(tableName: tableName)
    }
    
    /// Clears a generic SQLite table by dropping it using the global connection
    /// CRITICAL FIX: Use only the global database connection to prevent multi-threading issues
    /// NOTE: This method should only be called from within sqliteQueue.sync context
    private func clearGenericSQLiteTable(tableName: String) {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGenericSQLiteTable() - database not ready for table: \(tableName)")
                return
            }
        
        // THREADING FIX: Use only the global database connection
        let dropTableString = "DROP TABLE IF EXISTS \(tableName)"
        var dropTableStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGenericSQLiteTable() - Successfully dropped table: \(tableName)")
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGenericSQLiteTable() - Failed to drop table \(tableName): \(errorMsg)")
            }
        } else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGenericSQLiteTable() - Failed to prepare drop statement for \(tableName): \(errorMsg)")
        }
            
            sqlite3_finalize(dropTableStatement)
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGenericSQLiteTable() - cleared table: \(tableName)")
        }
    }
    
    /// Clears UserDefaults cache data (replaces CoreData entities)
    /// Clears cache-related data that was previously stored in CoreData
    private func clearUserDefaultsCache() {
        AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearUserDefaultsCache() - Starting UserDefaults cache cleanup")
        
        // Clear cache counters that were previously in CoreData entities
        UserDefaults.standard.removeObject(forKey: "badwords_count")           // Replaces BadwordsCount
        UserDefaults.standard.removeObject(forKey: "online_refresh_time")      // Replaces OnlineRefresh
        UserDefaults.standard.removeObject(forKey: "forreview_count")          // Replaces Forreview
        UserDefaults.standard.removeObject(forKey: "notification_new_count")   // Replaces NotificationNew
        UserDefaults.standard.removeObject(forKey: "block_post_count")         // Replaces BlockPost
        
        // Clear filter settings that were in CoreData Filter entity
        UserDefaults.standard.removeObject(forKey: "filter_min_age")
        UserDefaults.standard.removeObject(forKey: "filter_max_age")
        UserDefaults.standard.removeObject(forKey: "filter_gender")
        UserDefaults.standard.removeObject(forKey: "filter_country")
        
        // Clear IP address data that was in CoreData IpAddress entity
        UserDefaults.standard.removeObject(forKey: "user_ip_address")
        UserDefaults.standard.removeObject(forKey: "user_city")
        UserDefaults.standard.removeObject(forKey: "user_country_ip")
        
        // Clear profanity words cache (now handled by ProfanityService)
        UserDefaults.standard.removeObject(forKey: "last_profanity_check")
        UserDefaults.standard.removeObject(forKey: "profanity_words_version")
        UserDefaults.standard.removeObject(forKey: "profanityAppNamesVersion")
        
        // Synchronize changes
        UserDefaults.standard.synchronize()
        
        AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearUserDefaultsCache() - UserDefaults cache cleanup completed")
    }
    
    // MARK: - Direct Table Clearing Methods (Thread-Safe)
    
    /// Clear OnlineUsers table directly using global connection
    private func clearOnlineUsersTableDirectly() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearOnlineUsersTableDirectly() - database not ready")
                return
            }
            
            // Drop and recreate table using global connection
            let dropTableString = "DROP TABLE IF EXISTS OnlineUsers"
            var dropTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearOnlineUsersTableDirectly() - Table dropped successfully")
                } else {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearOnlineUsersTableDirectly() - Failed to drop table: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearOnlineUsersTableDirectly() - Failed to prepare drop statement: \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(dropTableStatement)
            
            // Recreate table with complete schema matching OnlineUsersDB
            let createTableString = """
            CREATE TABLE OnlineUsers (
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
            
            if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(createTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearOnlineUsersTableDirectly() - Table recreated successfully")
                } else {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearOnlineUsersTableDirectly() - Failed to recreate table: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearOnlineUsersTableDirectly() - Failed to prepare create statement: \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(createTableStatement)
        }
    }
    
    /// Clear ChatTable directly using global connection
    private func clearChatTableDirectly() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearChatTableDirectly() - database not ready")
                return
            }
            
            // Drop and recreate table using global connection
            let dropTableString = "DROP TABLE IF EXISTS ChatTable"
            var dropTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearChatTableDirectly() - Table dropped successfully")
                } else {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearChatTableDirectly() - Failed to drop table: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearChatTableDirectly() - Failed to prepare drop statement: \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(dropTableStatement)
            
            // Recreate table
            let createTableString = """
            CREATE TABLE ChatTable (
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
                LastMessageSentByUserId TEXT
            );
            """
            var createTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(createTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearChatTableDirectly() - Table recreated successfully")
                } else {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearChatTableDirectly() - Failed to recreate table: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearChatTableDirectly() - Failed to prepare create statement: \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(createTableStatement)
        }
    }
    
    /// Clear MessageTable directly using global connection
    private func clearMessageTableDirectly() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMessageTableDirectly() - database not ready")
                return
            }
            
            // Drop and recreate table using global connection
            let dropTableString = "DROP TABLE IF EXISTS Message"
            var dropTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMessageTableDirectly() - Table dropped successfully")
                } else {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMessageTableDirectly() - Failed to drop table: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMessageTableDirectly() - Failed to prepare drop statement: \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(dropTableStatement)
            
            // Recreate table
            let createTableString = """
            CREATE TABLE Message (
                MessageId TEXT PRIMARY KEY NOT NULL,
                ChatId TEXT,
                Message TEXT,
                SenderId TEXT,
                Image TEXT,
                SendDate INT,
                DocId TEXT,
                AdAvailable INT,
                premium INT
            );
            """
            var createTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(createTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMessageTableDirectly() - Table recreated successfully")
                } else {
                    AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMessageTableDirectly() - Failed to recreate table: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMessageTableDirectly() - Failed to prepare create statement: \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(createTableStatement)
        }
    }
    
    /// Clear ProfileTable directly using global connection
    private func clearProfileTableDirectly() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearProfileTableDirectly() - database not ready")
                return
            }
            
            // Drop and recreate table using global connection
            let dropTableString = "DROP TABLE IF EXISTS ProfileTable"
            var dropTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearProfileTableDirectly() - Table dropped successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearProfileTableDirectly() - Failed to drop table: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearProfileTableDirectly() - Failed to prepare drop statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(dropTableStatement)
        
        // Recreate table (using the same schema as ProfileDB)
        let createTableString = """
        CREATE TABLE ProfileTable (
            UserId TEXT PRIMARY KEY NOT NULL,
            Age TEXT,
            Gender TEXT,
            Language TEXT,
            Country TEXT,
            men TEXT,
            women TEXT,
            single TEXT,
            married TEXT,
            children TEXT,
            gym TEXT,
            smoke TEXT,
            drink TEXT,
            games TEXT,
            decenttalk TEXT,
            pets TEXT,
            travel TEXT,
            music TEXT,
            movies TEXT,
            naughty TEXT,
            Foodie TEXT,
            dates TEXT,
            fashion TEXT,
            broken TEXT,
            depressed TEXT,
            lonely TEXT,
            cheated TEXT,
            insomnia TEXT,
            voice TEXT,
            video TEXT,
            pics TEXT,
            voicecalls TEXT,
            videocalls TEXT,
            goodexperience TEXT,
            badexperience TEXT,
            male_accounts TEXT,
            female_accounts TEXT,
            male_chats TEXT,
            female_chats TEXT,
            reports TEXT,
            blocks TEXT,
            Time INT,
            Image TEXT,
            Name TEXT,
            Height TEXT,
            Occupation TEXT,
            Instagram TEXT,
            Snapchat TEXT,
            Zodic TEXT,
            Hobbies TEXT,
            EmailVerified TEXT,
            CreatedTime TEXT,
            Platform TEXT,
            Premium TEXT,
            city TEXT
        );
        """
        var createTableStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearProfileTableDirectly() - Table recreated successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearProfileTableDirectly() - Failed to recreate table: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearProfileTableDirectly() - Failed to prepare create statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createTableStatement)
        }
    }
    
    /// Clear GameTable directly using global connection
    private func clearGameTableDirectly() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGameTableDirectly() - database not ready")
                return
            }
            
            // Drop and recreate table using global connection
            let dropTableString = "DROP TABLE IF EXISTS GameTable"
            var dropTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGameTableDirectly() - Table dropped successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGameTableDirectly() - Failed to drop table: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGameTableDirectly() - Failed to prepare drop statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(dropTableStatement)
        
        // Recreate table (using the same schema as GamesDB)
        let createTableString = """
        CREATE TABLE GameTable (
            GameId TEXT PRIMARY KEY NOT NULL,
            GameName TEXT,
            GameImage TEXT,
            GameDescription TEXT,
            GameUrl TEXT,
            GameCategory TEXT,
            GameRating TEXT,
            GamePlayers TEXT,
            GameTime INT,
            GameStatus INT
        );
        """
        var createTableStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGameTableDirectly() - Table recreated successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGameTableDirectly() - Failed to recreate table: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearGameTableDirectly() - Failed to prepare create statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createTableStatement)
        }
    }
    
    /// Clear RecentGameTable directly using global connection
    private func clearRecentGameTableDirectly() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearRecentGameTableDirectly() - database not ready")
                return
            }
            
            // Drop and recreate table using global connection
            let dropTableString = "DROP TABLE IF EXISTS RecentGameTable"
            var dropTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearRecentGameTableDirectly() - Table dropped successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearRecentGameTableDirectly() - Failed to drop table: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearRecentGameTableDirectly() - Failed to prepare drop statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(dropTableStatement)
        
        // Recreate table (using the same schema as GamesDB)
        let createTableString = """
        CREATE TABLE RecentGameTable (
            GameId TEXT PRIMARY KEY NOT NULL,
            GameName TEXT,
            GameImage TEXT,
            GameDescription TEXT,
            GameUrl TEXT,
            GameCategory TEXT,
            GameRating TEXT,
            GamePlayers TEXT,
            GameTime INT,
            GameStatus INT,
            LastPlayedTime INT
        );
        """
        var createTableStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearRecentGameTableDirectly() - Table recreated successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearRecentGameTableDirectly() - Failed to recreate table: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearRecentGameTableDirectly() - Failed to prepare create statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createTableStatement)
        }
    }
    
    /// Clear Notification table directly using global connection
    private func clearNotificationTableDirectly() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearNotificationTableDirectly() - database not ready")
                return
            }
            
            // Drop and recreate table using global connection
            let dropTableString = "DROP TABLE IF EXISTS Notification"
            var dropTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearNotificationTableDirectly() - Table dropped successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearNotificationTableDirectly() - Failed to drop table: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearNotificationTableDirectly() - Failed to prepare drop statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(dropTableStatement)
        
        // CRITICAL FIX: Don't recreate table here - let InAppNotificationDB handle it with correct schema
        // The table will be recreated by InAppNotificationDB.CreateNotification() with Android parity schema
        AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearNotificationTableDirectly() - Table dropped, InAppNotificationDB will recreate with correct schema")
        }
    }
    
    /// Clear MyProfileData table directly using global connection
    private func clearMyProfileTableDirectly() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMyProfileTableDirectly() - database not ready")
                return
            }
            
            // Drop and recreate table using global connection
            let dropTableString = "DROP TABLE IF EXISTS MyProfileData"
            var dropTableStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMyProfileTableDirectly() - Table dropped successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMyProfileTableDirectly() - Failed to drop table: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMyProfileTableDirectly() - Failed to prepare drop statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(dropTableStatement)
        
        // Recreate table (MyProfileData table - now deprecated, user profile stored in ProfileTable)
        let createTableString = """
        CREATE TABLE MyProfileData (
            Id TEXT PRIMARY KEY NOT NULL,
            Type TEXT,
            Time TEXT,
            Exist INT
        );
        """
        var createTableStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMyProfileTableDirectly() - Table recreated successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMyProfileTableDirectly() - Failed to recreate table: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: DatabaseCleanupService", message: "clearMyProfileTableDirectly() - Failed to prepare create statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(createTableStatement)
        }
    }
} 