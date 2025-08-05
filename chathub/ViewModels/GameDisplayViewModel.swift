import Foundation
import SwiftUI
import FirebaseFirestore

class GameDisplayViewModel: ObservableObject {
    @Published var isLoading = true
    
    private let gameUrl: String
    private var userId: String = ""
    private var deviceId: String = ""
    
    // Recent games tracking properties (Android parity)
    private let gamesDB = GamesDB.shared
    private var gameId: String = ""
    private var gameName: String = ""
    private var gameDescription: String = ""
    private var gameIcon: String = ""
    private var gameCover: String = ""
    private var gameRating: String = ""
    private var gamePlays: Int = 0
    private var isMultiplayer: Bool = false
    
    init(gameUrl: String) {
        self.gameUrl = gameUrl
        loadUserSession()
        extractGameMetadata()
    }
    
    private func loadUserSession() {
        // Use specialized UserSessionManager instead of monolithic SessionManager
        let userSessionManager = UserSessionManager.shared
        userId = userSessionManager.userId ?? ""
        deviceId = userSessionManager.deviceId ?? ""
        
        AppLogger.log(tag: "LOG-APP: GameDisplayView", message: "loadUserSession() User session loaded - userId: \(userId), deviceId: \(deviceId)")
    }
    
    private func extractGameMetadata() {
        // Extract game ID from URL (Android parity logic)
        // URL format: https://www.gamezop.com/g/GAME_ID?params...
        AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "extractGameMetadata() Processing URL: \(gameUrl)")
        
        if let urlComponents = URLComponents(string: gameUrl) {
            // Parse Gamezop URL format
            let pathComponents = urlComponents.path.components(separatedBy: "/")
            
            // Look for /g/GAME_ID pattern (Android parity)
            if let gIndex = pathComponents.firstIndex(of: "g"),
               gIndex + 1 < pathComponents.count {
                gameId = pathComponents[gIndex + 1]
                AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "extractGameMetadata() Extracted gameId from /g/ pattern: \(gameId)")
            } else if let lastComponent = pathComponents.last,
                     !lastComponent.isEmpty && lastComponent != "/" {
                gameId = lastComponent
                AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "extractGameMetadata() Extracted gameId from last path component: \(gameId)")
            } else {
                // Fallback: generate game ID from URL hash
                gameId = String(abs(gameUrl.hashValue))
                AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "extractGameMetadata() Using URL hash as gameId: \(gameId)")
            }
            
            // Try to get game details from database if available
            loadGameDetailsFromDatabase()
        } else {
            // Complete fallback for malformed URLs
            gameId = String(abs(gameUrl.hashValue))
            gameName = "Web Game"
            gameDescription = "Game played via web browser"
            gameIcon = ""
            gameCover = ""
            gameRating = "0"
            gamePlays = 0
            isMultiplayer = false
            AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "extractGameMetadata() Malformed URL, using complete fallback: \(gameId)")
        }
    }
    
    private func loadGameDetailsFromDatabase() {
        // Try to find game in database (Android parity)
        let allGames = gamesDB.query()
        if let foundGame = allGames.first(where: { $0.GameId == gameId }) {
            gameName = foundGame.GameName
            gameDescription = foundGame.GameDescription
            gameIcon = foundGame.GameIcon
            gameCover = foundGame.GameCover
            gameRating = foundGame.GameRating
            gamePlays = foundGame.GamePlays
            isMultiplayer = foundGame.Multiplayer
            AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "loadGameDetailsFromDatabase() Found game in database: \(gameName)")
        } else {
            // Game not in database - use URL-based defaults
            gameName = "Game \(gameId)"
            gameDescription = "Game accessed via direct URL"
            gameIcon = ""
            gameCover = ""
            gameRating = "0"
            gamePlays = 0
            isMultiplayer = false
            AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "loadGameDetailsFromDatabase() Game not found in database, using defaults")
        }
    }
    
    func startGameSession() {
        AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "startGameSession() Starting game session")
        
        // Set Firebase playing_games status to true (Android parity)
        setPlayingGamesStatus(isPlaying: true)
        
        // Save recent game data (Android parity - NEW FUNCTIONALITY)
        saveRecentGameData()
    }
    
    func endGameSession() {
        AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "endGameSession() Ending game session")
        
        // Set Firebase playing_games status to false (Android parity)
        setPlayingGamesStatus(isPlaying: false)
    }
    
    private func saveRecentGameData() {
        // Android parity: Save game to recent games database
        guard !gameId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "saveRecentGameData() gameId is empty, skipping recent game save")
            return
        }
        
        let currentTime = Date()
        
        AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "saveRecentGameData() Saving recent game - gameId: '\(gameId)', gameUrl: '\(gameUrl)', time: \(currentTime)")
        
        // SIMPLIFIED APPROACH: Just save game ID and timestamp (Android parity)
        // This will update the played time for existing games or add new minimal entries
        gamesDB.setGamePlayedTimeSimple(gameId: gameId, time: currentTime)
        
        AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "saveRecentGameData() Recent game saved successfully")
    }
    
    private func setPlayingGamesStatus(isPlaying: Bool) {
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "setPlayingGamesStatus() userId is empty, skipping Firebase update")
            return
        }
        
        let parameters: [String: Any] = ["playing_games": isPlaying]
        
        Firestore.firestore()
            .collection("Users")
            .document(userId)
            .setData(parameters, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "setPlayingGamesStatus() Firebase error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: GameDisplayViewModel", message: "setPlayingGamesStatus() playing_games set to \(isPlaying)")
                }
            }
    }
}