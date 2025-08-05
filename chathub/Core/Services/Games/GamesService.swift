import Foundation
import UIKit

class GamesService {
    
    // MARK: - Singleton
    static let shared = GamesService()
    private init() {}
    
    // MARK: - Properties
    private let sessionManager = SessionManager.shared
    private let gamesDB = GamesDB.shared
    
    // MARK: - Constants (matching Android)
    private let GAMEZOP_API_URL = "https://pub.gamezop.com/v3/games?id=3190"
    private let MULTIPLAYER_GAMES = "rkt7TzJv9k7,Sy8y2aQ9CB,rkAXTzkD5kX,rJWyhp79RS,SJgx126Qc0H,rJiWkhaQ9CS,Hk2yhp7cCH,rkmJ2aXcCS,SkhljT2fdgb,H1IEpMJP917,H1WmafkP9JQ,H1Hgyn6XqAS"
    
    // MARK: - Retry Configuration
    private let MAX_RETRY_ATTEMPTS = 3
    private let RETRY_DELAY_BASE: TimeInterval = 2.0 // Base delay in seconds
    
    // MARK: - Public Methods
    
    /// Fetches games from Gamezop API and stores in local database (Android parity method)
    func fetchAndStoreGames(completion: @escaping (Bool) -> Void = { _ in }) {
        fetchAndStoreGamesWithRetry(attempt: 1, completion: completion)
    }
    
    /// Checks if games need to be fetched and fetches them if necessary
    func fetchGamesIfNeeded(completion: @escaping (Bool) -> Void = { _ in }) {
        AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchGamesIfNeeded() checking if fetch needed")
        
        // Check if games already fetched (Android parity logic)
        if sessionManager.gamesFetched && gamesDB.gamescount() > 0 {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchGamesIfNeeded() games already available, skipping fetch")
            completion(true)
            return
        }
        
        AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchGamesIfNeeded() games not available, fetching...")
        fetchAndStoreGames(completion: completion)
    }
    
    // MARK: - Debug Methods
    
    /// Tests API connectivity and logs detailed response for debugging
    func testAPIConnection() {
        AppLogger.log(tag: "LOG-APP: GamesService", message: "testAPIConnection() testing Gamezop API connectivity")
        
        guard let url = URL(string: GAMEZOP_API_URL) else {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "testAPIConnection() invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // Just check if endpoint is reachable
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: GamesService", message: "testAPIConnection() API unreachable: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                AppLogger.log(tag: "LOG-APP: GamesService", message: "testAPIConnection() API status: \(httpResponse.statusCode)")
            }
        }.resume()
    }
    
    /// Gets current database and fetch status for debugging
    func getDatabaseStatus() -> String {
        let count = gamesDB.gamescount()
        let fetched = sessionManager.gamesFetched
        return "Games in DB: \(count), Fetched flag: \(fetched)"
    }
    
    /// Resets games fetch status and clears database for testing
    func resetGamesData() {
        AppLogger.log(tag: "LOG-APP: GamesService", message: "resetGamesData() clearing games data and fetch status")
        
        // Clear fetch status
        sessionManager.gamesFetched = false
        
        // Clear games from database
        gamesDB.deleteAllGamesFromGamesTable()
        
        AppLogger.log(tag: "LOG-APP: GamesService", message: "resetGamesData() games data cleared")
    }
    
    // MARK: - Private Methods with Retry Logic
    
    /// Fetches games with retry mechanism and exponential backoff
    private func fetchAndStoreGamesWithRetry(attempt: Int, completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchAndStoreGamesWithRetry() attempt \(attempt)/\(MAX_RETRY_ATTEMPTS)")
        
        guard let url = URL(string: GAMEZOP_API_URL) else {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchAndStoreGamesWithRetry() invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchAndStoreGamesWithRetry() network error attempt \(attempt): \(error.localizedDescription)")
                
                if attempt < self.MAX_RETRY_ATTEMPTS {
                    let delay = self.RETRY_DELAY_BASE * pow(2.0, Double(attempt - 1)) // Exponential backoff
                    AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchAndStoreGamesWithRetry() retrying in \(delay) seconds...")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.fetchAndStoreGamesWithRetry(attempt: attempt + 1, completion: completion)
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchAndStoreGamesWithRetry() max retry attempts reached, failing")
                    completion(false)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchAndStoreGamesWithRetry() invalid response type")
                
                if attempt < self.MAX_RETRY_ATTEMPTS {
                    let delay = self.RETRY_DELAY_BASE * pow(2.0, Double(attempt - 1))
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.fetchAndStoreGamesWithRetry(attempt: attempt + 1, completion: completion)
                    }
                } else {
                    completion(false)
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                guard let data = data else {
                    AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchAndStoreGamesWithRetry() no data received")
                    
                    if attempt < self.MAX_RETRY_ATTEMPTS {
                        let delay = self.RETRY_DELAY_BASE * pow(2.0, Double(attempt - 1))
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.fetchAndStoreGamesWithRetry(attempt: attempt + 1, completion: completion)
                        }
                    } else {
                        completion(false)
                    }
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchAndStoreGamesWithRetry() received data on attempt \(attempt), parsing...")
                self.parseAndStoreGamesData(data) { success in
                    if success {
                        // Mark games as fetched in session manager (Android parity)
                        self.sessionManager.gamesFetched = true
                        AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchAndStoreGamesWithRetry() completed successfully on attempt \(attempt)")
                        completion(true)
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchAndStoreGamesWithRetry() parsing failed on attempt \(attempt)")
                        
                        if attempt < self.MAX_RETRY_ATTEMPTS {
                            let delay = self.RETRY_DELAY_BASE * pow(2.0, Double(attempt - 1))
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                self.fetchAndStoreGamesWithRetry(attempt: attempt + 1, completion: completion)
                            }
                        } else {
                            completion(false)
                        }
                    }
                }
            } else {
                AppLogger.log(tag: "LOG-APP: GamesService", message: "fetchAndStoreGamesWithRetry() HTTP error attempt \(attempt): \(httpResponse.statusCode)")
                
                if attempt < self.MAX_RETRY_ATTEMPTS {
                    let delay = self.RETRY_DELAY_BASE * pow(2.0, Double(attempt - 1))
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.fetchAndStoreGamesWithRetry(attempt: attempt + 1, completion: completion)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    /// Parses JSON response and stores games in database (Android parity method)
    private func parseAndStoreGamesData(_ data: Data, completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: GamesService", message: "parseAndStoreGamesData() parsing JSON response")
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let gamesArray = json["games"] as? [[String: Any]] else {
                AppLogger.log(tag: "LOG-APP: GamesService", message: "parseAndStoreGamesData() invalid JSON structure")
                completion(false)
                return
            }
            
            AppLogger.log(tag: "LOG-APP: GamesService", message: "parseAndStoreGamesData() found \(gamesArray.count) games")
            
            // Process games in background thread (Android parity)
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                
                var successCount = 0
                
                for gameData in gamesArray {
                    if self.processAndStoreGame(gameData) {
                        successCount += 1
                    }
                }
                
                DispatchQueue.main.async {
                    let success = successCount > 0
                    AppLogger.log(tag: "LOG-APP: GamesService", message: "parseAndStoreGamesData() stored \(successCount)/\(gamesArray.count) games")
                    completion(success)
                }
            }
            
        } catch {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "parseAndStoreGamesData() JSON parsing error: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    /// Processes and stores a single game from API response (Android parity method)
    private func processAndStoreGame(_ gameData: [String: Any]) -> Bool {
        AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() processing game data")
        
        // Helper to extract localized or direct string
        func extractString(_ value: Any?) -> String? {
            if let str = value as? String {
                return str
            } else if let dict = value as? [String: Any] {
                // Try "en" first, then any value
                if let en = dict["en"] as? String {
                    return en
                } else if let first = dict.values.first as? String {
                    return first
                }
            }
            return nil
        }
        
        // Helper to extract string or number as string
        func extractStringOrNumber(_ value: Any?) -> String? {
            if let str = value as? String {
                return str
            } else if let num = value as? NSNumber {
                return num.stringValue
            } else if let int = value as? Int {
                return String(int)
            } else if let double = value as? Double {
                return String(double)
            }
            return nil
        }
        
        // Helper to extract icon/cover from assets
        func extractAsset(_ dict: [String: Any], keys: [String]) -> String? {
            for key in keys {
                if let val = dict[key] as? String, !val.isEmpty {
                    return val
                }
            }
            return nil
        }
        
        // Validate required fields exist and are not empty
        guard let gameId = gameData["code"] as? String, !gameId.isEmpty,
              let gameUrl = gameData["url"] as? String, !gameUrl.isEmpty,
              let gameName = extractString(gameData["name"]), !gameName.isEmpty,
              let gameDescription = extractString(gameData["description"]), !gameDescription.isEmpty,
              let assetsDict = gameData["assets"] as? [String: Any],
              let gameIcon = extractAsset(assetsDict, keys: ["thumb", "icon", "cover"]), !gameIcon.isEmpty,
              let gameCover = extractAsset(assetsDict, keys: ["cover", "thumb", "icon"]), !gameCover.isEmpty,
              let gameRating = extractStringOrNumber(gameData["rating"]), !gameRating.isEmpty,
              let gamePlays = extractStringOrNumber(gameData["gamePlays"]), !gamePlays.isEmpty else {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() missing or empty required fields for game. Available keys: \(gameData.keys)")
            return false
        }
        
        // Additional validation for critical fields
        if gameId.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty ||
           gameName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() game has empty critical fields after trimming - ID: '\(gameId)', Name: '\(gameName)'")
            return false
        }
        
        // Validate URL format
        if !gameUrl.hasPrefix("http://") && !gameUrl.hasPrefix("https://") {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() invalid game URL format: \(gameUrl)")
            return false
        }
        
        // Validate rating is a valid number
        if Double(gameRating) == nil {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() invalid game rating: \(gameRating)")
            return false
        }
        
        // Validate game plays is a valid number
        let gamePlaysInt = Int(gamePlays) ?? 0
        if gamePlaysInt < 0 {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() invalid game plays count: \(gamePlays)")
            return false
        }

        // Determine if multiplayer (Android parity logic)
        let isMultiplayer = MULTIPLAYER_GAMES.contains(gameId) ? 1 : 0

        // Log game details (Android parity)
        AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() validated game - ID: \(gameId), Name: \(gameName), Plays: \(gamePlaysInt), Multiplayer: \(isMultiplayer)")

        // Insert into database (Android parity method)
        gamesDB.insert(
            GameId: gameId as NSString,
            GameUrl: gameUrl as NSString,
            GameName: gameName as NSString,
            GameDescription: gameDescription as NSString,
            GameIcon: gameIcon as NSString,
            GameCover: gameCover as NSString,
            GameRating: gameRating as NSString,
            GamePlays: gamePlaysInt,
            Multiplayer: isMultiplayer
        )

        return true
    }
}

// MARK: - SessionManager Extension for Games Support
extension SessionManager {
    
    // MARK: - Games Fetched Status (Android parity)
    
    /// Gets whether games have been fetched from API
    var gamesFetched: Bool {
        get { UserDefaults.standard.bool(forKey: "gamesFetched") }
        set { UserDefaults.standard.set(newValue, forKey: "gamesFetched") }
    }
    
    /// Sets games fetched status (Android parity method)
    func setGamesFetched(_ fetched: Bool) {
        gamesFetched = fetched
        synchronize()
    }
    
    /// Gets games fetched status (Android parity method)
    func isGamesFetched() -> Bool {
        return gamesFetched
    }
} 