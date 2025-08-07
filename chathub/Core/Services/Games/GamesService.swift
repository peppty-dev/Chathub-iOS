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
            
            // Clear existing games before inserting new ones to prevent duplicates (Android parity)
            AppLogger.log(tag: "LOG-APP: GamesService", message: "parseAndStoreGamesData() clearing existing games before inserting new ones")
            self.gamesDB.deleteAllGamesFromGamesTable()
            
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
        
        // DEBUG: Log what we're trying to extract
        let gameId = gameData["code"] as? String
        let gameUrl = gameData["url"] as? String
        let gameName = extractString(gameData["name"])
        let gameDescription = extractString(gameData["description"])
        let assetsDict = gameData["assets"] as? [String: Any]
        let gameIcon = assetsDict != nil ? extractAsset(assetsDict!, keys: ["thumb", "icon", "cover"]) : nil
        let gameCover = assetsDict != nil ? extractAsset(assetsDict!, keys: ["cover", "thumb", "icon"]) : nil
        let gameRating = extractStringOrNumber(gameData["rating"])
        let gamePlays = extractStringOrNumber(gameData["gamePlays"])
        
        AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() extracted values - ID: '\(gameId ?? "nil")', Name: '\(gameName ?? "nil")', Rating: '\(gameRating ?? "nil")', Plays: '\(gamePlays ?? "nil")'")
        AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() extracted values - Icon: '\(gameIcon ?? "nil")', Cover: '\(gameCover ?? "nil")'")
        
        // Validate ONLY critical required fields (gameId, gameUrl, gameName are essential)
        // Make other fields optional with fallback values to prevent rejecting valid games
        guard let gameId = gameId, !gameId.isEmpty,
              let gameUrl = gameUrl, !gameUrl.isEmpty,
              let gameName = gameName, !gameName.isEmpty else {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() missing critical required fields - ID: '\(gameId ?? "nil")', URL: '\(gameUrl ?? "nil")', Name: '\(gameName ?? "nil")'. Available keys: \(gameData.keys)")
            return false
        }
        
        // Use fallback values for optional fields to prevent rejection
        let finalGameDescription = gameDescription ?? "No description available"
        let finalGameIcon = gameIcon ?? "https://via.placeholder.com/64x64.png?text=Game"
        let finalGameCover = gameCover ?? "https://via.placeholder.com/300x200.png?text=Game"
        let finalGameRating = gameRating ?? "4.0"
        let finalGamePlays = gamePlays ?? "0"
        
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
        
        // Validate rating is a valid number with fallback
        if Double(finalGameRating) == nil {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() invalid game rating: \(finalGameRating), using fallback 4.0")
        }
        
        // Validate game plays is a valid number with fallback
        let gamePlaysInt = Int(finalGamePlays) ?? 0
        if gamePlaysInt < 0 {
            AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() invalid game plays count: \(finalGamePlays), using fallback 0")
        }

        // Determine if multiplayer (Android parity logic)
        let isMultiplayer = MULTIPLAYER_GAMES.contains(gameId) ? 1 : 0

        // Log game details (Android parity)
        AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() validated game - ID: \(gameId), Name: \(gameName), Plays: \(gamePlaysInt), Multiplayer: \(isMultiplayer)")
        AppLogger.log(tag: "LOG-APP: GamesService", message: "processAndStoreGame() game details - Icon: \(finalGameIcon), Rating: \(finalGameRating), Description: \(finalGameDescription.prefix(50))...")

        // Insert into database (Android parity method) using final values with fallbacks
        gamesDB.insert(
            GameId: gameId as NSString,
            GameUrl: gameUrl as NSString,
            GameName: gameName as NSString,
            GameDescription: finalGameDescription as NSString,
            GameIcon: finalGameIcon as NSString,
            GameCover: finalGameCover as NSString,
            GameRating: finalGameRating as NSString,
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