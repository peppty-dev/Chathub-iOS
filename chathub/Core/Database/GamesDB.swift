import Foundation
import SQLite3

// MARK: - Removed unused GameData, GameValues, Assets, Categories, and Description structs
// These were not being used in the actual parsing logic and created unnecessary complexity
// iOS now uses direct JSON parsing to match Android's approach exactly

// MARK: - UI Layer Games Struct (iOS Legacy Compatibility)
struct Games {
    let GameId: String
    let GameUrl: String
    let GameName: String
    let GameDescription: String
    let GameIcon: String
    let GameCover: String
    let GameRating: String
    let GamePlays: Int
    let Multiplayer: Bool
    let Adavailable: Bool
    
    init(GameId: String, GameUrl: String, GameName: String, GameDescription: String,
         GameIcon: String, GameCover: String, GameRating: String, GamePlays: Int,
         Multiplayer: Bool, Adavailable: Bool = false) {
        self.GameId = GameId
        self.GameUrl = GameUrl
        self.GameName = GameName
        self.GameDescription = GameDescription
        self.GameIcon = GameIcon
        self.GameCover = GameCover
        self.GameRating = GameRating
        self.GamePlays = GamePlays
        self.Multiplayer = Multiplayer
        self.Adavailable = Adavailable
    }
    
    // Convenience initializer from Games_Table
    init(from gamesTable: Games_Table) {
        self.GameId = gamesTable.game_id
        self.GameUrl = gamesTable.game_url
        self.GameName = gamesTable.game_name
        self.GameDescription = gamesTable.game_description
        self.GameIcon = gamesTable.game_icon
        self.GameCover = gamesTable.game_cover
        self.GameRating = gamesTable.game_rating
        self.GamePlays = Int(gamesTable.game_plays) ?? 0
        self.Multiplayer = gamesTable.game_type == "Multiplayer"
        self.Adavailable = false // iOS doesn't use ads in games
    }
}

// CRITICAL FIX: Android-compatible Games_Table struct (no ads)
struct Games_Table {
    var id: Int = 0
    let game_id: String
    let game_url: String
    let game_name: String
    let game_description: String
    let game_icon: String
    let game_cover: String
    let game_rating: String
    let game_plays: String
    let game_type: String
    let game_played_time: Int64
    
    init(game_id: String, game_url: String, game_name: String, game_description: String, 
         game_icon: String, game_cover: String, game_rating: String, game_plays: String, 
         game_type: String, game_played_time: Int64) {
        self.game_id = game_id
        self.game_url = game_url
        self.game_name = game_name
        self.game_description = game_description
        self.game_icon = game_icon
        self.game_cover = game_cover
        self.game_rating = game_rating
        self.game_plays = game_plays
        self.game_type = game_type
        self.game_played_time = game_played_time
    }
}

class GamesDB {
    
    // CRITICAL FIX: Singleton pattern + thread-safe database operations using serial queue
    static let shared = GamesDB()
    private let dbQueue = DispatchQueue(label: "GamesDB.serialQueue", qos: .userInitiated)
    
    private init() {
        // Table creation will be handled by ensureTablesCreated() when called from DatabaseManager
        AppLogger.log(tag: "LOG-APP: GamesDB", message: "init() - GamesDB singleton initialized")
    }
    
    // Public method to ensure tables are created when database becomes ready
    func ensureTablesCreated() {
        createAndroidTable()
        //migrateFromOldStructure()
    }
    
    // CRITICAL FIX: Create Android-compatible Games_Table
    private func createAndroidTable() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "createAndroidTable() database not ready")
                return
            }
            
            // ANDROID PARITY: Create table only if it doesn't exist to preserve data
            let createTableString = """
        CREATE TABLE IF NOT EXISTS Games_Table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id TEXT NOT NULL,
            game_url TEXT,
            game_name TEXT,
            game_description TEXT,
            game_icon TEXT,
            game_cover TEXT,
            game_rating TEXT,
            game_plays TEXT,
            game_type TEXT,
            game_played_time INTEGER DEFAULT 0
        );
        """
            
            var createTableStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(createTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "createAndroidTable() Games_Table created successfully")
                    
                    // Create index for game_id for faster lookups
                    let createIndexString = "CREATE INDEX IF NOT EXISTS idx_game_id ON Games_Table(game_id);"
                    var indexStatement: OpaquePointer?
                    if sqlite3_prepare_v2(db, createIndexString, -1, &indexStatement, nil) == SQLITE_OK {
                        if sqlite3_step(indexStatement) == SQLITE_DONE {
                            AppLogger.log(tag: "LOG-APP: GamesDB", message: "createAndroidTable() Index created successfully")
                        }
                    }
                    sqlite3_finalize(indexStatement)
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "createAndroidTable() failed to create Games_Table: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "createAndroidTable() prepare statement failed: \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(createTableStatement)
        }
    }
    
    
    // CRITICAL FIX: Helper method to check if a column exists in a table
    private func checkColumnExists(tableName: String, columnName: String) -> Bool {
        let pragmaString = "PRAGMA table_info(\(tableName))"
        
        let result = DatabaseManager.shared.executeReadQuery(
            sql: pragmaString,
            parameters: []
        ) { statement in
            var columnExists = false
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let namePtr = sqlite3_column_text(statement, 1) {
                    let columnNameInTable = String(cString: namePtr)
                    if columnNameInTable == columnName {
                        columnExists = true
                        break
                    }
                }
            }
            
            AppLogger.log(tag: "LOG-APP: GamesDB", message: "checkColumnExists() Column '\(columnName)' in table '\(tableName)': \(columnExists ? "EXISTS" : "MISSING")")
            return columnExists
        }
        
        switch result {
        case .success(let exists):
            return exists
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: GamesDB", message: "checkColumnExists() Failed to check column existence: \(error)")
            return false
        }
    }
    
    func createrecenttable() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() database not ready")
                return
            }
            
            // ANDROID PARITY: Check if table exists with correct schema before dropping
            let checkTableQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='RecentGameTable'"
            var checkStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, checkTableQuery, -1, &checkStatement, nil) == SQLITE_OK {
                if sqlite3_step(checkStatement) == SQLITE_ROW {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() - RecentGameTable exists, validating schema")
                    
                    // Validate schema - check if all required columns exist
                    let requiredColumns = ["GameId", "GameUrl", "GameName", "GameDescription", "GameIcon", "GameCover", "GameRating", "GamePlays", "Multiplayer", "Time"]
                    var schemaValid = true
                    
                    for column in requiredColumns {
                        if !self.checkColumnExists(tableName: "RecentGameTable", columnName: column) {
                            schemaValid = false
                            AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() - Missing required column: \(column)")
                            break
                        }
                    }
                    
                    if schemaValid {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() - Schema validation passed, skipping table creation")
                        sqlite3_finalize(checkStatement)
                        return
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() - Schema incompatible, dropping and recreating table")
                        // Drop the table with incompatible schema
                        let dropTableString = "DROP TABLE IF EXISTS RecentGameTable;"
                        var dropTableStatement: OpaquePointer?
                        
                        if sqlite3_prepare_v2(db, dropTableString, -1, &dropTableStatement, nil) == SQLITE_OK {
                            if sqlite3_step(dropTableStatement) == SQLITE_DONE {
                                AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() - Incompatible RecentGameTable dropped successfully")
                            } else {
                                AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() - Failed to drop incompatible RecentGameTable: \(String(cString: sqlite3_errmsg(db)))")
                            }
                        } else {
                            AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() - Failed to prepare drop statement: \(String(cString: sqlite3_errmsg(db)))")
                        }
                        sqlite3_finalize(dropTableStatement)
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() - RecentGameTable does not exist, creating new Android parity schema")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() - Failed to check table existence: \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(checkStatement)
            
            // ANDROID PARITY: Create table with complete schema
            let createTableString = """
        CREATE TABLE RecentGameTable (
            GameId TEXT PRIMARY KEY NOT NULL,
            GameUrl TEXT,
            GameName TEXT,
            GameDescription TEXT,
            GameIcon TEXT,
            GameCover TEXT,
            GameRating TEXT,
            GamePlays INT,
            Multiplayer INT,
            Time INT);
        """
            var createTableStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(createTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() RecentGameTable created successfully with Android parity schema")
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() failed to create RecentGameTable: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "createrecenttable() prepare statement failed: \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(createTableStatement)
        }
    }
        
        func deletetable() {
            DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
                guard let db = db else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "deletetable() database not ready")
                    return
                }
                
                let createTableString = "DROP TABLE IF EXISTS GameTable"
                var createTableStatement: OpaquePointer?
                if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
                    if sqlite3_step(createTableStatement) == SQLITE_DONE {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "deletetable() GameTable deleted successfully")
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "deletetable() failed to delete GameTable: \(String(cString: sqlite3_errmsg(db)))")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "deletetable() prepare statement failed: \(String(cString: sqlite3_errmsg(db)))")
                }
                sqlite3_finalize(createTableStatement)
            }
        }
        
        func debugRecentGamesTable() {
            AppLogger.log(tag: "LOG-APP: GamesDB", message: "debugRecentGamesTable() - Checking RecentGameTable contents")
            
            let queryString = "SELECT GameId, GameName, GameUrl, GameIcon, Time FROM RecentGameTable ORDER BY Time DESC LIMIT 5;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: []
            ) { statement in
                var count = 0
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    count += 1
                    
                    var gameId = ""
                    var gameName = ""
                    var gameUrl = ""
                    var gameIcon = ""
                    
                    if let idPtr = sqlite3_column_text(statement, 0) {
                        gameId = String(cString: idPtr)
                    }
                    if let namePtr = sqlite3_column_text(statement, 1) {
                        gameName = String(cString: namePtr)
                    }
                    if let urlPtr = sqlite3_column_text(statement, 2) {
                        gameUrl = String(cString: urlPtr)
                    }
                    if let iconPtr = sqlite3_column_text(statement, 3) {
                        gameIcon = String(cString: iconPtr)
                    }
                    let time = Int(sqlite3_column_int(statement, 4))
                    
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "debugRecentGamesTable() Row \(count): GameId='\(gameId)', GameName='\(gameName)', GameUrl='\(gameUrl)', GameIcon='\(gameIcon)', Time=\(time)")
                }
                
                if count == 0 {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "debugRecentGamesTable() No records found in RecentGameTable")
                }
                
                return count
            }
            
            switch result {
            case .success(_):
                break // Already logged in the query block
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "debugRecentGamesTable() Failed to execute query: \(error)")
            }
        }
        
        // CRITICAL FIX: Clean up corrupted entries in RecentGameTable
        func cleanupCorruptedRecentGames() {
            AppLogger.log(tag: "LOG-APP: GamesDB", message: "cleanupCorruptedRecentGames() - Cleaning up corrupted recent games")
            
            DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
                guard let db = db else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "cleanupCorruptedRecentGames() database not ready")
                    return
                }
                
                // First, try to repair entries with missing names by looking up data from main table
                self.repairCorruptedRecentGames()
                
                // Then, delete entries that still have empty GameId or GameName
                var deleteStatement: OpaquePointer?
                let deleteString = "DELETE FROM RecentGameTable WHERE GameId = '' OR GameName = '' OR GameId IS NULL OR GameName IS NULL;"
                
                if sqlite3_prepare_v2(db, deleteString, -1, &deleteStatement, nil) == SQLITE_OK {
                    if sqlite3_step(deleteStatement) == SQLITE_DONE {
                        let deletedCount = sqlite3_changes(db)
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "cleanupCorruptedRecentGames() Successfully deleted \(deletedCount) corrupted entries")
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "cleanupCorruptedRecentGames() Failed to delete corrupted entries: \(String(cString: sqlite3_errmsg(db)))")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "cleanupCorruptedRecentGames() Failed to prepare delete statement: \(String(cString: sqlite3_errmsg(db)))")
                }
                sqlite3_finalize(deleteStatement)
            }
        }
        
        // CRITICAL FIX: Repair corrupted recent games by looking up data from main table
        func repairCorruptedRecentGames() {
            AppLogger.log(tag: "LOG-APP: GamesDB", message: "repairCorruptedRecentGames() - Attempting to repair corrupted recent games")
            
            DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
                guard let db = db else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "repairCorruptedRecentGames() database not ready")
                    return
                }
                
                // Find recent games with valid GameId but empty GameName
                var queryStatement: OpaquePointer?
                let queryString = "SELECT GameId, Time FROM RecentGameTable WHERE GameId != '' AND GameId IS NOT NULL AND (GameName = '' OR GameName IS NULL);"
                
                var corruptedEntries: [(gameId: String, time: Int)] = []
                
                if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK {
                    while sqlite3_step(queryStatement) == SQLITE_ROW {
                        var gameId = ""
                        if let idPtr = sqlite3_column_text(queryStatement, 0) {
                            gameId = String(cString: idPtr)
                        }
                        let time = Int(sqlite3_column_int(queryStatement, 1))
                        
                        if !gameId.isEmpty {
                            corruptedEntries.append((gameId: gameId, time: time))
                        }
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "repairCorruptedRecentGames() Failed to prepare query: \(String(cString: sqlite3_errmsg(db)))")
                }
                sqlite3_finalize(queryStatement)
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "repairCorruptedRecentGames() Found \(corruptedEntries.count) corrupted entries to repair")
                
                // For each corrupted entry, try to get proper data from main table
                for entry in corruptedEntries {
                    var gameQueryStatement: OpaquePointer?
                    let gameQueryString = "SELECT GameUrl, GameName, GameDescription, GameIcon, GameCover, GameRating, GamePlays, Multiplayer FROM GameTable WHERE GameId = ?;"
                    
                    if sqlite3_prepare_v2(db, gameQueryString, -1, &gameQueryStatement, nil) == SQLITE_OK {
                        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                        sqlite3_bind_text(gameQueryStatement, 1, entry.gameId, -1, SQLITE_TRANSIENT)
                        
                        if sqlite3_step(gameQueryStatement) == SQLITE_ROW {
                            // Extract data from main table
                            var gameUrl = ""
                            var gameName = ""
                            var gameDescription = ""
                            var gameIcon = ""
                            var gameCover = ""
                            var gameRating = ""
                            
                            if let urlPtr = sqlite3_column_text(gameQueryStatement, 0) {
                                gameUrl = String(cString: urlPtr)
                            }
                            if let namePtr = sqlite3_column_text(gameQueryStatement, 1) {
                                gameName = String(cString: namePtr)
                            }
                            if let descPtr = sqlite3_column_text(gameQueryStatement, 2) {
                                gameDescription = String(cString: descPtr)
                            }
                            if let iconPtr = sqlite3_column_text(gameQueryStatement, 3) {
                                gameIcon = String(cString: iconPtr)
                            }
                            if let coverPtr = sqlite3_column_text(gameQueryStatement, 4) {
                                gameCover = String(cString: coverPtr)
                            }
                            if let ratingPtr = sqlite3_column_text(gameQueryStatement, 5) {
                                gameRating = String(cString: ratingPtr)
                            }
                            
                            let gamePlays = Int(sqlite3_column_int(gameQueryStatement, 6))
                            let multiplayer = Int(sqlite3_column_int(gameQueryStatement, 7))
                            
                            // Only repair if we have a valid game name
                            if !gameName.isEmpty {
                                // Update the recent game entry with proper data
                                var updateStatement: OpaquePointer?
                                let updateString = "UPDATE RecentGameTable SET GameUrl = ?, GameName = ?, GameDescription = ?, GameIcon = ?, GameCover = ?, GameRating = ?, GamePlays = ?, Multiplayer = ? WHERE GameId = ? AND Time = ?;"
                                
                                if sqlite3_prepare_v2(db, updateString, -1, &updateStatement, nil) == SQLITE_OK {
                                    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                                    sqlite3_bind_text(updateStatement, 1, gameUrl, -1, SQLITE_TRANSIENT)
                                    sqlite3_bind_text(updateStatement, 2, gameName, -1, SQLITE_TRANSIENT)
                                    sqlite3_bind_text(updateStatement, 3, gameDescription, -1, SQLITE_TRANSIENT)
                                    sqlite3_bind_text(updateStatement, 4, gameIcon, -1, SQLITE_TRANSIENT)
                                    sqlite3_bind_text(updateStatement, 5, gameCover, -1, SQLITE_TRANSIENT)
                                    sqlite3_bind_text(updateStatement, 6, gameRating, -1, SQLITE_TRANSIENT)
                                    sqlite3_bind_int(updateStatement, 7, Int32(gamePlays))
                                    sqlite3_bind_int(updateStatement, 8, Int32(multiplayer))
                                    sqlite3_bind_text(updateStatement, 9, entry.gameId, -1, SQLITE_TRANSIENT)
                                    sqlite3_bind_int(updateStatement, 10, Int32(entry.time))
                                    
                                    if sqlite3_step(updateStatement) == SQLITE_DONE {
                                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "repairCorruptedRecentGames() Successfully repaired entry for gameId: \(entry.gameId) with name: '\(gameName)'")
                                    } else {
                                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "repairCorruptedRecentGames() Failed to update entry for gameId: \(entry.gameId): \(String(cString: sqlite3_errmsg(db)))")
                                    }
                                } else {
                                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "repairCorruptedRecentGames() Failed to prepare update for gameId: \(entry.gameId): \(String(cString: sqlite3_errmsg(db)))")
                                }
                                sqlite3_finalize(updateStatement)
                            } else {
                                AppLogger.log(tag: "LOG-APP: GamesDB", message: "repairCorruptedRecentGames() Main table entry for gameId: \(entry.gameId) also has empty name, cannot repair")
                            }
                        } else {
                            AppLogger.log(tag: "LOG-APP: GamesDB", message: "repairCorruptedRecentGames() No matching entry found in main table for gameId: \(entry.gameId)")
                        }
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "repairCorruptedRecentGames() Failed to prepare game query for gameId: \(entry.gameId): \(String(cString: sqlite3_errmsg(db)))")
                    }
                    sqlite3_finalize(gameQueryStatement)
                }
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "repairCorruptedRecentGames() Repair operation completed")
            }
        }
        
        // MARK: - Simplified Recent Games Methods (Android Parity)
        
        
        
        // MARK: - Public Migration Method
        
        // CRITICAL FIX: Public method to force database migration for existing users
        func forceDatabaseMigration() {
            AppLogger.log(tag: "LOG-APP: GamesDB", message: "forceDatabaseMigration() Starting forced migration")
            
            DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
                guard let db = db else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "forceDatabaseMigration() database not ready")
                    return
                }
                
                // Check and add game_played_time column if missing
                if !self.checkColumnExists(tableName: "GameTable", columnName: "game_played_time") {
                    let alterTableString = "ALTER TABLE GameTable ADD COLUMN game_played_time INT DEFAULT 0"
                    var alterStatement: OpaquePointer?
                    if sqlite3_prepare_v2(db, alterTableString, -1, &alterStatement, nil) == SQLITE_OK {
                        if sqlite3_step(alterStatement) == SQLITE_DONE {
                            AppLogger.log(tag: "LOG-APP: GamesDB", message: "forceDatabaseMigration() Successfully added game_played_time column")
                        } else {
                            AppLogger.log(tag: "LOG-APP: GamesDB", message: "forceDatabaseMigration() Failed to add game_played_time column: \(String(cString: sqlite3_errmsg(db)))")
                        }
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "forceDatabaseMigration() Failed to prepare ALTER TABLE: \(String(cString: sqlite3_errmsg(db)))")
                    }
                    sqlite3_finalize(alterStatement)
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "forceDatabaseMigration() game_played_time column already exists")
                }
            }
        }
        
        // MARK: - Android Parity Methods
        
        // Migration helper method
        func migrateFromOldStructure() {
            AppLogger.log(tag: "LOG-APP: GamesDB", message: "migrateFromOldStructure() Starting migration from old iOS structure")
            
            DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
                guard let db = db else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "migrateFromOldStructure() database not ready")
                    return
                }
                
                // Check if old tables exist and migrate data
                var queryStatement: OpaquePointer?
                let checkOldTableString = "SELECT name FROM sqlite_master WHERE type='table' AND name='GameTable';"
                
                if sqlite3_prepare_v2(db, checkOldTableString, -1, &queryStatement, nil) == SQLITE_OK {
                    if sqlite3_step(queryStatement) == SQLITE_ROW {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "migrateFromOldStructure() Old GameTable found, migrating data")
                        
                        // Migrate data from old GameTable to new Games_Table
                        let migrateString = """
                INSERT OR IGNORE INTO Games_Table 
                (game_id, game_url, game_name, game_description, game_icon, game_cover, game_rating, game_plays, game_type, game_played_time)
                SELECT GameId, GameUrl, GameName, GameDescription, GameIcon, GameCover, GameRating, 
                       CAST(GamePlays AS TEXT), 
                       CASE WHEN Multiplayer = 1 THEN 'Multiplayer' ELSE 'Single player' END,
                       COALESCE(game_played_time, 0)
                FROM GameTable;
                """
                        
                        var migrateStatement: OpaquePointer?
                        if sqlite3_prepare_v2(db, migrateString, -1, &migrateStatement, nil) == SQLITE_OK {
                            if sqlite3_step(migrateStatement) == SQLITE_DONE {
                                AppLogger.log(tag: "LOG-APP: GamesDB", message: "migrateFromOldStructure() Successfully migrated data from old GameTable")
                            } else {
                                AppLogger.log(tag: "LOG-APP: GamesDB", message: "migrateFromOldStructure() Failed to migrate data: \(String(cString: sqlite3_errmsg(db)))")
                            }
                        }
                        sqlite3_finalize(migrateStatement)
                    }
                }
                sqlite3_finalize(queryStatement)
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "migrateFromOldStructure() Migration completed")
            }
        }
        
        // Android: void insert(Games_Table games_table)
        func insert(_ games_table: Games_Table) {
            DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
                guard let db = db else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "insert() database not ready")
                    return
                }
                
                let insertString = """
            INSERT OR IGNORE INTO Games_Table 
            (game_id, game_url, game_name, game_description, game_icon, game_cover, game_rating, game_plays, game_type, game_played_time) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
                
                var insertStatement: OpaquePointer?
                if sqlite3_prepare_v2(db, insertString, -1, &insertStatement, nil) == SQLITE_OK {
                    // CRITICAL FIX: Use SQLITE_TRANSIENT to ensure SQLite makes a copy of string data
                    // This prevents corruption when Swift's memory management deallocates the original strings
                    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    
                    sqlite3_bind_text(insertStatement, 1, games_table.game_id, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(insertStatement, 2, games_table.game_url, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(insertStatement, 3, games_table.game_name, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(insertStatement, 4, games_table.game_description, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(insertStatement, 5, games_table.game_icon, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(insertStatement, 6, games_table.game_cover, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(insertStatement, 7, games_table.game_rating, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(insertStatement, 8, games_table.game_plays, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(insertStatement, 9, games_table.game_type, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int64(insertStatement, 10, games_table.game_played_time)
                    
                    if sqlite3_step(insertStatement) == SQLITE_DONE {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "insert() Successfully inserted game: \(games_table.game_name)")
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "insert() Failed to insert game: \(String(cString: sqlite3_errmsg(db)))")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "insert() Failed to prepare statement: \(String(cString: sqlite3_errmsg(db)))")
                }
                sqlite3_finalize(insertStatement)
            }
        }
        
        // Android: DataSource.Factory<Integer, Games_Table> selectGames()
        func selectGames() -> [Games_Table] {
            let queryString = "SELECT * FROM Games_Table WHERE game_id != '' AND game_name != '' AND game_id IS NOT NULL AND game_name IS NOT NULL ORDER BY id ASC;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: []
            ) { statement in
                var games: [Games_Table] = []
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int(statement, 0))
                    
                    // Safe string extraction with null checks
                    let game_id = sqlite3_column_text(statement, 1) != nil ? String(cString: sqlite3_column_text(statement, 1)) : ""
                    let game_url = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)) : ""
                    let game_name = sqlite3_column_text(statement, 3) != nil ? String(cString: sqlite3_column_text(statement, 3)) : ""
                    let game_description = sqlite3_column_text(statement, 4) != nil ? String(cString: sqlite3_column_text(statement, 4)) : ""
                    let game_icon = sqlite3_column_text(statement, 5) != nil ? String(cString: sqlite3_column_text(statement, 5)) : ""
                    let game_cover = sqlite3_column_text(statement, 6) != nil ? String(cString: sqlite3_column_text(statement, 6)) : ""
                    let game_rating = sqlite3_column_text(statement, 7) != nil ? String(cString: sqlite3_column_text(statement, 7)) : "0"
                    let game_plays = sqlite3_column_text(statement, 8) != nil ? String(cString: sqlite3_column_text(statement, 8)) : "0"
                    let game_type = sqlite3_column_text(statement, 9) != nil ? String(cString: sqlite3_column_text(statement, 9)) : "Single player"
                    let game_played_time = sqlite3_column_int64(statement, 10)
                    
                    // Double-check: Skip games with empty critical fields (should not happen with WHERE clause)
                    if game_id.isEmpty || game_name.isEmpty {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectGames() Skipping game with empty critical fields - ID: '\(game_id)', Name: '\(game_name)'")
                        continue
                    }
                    
                    var game = Games_Table(
                        game_id: game_id,
                        game_url: game_url,
                        game_name: game_name,
                        game_description: game_description,
                        game_icon: game_icon,
                        game_cover: game_cover,
                        game_rating: game_rating,
                        game_plays: game_plays,
                        game_type: game_type,
                        game_played_time: game_played_time
                    )
                    game.id = id
                    games.append(game)
                }
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectGames() Retrieved \(games.count) valid games")
                return games
            }
            
            switch result {
            case .success(let games):
                return games
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectGames() Failed to execute query: \(error)")
                return []
            }
        }
        
        // Alternative method that includes all games (for debugging)
        func selectAllGamesIncludingCorrupted() -> [Games_Table] {
            let queryString = "SELECT * FROM Games_Table ORDER BY id ASC;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: []
            ) { statement in
                var games: [Games_Table] = []
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int(statement, 0))
                    
                    // Safe string extraction with null checks
                    let game_id = sqlite3_column_text(statement, 1) != nil ? String(cString: sqlite3_column_text(statement, 1)) : ""
                    let game_url = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)) : ""
                    let game_name = sqlite3_column_text(statement, 3) != nil ? String(cString: sqlite3_column_text(statement, 3)) : ""
                    let game_description = sqlite3_column_text(statement, 4) != nil ? String(cString: sqlite3_column_text(statement, 4)) : ""
                    let game_icon = sqlite3_column_text(statement, 5) != nil ? String(cString: sqlite3_column_text(statement, 5)) : ""
                    let game_cover = sqlite3_column_text(statement, 6) != nil ? String(cString: sqlite3_column_text(statement, 6)) : ""
                    let game_rating = sqlite3_column_text(statement, 7) != nil ? String(cString: sqlite3_column_text(statement, 7)) : "0"
                    let game_plays = sqlite3_column_text(statement, 8) != nil ? String(cString: sqlite3_column_text(statement, 8)) : "0"
                    let game_type = sqlite3_column_text(statement, 9) != nil ? String(cString: sqlite3_column_text(statement, 9)) : "Single player"
                    let game_played_time = sqlite3_column_int64(statement, 10)
                    
                    // Log corrupted entries but include them
                    if game_id.isEmpty || game_name.isEmpty {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectAllGamesIncludingCorrupted() Found corrupted game - ID: '\(game_id)', Name: '\(game_name)'")
                    }
                    
                    var game = Games_Table(
                        game_id: game_id,
                        game_url: game_url,
                        game_name: game_name,
                        game_description: game_description,
                        game_icon: game_icon,
                        game_cover: game_cover,
                        game_rating: game_rating,
                        game_plays: game_plays,
                        game_type: game_type,
                        game_played_time: game_played_time
                    )
                    game.id = id
                    games.append(game)
                }
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectAllGamesIncludingCorrupted() Retrieved \(games.count) total games")
                return games
            }
            
            switch result {
            case .success(let games):
                return games
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectAllGamesIncludingCorrupted() Failed to execute query: \(error)")
                return []
            }
        }
        
        // Android: void setGamePlayedTime(String game_id, long time)
        func setGamePlayedTime(game_id: String, time: Int64) {
            DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
                guard let db = db else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "setGamePlayedTime() database not ready")
                    return
                }
                
                let updateString = "UPDATE Games_Table SET game_played_time = ? WHERE game_id = ?;"
                var updateStatement: OpaquePointer?
                if sqlite3_prepare_v2(db, updateString, -1, &updateStatement, nil) == SQLITE_OK {
                    sqlite3_bind_int64(updateStatement, 1, time)
                    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    sqlite3_bind_text(updateStatement, 2, game_id, -1, SQLITE_TRANSIENT)
                    
                    if sqlite3_step(updateStatement) == SQLITE_DONE {
                        let rowsAffected = sqlite3_changes(db)
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "setGamePlayedTime() Successfully updated game_played_time for game_id: \(game_id), rows affected: \(rowsAffected)")
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "setGamePlayedTime() Failed to update game_played_time: \(String(cString: sqlite3_errmsg(db)))")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "setGamePlayedTime() Failed to prepare statement: \(String(cString: sqlite3_errmsg(db)))")
                }
                sqlite3_finalize(updateStatement)
            }
        }
        
        // Simplified version that accepts Date and converts to timestamp
        func setGamePlayedTimeSimple(gameId: String, time: Date) {
            let timestamp = Int64(time.timeIntervalSince1970 * 1000) // Convert to milliseconds like Android
            AppLogger.log(tag: "LOG-APP: GamesDB", message: "setGamePlayedTimeSimple() gameId: \(gameId), timestamp: \(timestamp)")
            
            // Check if game exists in table first
            if isGameInTable(game_id: gameId) {
                // Game exists, update the played time
                setGamePlayedTime(game_id: gameId, time: timestamp)
            } else {
                // Game doesn't exist, create a minimal entry
                insertMinimalGameEntry(gameId: gameId, timestamp: timestamp)
            }
        }
        
        // Helper method to insert minimal game entry for tracking played time
        func insertMinimalGameEntry(gameId: String, timestamp: Int64) {
            DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
                guard let db = db else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "insertMinimalGameEntry() database not ready")
                    return
                }
                
                let insertString = """
                INSERT INTO Games_Table (game_id, game_url, game_name, game_description, game_icon, game_cover, game_rating, game_plays, game_type, game_played_time)
                VALUES (?, '', ?, 'Game accessed via direct URL', '', '', '0', '0', 'Single', ?);
            """
                var insertStatement: OpaquePointer?
                if sqlite3_prepare_v2(db, insertString, -1, &insertStatement, nil) == SQLITE_OK {
                    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    sqlite3_bind_text(insertStatement, 1, gameId, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(insertStatement, 2, "Game \(gameId)", -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int64(insertStatement, 3, timestamp)
                    
                    if sqlite3_step(insertStatement) == SQLITE_DONE {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "insertMinimalGameEntry() Successfully inserted minimal game entry for gameId: \(gameId)")
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "insertMinimalGameEntry() Failed to insert minimal game entry: \(String(cString: sqlite3_errmsg(db)))")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "insertMinimalGameEntry() Failed to prepare statement: \(String(cString: sqlite3_errmsg(db)))")
                }
                sqlite3_finalize(insertStatement)
            }
        }
        
        // Android: DataSource.Factory<Integer, Games_Table> selectRecentGames()
        func selectRecentGames() -> [Games_Table] {
            let queryString = "SELECT * FROM Games_Table WHERE game_played_time != 0 ORDER BY game_played_time DESC LIMIT 20;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: []
            ) { statement in
                var games: [Games_Table] = []
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int(statement, 0))
                    
                    // Safe string extraction with null checks
                    let game_id = sqlite3_column_text(statement, 1) != nil ? String(cString: sqlite3_column_text(statement, 1)) : ""
                    let game_url = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)) : ""
                    let game_name = sqlite3_column_text(statement, 3) != nil ? String(cString: sqlite3_column_text(statement, 3)) : ""
                    let game_description = sqlite3_column_text(statement, 4) != nil ? String(cString: sqlite3_column_text(statement, 4)) : ""
                    let game_icon = sqlite3_column_text(statement, 5) != nil ? String(cString: sqlite3_column_text(statement, 5)) : ""
                    let game_cover = sqlite3_column_text(statement, 6) != nil ? String(cString: sqlite3_column_text(statement, 6)) : ""
                    let game_rating = sqlite3_column_text(statement, 7) != nil ? String(cString: sqlite3_column_text(statement, 7)) : "0"
                    let game_plays = sqlite3_column_text(statement, 8) != nil ? String(cString: sqlite3_column_text(statement, 8)) : "0"
                    let game_type = sqlite3_column_text(statement, 9) != nil ? String(cString: sqlite3_column_text(statement, 9)) : "Single player"
                    let game_played_time = sqlite3_column_int64(statement, 10)
                    
                    // Skip games with empty critical fields
                    if game_id.isEmpty || game_name.isEmpty {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectRecentGames() Skipping game with empty critical fields - ID: '\(game_id)', Name: '\(game_name)'")
                        continue
                    }
                    
                    var game = Games_Table(
                        game_id: game_id,
                        game_url: game_url,
                        game_name: game_name,
                        game_description: game_description,
                        game_icon: game_icon,
                        game_cover: game_cover,
                        game_rating: game_rating,
                        game_plays: game_plays,
                        game_type: game_type,
                        game_played_time: game_played_time
                    )
                    game.id = id
                    games.append(game)
                }
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectRecentGames() Retrieved \(games.count) recent games")
                return games
            }
            
            switch result {
            case .success(let games):
                return games
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectRecentGames() Failed to execute query: \(error)")
                return []
            }
        }
        
        // Android: DataSource.Factory<Integer, Games_Table> selectGamesByType(String type)
        func selectGamesByType(type: String) -> [Games_Table] {
            let queryString = "SELECT * FROM Games_Table WHERE game_type = ? ORDER BY game_played_time DESC;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: [type]
            ) { statement in
                var games: [Games_Table] = []
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int(statement, 0))
                    
                    // Safe string extraction with null checks
                    let game_id = sqlite3_column_text(statement, 1) != nil ? String(cString: sqlite3_column_text(statement, 1)) : ""
                    let game_url = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)) : ""
                    let game_name = sqlite3_column_text(statement, 3) != nil ? String(cString: sqlite3_column_text(statement, 3)) : ""
                    let game_description = sqlite3_column_text(statement, 4) != nil ? String(cString: sqlite3_column_text(statement, 4)) : ""
                    let game_icon = sqlite3_column_text(statement, 5) != nil ? String(cString: sqlite3_column_text(statement, 5)) : ""
                    let game_cover = sqlite3_column_text(statement, 6) != nil ? String(cString: sqlite3_column_text(statement, 6)) : ""
                    let game_rating = sqlite3_column_text(statement, 7) != nil ? String(cString: sqlite3_column_text(statement, 7)) : "0"
                    let game_plays = sqlite3_column_text(statement, 8) != nil ? String(cString: sqlite3_column_text(statement, 8)) : "0"
                    let game_type = sqlite3_column_text(statement, 9) != nil ? String(cString: sqlite3_column_text(statement, 9)) : "Single player"
                    let game_played_time = sqlite3_column_int64(statement, 10)
                    
                    // Skip games with empty critical fields
                    if game_id.isEmpty || game_name.isEmpty {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectGamesByType() Skipping game with empty critical fields - ID: '\(game_id)', Name: '\(game_name)'")
                        continue
                    }
                    
                    var game = Games_Table(
                        game_id: game_id,
                        game_url: game_url,
                        game_name: game_name,
                        game_description: game_description,
                        game_icon: game_icon,
                        game_cover: game_cover,
                        game_rating: game_rating,
                        game_plays: game_plays,
                        game_type: game_type,
                        game_played_time: game_played_time
                    )
                    game.id = id
                    games.append(game)
                }
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectGamesByType() Retrieved \(games.count) games of type: \(type)")
                return games
            }
            
            switch result {
            case .success(let games):
                return games
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "selectGamesByType() Failed to execute query: \(error)")
                return []
            }
        }
        
        // Android: boolean isGameInTable(String game_id)
        func isGameInTable(game_id: String) -> Bool {
            let queryString = "SELECT id FROM Games_Table WHERE game_id = ? LIMIT 1;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: [game_id]
            ) { statement in
                var exists = false
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    exists = true
                }
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "isGameInTable() game_id: \(game_id) exists: \(exists)")
                return exists
            }
            
            switch result {
            case .success(let exists):
                return exists
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "isGameInTable() Failed to execute query: \(error)")
                return false
            }
        }
        
        // Android: int getGameIdFromTable(String game_id)
        func getGameIdFromTable(game_id: String) -> Int {
            let queryString = "SELECT id FROM Games_Table WHERE game_id = ? LIMIT 1;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: [game_id]
            ) { statement in
                var id = 0
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    id = Int(sqlite3_column_int(statement, 0))
                }
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "getGameIdFromTable() game_id: \(game_id) table_id: \(id)")
                return id
            }
            
            switch result {
            case .success(let id):
                return id
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "getGameIdFromTable() Failed to execute query: \(error)")
                return 0
            }
        }
        
        // Android: void deleteAllGamesFromGamesTable()
        func deleteAllGamesFromGamesTable() {
            DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
                guard let db = db else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "deleteAllGamesFromGamesTable() database not ready")
                    return
                }
                
                let deleteString = "DELETE FROM Games_Table;"
                var deleteStatement: OpaquePointer?
                if sqlite3_prepare_v2(db, deleteString, -1, &deleteStatement, nil) == SQLITE_OK {
                    if sqlite3_step(deleteStatement) == SQLITE_DONE {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "deleteAllGamesFromGamesTable() Successfully deleted all games")
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "deleteAllGamesFromGamesTable() Failed to delete all games: \(String(cString: sqlite3_errmsg(db)))")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "deleteAllGamesFromGamesTable() Failed to prepare statement: \(String(cString: sqlite3_errmsg(db)))")
                }
                sqlite3_finalize(deleteStatement)
            }
        }
        
        // MARK: - UI Layer Methods (iOS Legacy Compatibility)
        
        /// Main query method for UI - returns all games as Games structs
        func query() -> [Games] {
            let gamesTableResults = selectGames()
            return gamesTableResults.map { Games(from: $0) }
        }
        
        /// Query multiplayer games for UI - returns multiplayer games as Games structs
        func querymultiplayer() -> [Games] {
            let multiplayerGamesTable = selectGamesByType(type: "Multiplayer")
            return multiplayerGamesTable.map { Games(from: $0) }
        }
        
        /// Query recent games for UI - returns recent games as Games structs
        func queryrecent() -> [Games] {
            let recentGamesTable = selectRecentGames()
            return recentGamesTable.map { Games(from: $0) }
        }
        
        /// Get games count for debugging
        func gamescount() -> Int {
            let queryString = "SELECT COUNT(*) FROM Games_Table;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: []
            ) { statement in
                var count = 0
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(statement, 0))
                }
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "gamescount() Total games: \(count)")
                return count
            }
            
            switch result {
            case .success(let count):
                return count
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "gamescount() Failed to execute query: \(error)")
                return 0
            }
        }
        
        /// Get count of valid games (with non-empty critical fields)
        func validGamesCount() -> Int {
            let queryString = "SELECT COUNT(*) FROM Games_Table WHERE game_id != '' AND game_name != '' AND game_id IS NOT NULL AND game_name IS NOT NULL;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: []
            ) { statement in
                var count = 0
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(statement, 0))
                }
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "validGamesCount() Valid games: \(count)")
                return count
            }
            
            switch result {
            case .success(let count):
                return count
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "validGamesCount() Failed to execute query: \(error)")
                return 0
            }
        }
        
        /// Get count of corrupted games (with empty critical fields)
        func corruptedGamesCount() -> Int {
            let queryString = "SELECT COUNT(*) FROM Games_Table WHERE game_id = '' OR game_name = '' OR game_id IS NULL OR game_name IS NULL;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: []
            ) { statement in
                var count = 0
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(statement, 0))
                }
                
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "corruptedGamesCount() Corrupted games: \(count)")
                return count
            }
            
            switch result {
            case .success(let count):
                return count
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "corruptedGamesCount() Failed to execute query: \(error)")
                return 0
            }
        }
        
        /// Clean up corrupted game entries
        func cleanupCorruptedGames(completion: @escaping (Int) -> Void) {
            DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
                guard let db = db else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "cleanupCorruptedGames() database not ready")
                    completion(0)
                    return
                }
                
                let deleteString = "DELETE FROM Games_Table WHERE game_id = '' OR game_name = '' OR game_id IS NULL OR game_name IS NULL;"
                var deleteStatement: OpaquePointer?
                var deletedCount = 0
                
                if sqlite3_prepare_v2(db, deleteString, -1, &deleteStatement, nil) == SQLITE_OK {
                    if sqlite3_step(deleteStatement) == SQLITE_DONE {
                        deletedCount = Int(sqlite3_changes(db))
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "cleanupCorruptedGames() Successfully deleted \(deletedCount) corrupted entries")
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesDB", message: "cleanupCorruptedGames() Failed to delete corrupted entries: \(String(cString: sqlite3_errmsg(db)))")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "cleanupCorruptedGames() Failed to prepare delete statement: \(String(cString: sqlite3_errmsg(db)))")
                }
                sqlite3_finalize(deleteStatement)
                
                completion(deletedCount)
            }
        }
        
        /// Debug method to show sample corrupted data
        func debugCorruptedGames() {
            let queryString = "SELECT id, game_id, game_name, game_url FROM Games_Table WHERE game_id = '' OR game_name = '' OR game_id IS NULL OR game_name IS NULL LIMIT 10;"
            
            let result = DatabaseManager.shared.executeReadQuery(
                sql: queryString,
                parameters: []
            ) { statement in
                var count = 0
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    count += 1
                    let id = Int(sqlite3_column_int(statement, 0))
                    let game_id = sqlite3_column_text(statement, 1) != nil ? String(cString: sqlite3_column_text(statement, 1)) : "NULL"
                    let game_name = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)) : "NULL"
                    let game_url = sqlite3_column_text(statement, 3) != nil ? String(cString: sqlite3_column_text(statement, 3)) : "NULL"
                    
                    AppLogger.log(tag: "LOG-APP: GamesDB", message: "debugCorruptedGames() Row \(count): ID=\(id), game_id='\(game_id)', game_name='\(game_name)', game_url='\(game_url)'")
                }
                
                return count
            }
            
            switch result {
            case .success(let count):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "debugCorruptedGames() Found \(count) corrupted entries (showing first 10)")
            case .failure(let error):
                AppLogger.log(tag: "LOG-APP: GamesDB", message: "debugCorruptedGames() Failed to execute query: \(error)")
            }
        }
        
        /// Legacy insert method for iOS compatibility - converts old format to new Games_Table
        func insert(GameId: NSString, GameUrl: NSString, GameName: NSString, GameDescription: NSString,
                    GameIcon: NSString, GameCover: NSString, GameRating: NSString, GamePlays: Int, Multiplayer: Int) {
            
            // Convert to Games_Table format
            let gameType = Multiplayer == 1 ? "Multiplayer" : "Single player"
            let gamePlaysString = String(GamePlays)
            
            let gamesTable = Games_Table(
                game_id: GameId as String,
                game_url: GameUrl as String,
                game_name: GameName as String,
                game_description: GameDescription as String,
                game_icon: GameIcon as String,
                game_cover: GameCover as String,
                game_rating: GameRating as String,
                game_plays: gamePlaysString,
                game_type: gameType,
                game_played_time: 0
            )
            
            // Insert using the new Android-compatible method
            insert(gamesTable)
            
            AppLogger.log(tag: "LOG-APP: GamesDB", message: "insert() Legacy insert completed for game: \(GameName)")
        }
    }

