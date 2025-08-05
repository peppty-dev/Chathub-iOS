import Foundation
import SQLite3

struct ProfileModel {
    var UserId : String
    var Premium: String
    var EmailVerified: String
    var CreatedTime: String
    var Age : String
    var Gender: String
    var Language: String
    var city: String
    var Country:  String
    var Platform: String
    var Height: String
    var men: String
    var women: String
    var single: String
    var married: String
    var children: String
    var gym: String
    var smoke: String
    var drink: String
    var Occupation: String
    var games: String
    var decenttalk: String
    var pets: String
    var Hobbies: String
    var travel: String
    var Zodic: String
    var music: String
    var movies: String
    var naughty: String
    var Foodie: String
    var dates: String
    var fashion: String
    var broken: String
    var depressed: String
    var lonely: String
    var cheated: String
    var insomnia: String
    var voice: String
    var video: String
    var pics: String
    var voicecalls: String
    var videocalls: String
    var goodexperience: String
    var badexperience : String
    var male_accounts : String
    var female_accounts: String
    var male_chats: String
    var female_chats : String
    var blocks: String
    var reports: String
    var Snapchat: String
    var Instagram: String
    var Image: String
    var Name: String
    var Time: Int
}
                  
class ProfileDB {
    
    // CRITICAL FIX: Singleton pattern + thread-safe database operations using serial queue
    static let shared = ProfileDB()
    private let dbQueue = DispatchQueue(label: "ProfileDB.serialQueue", qos: .userInitiated)
    
    private init() {
        // Table creation will be handled by ensureTableCreated() when called from DatabaseManager
        AppLogger.log(tag: "LOG-APP: ProfileDB", message: "init() - ProfileDB singleton initialized")
    }
    
    // Public method to ensure table is created when database becomes ready
    func ensureTableCreated() {
        createtable()
    }
    
    func createtable() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "createtable() database not ready")
                return
            }
        
        // ANDROID PARITY: Create table only if it doesn't exist to preserve existing data
        let createTableString = """
        CREATE TABLE IF NOT EXISTS ProfileTable (
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
            city TEXT);
        """
        
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "createtable() Profile table created successfully or already exists")
            } else {
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "createtable() failed to create ProfileTable: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: ProfileDB", message: "createtable() prepare statement failed: \(String(cString: sqlite3_errmsg(db)))")
        }
            sqlite3_finalize(createTableStatement)
            
            // Apply any necessary schema migrations for existing tables
            self.migrateDatabaseSchemaInner(db: db)
        }
    }
    
    private func migrateDatabaseSchema() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else { return }
            self.migrateDatabaseSchemaInner(db: db)
        }
    }
    
    private func migrateDatabaseSchemaInner(db: OpaquePointer) {
        AppLogger.log(tag: "LOG-APP: ProfileDB", message: "migrateDatabaseSchema() Starting database schema migration")
        
        // List of columns that might be missing in older database versions
        let columnsToAdd = [
            "married TEXT",
            "Height TEXT",
            "Occupation TEXT", 
            "Instagram TEXT",
            "Snapchat TEXT",
            "Zodic TEXT",
            "Hobbies TEXT",
            "EmailVerified TEXT",
            "CreatedTime TEXT",
            "Platform TEXT",
            "Premium TEXT",
            "city TEXT"
        ]
        
        for columnDef in columnsToAdd {
            let columnName = columnDef.components(separatedBy: " ").first ?? ""
            
            // Check if column already exists before adding
            if !columnExistsInner(db: db, tableName: "ProfileTable", columnName: columnName) {
                let alterTableString = "ALTER TABLE ProfileTable ADD COLUMN \(columnDef);"
                
                var alterStatement: OpaquePointer?
                if sqlite3_prepare_v2(db, alterTableString, -1, &alterStatement, nil) == SQLITE_OK {
                    if sqlite3_step(alterStatement) == SQLITE_DONE {
                        AppLogger.log(tag: "LOG-APP: ProfileDB", message: "migrateDatabaseSchema() ✅ Added column: \(columnName)")
                    } else {
                        AppLogger.log(tag: "LOG-APP: ProfileDB", message: "migrateDatabaseSchema() ❌ Failed to add column \(columnName): \(String(cString: sqlite3_errmsg(db)))")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfileDB", message: "migrateDatabaseSchema() ❌ Failed to prepare statement for column \(columnName): \(String(cString: sqlite3_errmsg(db)))")
                }
                sqlite3_finalize(alterStatement)
            } else {
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "migrateDatabaseSchema() ℹ️ Column \(columnName) already exists, skipping migration")
            }
        }
        
        AppLogger.log(tag: "LOG-APP: ProfileDB", message: "migrateDatabaseSchema() Database schema migration completed")
    }
    
    // MARK: - Helper Methods
    
    /// Check if a column exists in a table
    private func columnExists(tableName: String, columnName: String) -> Bool {
        var result = false
        DatabaseManager.shared.executeOnDatabaseQueue { db in
            guard let db = db else { return }
            result = self.columnExistsInner(db: db, tableName: tableName, columnName: columnName)
        }
        return result
    }
    
    private func columnExistsInner(db: OpaquePointer, tableName: String, columnName: String) -> Bool {
        let pragmaSQL = "PRAGMA table_info(\(tableName));"
        var pragmaStatement: OpaquePointer?
        var columnExists = false
        
        if sqlite3_prepare_v2(db, pragmaSQL, -1, &pragmaStatement, nil) == SQLITE_OK {
            while sqlite3_step(pragmaStatement) == SQLITE_ROW {
                if let columnNamePtr = sqlite3_column_text(pragmaStatement, 1) {
                    let existingColumnName = String(cString: columnNamePtr)
                    if existingColumnName.lowercased() == columnName.lowercased() {
                        columnExists = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(pragmaStatement)
        
        return columnExists
    }
    
    func deletetable() {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "deletetable() database not ready")
                return
            }
            
            let createTableString = "DROP TABLE IF EXISTS ProfileTable"
            var createTableStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
                if sqlite3_step(createTableStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: ProfileDB", message: "deletetable() ProfileTable deleted successfully")
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfileDB", message: "deletetable() failed to delete ProfileTable: \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "deletetable() prepare statement failed: \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(createTableStatement)
        }
    }
    
    func query(UserId: String) -> ProfileModel? {
        let queryStatementString = "SELECT UserId, Age, Gender, Language, Country, men, women, single, married, children, gym, smoke, drink, games, decenttalk, pets, travel, music, movies, naughty, Foodie, dates, fashion, broken, depressed, lonely, cheated, insomnia, voice, video, pics, voicecalls, videocalls, goodexperience, badexperience, male_accounts, female_accounts, male_chats, female_chats, reports, blocks, Time, Image, Name, Height, Occupation, Instagram, Snapchat, Zodic, Hobbies, EmailVerified, CreatedTime, Platform, Premium, city FROM ProfileTable WHERE UserId = ?;"
        
        AppLogger.log(tag: "LOG-APP: ProfileDB", message: "query() 🔍 Searching for UserId: '\(UserId)'")
        
        let result = DatabaseManager.shared.executeReadQuery(
            sql: queryStatementString,
            parameters: [UserId]
        ) { statement in
            AppLogger.log(tag: "LOG-APP: ProfileDB", message: "query() 📋 SQL prepared successfully, executing query...")
            
            var psns: ProfileModel? = nil
            var rowCount = 0
            
            while sqlite3_step(statement) == SQLITE_ROW {
                rowCount += 1
                let UserId = String(cString: sqlite3_column_text(statement, 0))
                let Userdetails1 = String(cString: sqlite3_column_text(statement, 1))
                let Userdetails2 = String(cString: sqlite3_column_text(statement, 2))
                let Userdetails3 = String(cString: sqlite3_column_text(statement, 3))
                let Userdetails4 = String(cString: sqlite3_column_text(statement, 4))
                let Userdetails5 = String(cString: sqlite3_column_text(statement, 5))
                let Userdetails6 = String(cString: sqlite3_column_text(statement, 6))
                let Userdetails7 = String(cString: sqlite3_column_text(statement, 7))
                let Userdetails8 = String(cString: sqlite3_column_text(statement, 8))
                let Userdetails9 = String(cString: sqlite3_column_text(statement, 9))
                let Userdetails10 = String(cString: sqlite3_column_text(statement, 10))
                let Userdetails11 = String(cString: sqlite3_column_text(statement, 11))
                let Userdetails12 = String(cString: sqlite3_column_text(statement, 12))
                let Userdetails13 = String(cString: sqlite3_column_text(statement, 13))
                let Userdetails14 = String(cString: sqlite3_column_text(statement, 14))
                let Userdetails15 = String(cString: sqlite3_column_text(statement, 15))
                let Userdetails16 = String(cString: sqlite3_column_text(statement, 16))
                let Userdetails17 = String(cString: sqlite3_column_text(statement, 17))
                let Userdetails18 = String(cString: sqlite3_column_text(statement, 18))
                let Userdetails19 = String(cString: sqlite3_column_text(statement, 19))
                let Userdetails20 = String(cString: sqlite3_column_text(statement, 20))
                let Userdetails21 = String(cString: sqlite3_column_text(statement, 21))
                let Userdetails22 = String(cString: sqlite3_column_text(statement, 22))
                let Userdetails23 = String(cString: sqlite3_column_text(statement, 23))
                let Userdetails24 = String(cString: sqlite3_column_text(statement, 24))
                let Userdetails25 = String(cString: sqlite3_column_text(statement, 25))
                let Userdetails26 = String(cString: sqlite3_column_text(statement, 26))
                let Userdetails27 = String(cString: sqlite3_column_text(statement, 27))
                let Userdetails28 = String(cString: sqlite3_column_text(statement, 28))
                let Userdetails29 = String(cString: sqlite3_column_text(statement, 29))
                let Userdetails30 = String(cString: sqlite3_column_text(statement, 30))
                let Userdetails31 = String(cString: sqlite3_column_text(statement, 31))
                let Userdetails32 = String(cString: sqlite3_column_text(statement, 32))
                let Userdetails33 = String(cString: sqlite3_column_text(statement, 33))
                let Userdetails34 = String(cString: sqlite3_column_text(statement, 34))
                let Userdetails35 = String(cString: sqlite3_column_text(statement, 35))
                let Userdetails36 = String(cString: sqlite3_column_text(statement, 36))
                let Userdetails37 = String(cString: sqlite3_column_text(statement, 37))
                let Userdetails38 = String(cString: sqlite3_column_text(statement, 38))
                let Userdetails39 = String(cString: sqlite3_column_text(statement, 39))
                let Userdetails40 = String(cString: sqlite3_column_text(statement, 40))
                let Userdetails41 = String(cString: sqlite3_column_text(statement, 41))
                let Userdetails42 = Int(TimeInterval(sqlite3_column_int(statement, 42)))
                let Userdetails43 = String(cString: sqlite3_column_text(statement, 43))
                let Userdetails44 = String(cString: sqlite3_column_text(statement, 44))
                let Userdetails45 = String(cString: sqlite3_column_text(statement, 45))
                let Userdetails46 = String(cString: sqlite3_column_text(statement, 46))
                let Userdetails47 = String(cString: sqlite3_column_text(statement, 47))
                let Userdetails48 = String(cString: sqlite3_column_text(statement, 48))
                let Userdetails49 = String(cString: sqlite3_column_text(statement, 49))
                let Userdetails50 = String(cString: sqlite3_column_text(statement, 50))
                let Userdetails51 = String(cString: sqlite3_column_text(statement, 51))
                let Userdetails52 = String(cString: sqlite3_column_text(statement, 52))
                let Userdetails53 = String(cString: sqlite3_column_text(statement, 53))
                let Userdetails54 = String(cString: sqlite3_column_text(statement, 54))
                let userdata = ProfileModel(UserId: UserId, Premium: Userdetails53, EmailVerified: Userdetails50, CreatedTime: Userdetails51, Age: Userdetails1, Gender: Userdetails2, Language: Userdetails3, city: Userdetails54, Country: Userdetails4, Platform: Userdetails52, Height: Userdetails44, men: Userdetails5, women: Userdetails6, single: Userdetails7, married: Userdetails8, children: Userdetails9, gym: Userdetails10, smoke: Userdetails11, drink: Userdetails12, Occupation: Userdetails45, games: Userdetails13, decenttalk: Userdetails14, pets: Userdetails15, Hobbies: Userdetails49, travel: Userdetails16, Zodic: Userdetails48, music: Userdetails17, movies: Userdetails18, naughty: Userdetails19, Foodie: Userdetails20, dates: Userdetails21, fashion: Userdetails22, broken: Userdetails23, depressed: Userdetails24, lonely: Userdetails25, cheated: Userdetails26, insomnia: Userdetails27, voice: Userdetails28, video: Userdetails29, pics: Userdetails30, voicecalls: Userdetails31, videocalls: Userdetails32, goodexperience: Userdetails33, badexperience: Userdetails34, male_accounts: Userdetails35, female_accounts: Userdetails36, male_chats: Userdetails37, female_chats: Userdetails38, blocks: Userdetails40, reports: Userdetails39, Snapchat: Userdetails47, Instagram: Userdetails46, Image: Userdetails43, Name: Userdetails43, Time: Userdetails42)
                psns = userdata
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "query() ✅ Found profile for UserId: '\(UserId)', Name: '\(Userdetails43)', Age: '\(Userdetails1)', Time: \(Userdetails42)")
            }
            
            AppLogger.log(tag: "LOG-APP: ProfileDB", message: "query() 📊 Query completed, found \(rowCount) rows")
            
            if psns == nil {
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "query() ❌ No profile found for UserId: '\(UserId)'")
            }
            
            return psns
        }
        
        switch result {
        case .success(let profile):
            return profile
        case .failure(let error):
            AppLogger.log(tag: "LOG-APP: ProfileDB", message: "query() ❌ Failed to execute query: \(error)")
            return nil
        }
    }
    
    func insert(UserId: NSString, Age: NSString, Country: NSString, Language: NSString, Gender: NSString, men: NSString, women: NSString, single: NSString, married: NSString, children: NSString, gym: NSString, smoke: NSString, drink: NSString, games: NSString, decenttalk: NSString, pets: NSString, travel: NSString, music: NSString, movies: NSString, naughty: NSString, Foodie: NSString, dates: NSString, fashion: NSString, broken: NSString, depressed: NSString, lonely: NSString, cheated: NSString, insomnia: NSString, voice: NSString, video: NSString, pics: NSString, goodexperience: NSString, badexperience: NSString, male_accounts: NSString, female_accounts: NSString, male_chats: NSString, female_chats: NSString, reports: NSString, blocks: NSString, voicecalls: NSString, videocalls: NSString, Time: Date, Image: NSString, Named: NSString, Height: NSString, Occupation: NSString, Instagram: NSString, Snapchat: NSString, Zodic: NSString, Hobbies: NSString, EmailVerified: NSString, CreatedTime: NSString, Platform: NSString, Premium: NSString, city: NSString) {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "insert() database not ready")
                return
            }
            
            AppLogger.log(tag: "LOG-APP: ProfileDB", message: "insert() inserting profile for UserId: '\(UserId)', Name: '\(Named)'")
            AppLogger.log(tag: "LOG-APP: ProfileDB", message: "insert() Profile data - Age: '\(Age)', Gender: '\(Gender)', Country: '\(Country)', Platform: '\(Platform)'")
            AppLogger.log(tag: "LOG-APP: ProfileDB", message: "insert() Additional data - Height: '\(Height)', Occupation: '\(Occupation)', City: '\(city)', EmailVerified: '\(EmailVerified)', CreatedTime: '\(CreatedTime)'")
            
            var insertStatement: OpaquePointer?
        let insertStatementString = "INSERT INTO ProfileTable (UserId, Age, Gender, Language, Country, men, women, single, married, children, gym, smoke, drink, games, decenttalk, pets, travel, music, movies, naughty, Foodie, dates, fashion, broken, depressed, lonely, cheated, insomnia, voice, video, pics, voicecalls, videocalls, goodexperience, badexperience, male_accounts, female_accounts, male_chats, female_chats, reports, blocks, Time, Image, Name, Height, Occupation, Instagram, Snapchat, Zodic, Hobbies, EmailVerified, CreatedTime, Platform, Premium, city) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        
        let prepareResult = sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil)
        if prepareResult == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, UserId.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, Age.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, Gender.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 4, Language.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 5, Country.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 6, men.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 7, women.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 8, single.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 9, married.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 10, children.utf8String , -1, nil)
            sqlite3_bind_text(insertStatement, 11, gym.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 12, smoke.utf8String , -1, nil)
            sqlite3_bind_text(insertStatement, 13, drink.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 14, games.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 15, decenttalk.utf8String , -1, nil)
            sqlite3_bind_text(insertStatement, 16, pets.utf8String , -1, nil)
            sqlite3_bind_text(insertStatement, 17, travel.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 18, music.utf8String , -1, nil)
            sqlite3_bind_text(insertStatement, 19, movies.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 20, naughty.utf8String , -1, nil)
            sqlite3_bind_text(insertStatement, 21, Foodie.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 22, dates.utf8String , -1, nil)
            sqlite3_bind_text(insertStatement, 23, fashion.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 24, broken.utf8String , -1, nil)
            sqlite3_bind_text(insertStatement, 25, depressed.utf8String , -1, nil)
            sqlite3_bind_text(insertStatement, 26, lonely.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 27, cheated.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 28, insomnia.utf8String , -1, nil)
            sqlite3_bind_text(insertStatement, 29, voice.utf8String , -1, nil)
            sqlite3_bind_text(insertStatement, 30, video.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 31, pics.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 32, voicecalls.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 33, videocalls.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 34, goodexperience.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 35, badexperience.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 36, male_accounts.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 37, female_accounts.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 38, male_chats.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 39, female_chats.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 40, reports.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 41, blocks.utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 42, Int32(Time.timeIntervalSince1970))
            sqlite3_bind_text(insertStatement, 43, Image.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 44, Named.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 45, Height.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 46, Occupation.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 47, Instagram.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 48, Snapchat.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 49, Zodic.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 50, Hobbies.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 51, EmailVerified.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 52, CreatedTime.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 53, Platform.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 54, Premium.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 55, city.utf8String, -1, nil)
            let stepResult = sqlite3_step(insertStatement)
            if stepResult == SQLITE_DONE {
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "insert() ✅ Successfully inserted profile for UserId: '\(UserId)'")
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "insert() ❌ Error inserting profile for UserId: '\(UserId)' - SQLite Error: \(errorMsg)")
            }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "insert() ❌ Failed to prepare insert statement for UserId: '\(UserId)' - SQLite Error: \(errorMsg)")
            }
            sqlite3_finalize(insertStatement)
        }
    }
    
    func delete(UserId: String) {
        DatabaseManager.shared.executeOnDatabaseQueueAsync { db in
            guard let db = db else {
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "delete() database not ready")
                return
            }
            
            AppLogger.log(tag: "LOG-APP: ProfileDB", message: "delete() deleting profile for UserId: '\(UserId)'")
            var updateStatement: OpaquePointer?
            let updateStatementString = "DELETE FROM ProfileTable WHERE UserId = ?;"
            if sqlite3_prepare_v2(db, updateStatementString, -1, &updateStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(updateStatement, 1, UserId, -1, nil)
                if sqlite3_step(updateStatement) == SQLITE_DONE {
                    AppLogger.log(tag: "LOG-APP: ProfileDB", message: "delete() ✅ Successfully deleted profile for UserId: '\(UserId)'")
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfileDB", message: "delete() ❌ Error deleting profile for UserId: '\(UserId)'")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: ProfileDB", message: "delete() ❌ Failed to prepare delete statement for UserId: '\(UserId)'")
            }
            sqlite3_finalize(updateStatement)
        }
    }
}
