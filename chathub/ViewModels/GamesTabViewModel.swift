import Foundation
import SwiftUI

class GamesTabViewModel: ObservableObject {
    @Published var gamesList: [Games] = []
    @Published var isLoading: Bool = false  // EFFICIENCY FIX: Start with false, only show loading when actually needed
    @Published var errorMessage: String?
    
    private let gamesDB = GamesDB.shared
    private let gamesService = GamesService.shared
    
    func loadGames() {
        AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() loading games data")
        
        // EFFICIENCY FIX: Load from database immediately first (instant display)
        let existingGames = gamesDB.query()
        AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() Found \(existingGames.count) existing games in database")
        
        if !existingGames.isEmpty {
            // Update UI with existing games immediately (instant display)
            self.gamesList = existingGames
            self.errorMessage = nil
            AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() instantly displayed \(existingGames.count) games from cache")
            
            // Log first few game names for debugging
            let gameNames = existingGames.prefix(3).map { $0.GameName }
            AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() sample games: \(gameNames)")
        } else {
            // No games in database, show loading and fetch
            AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() no games in database, showing loading and fetching")
            isLoading = true
            errorMessage = nil
            
            // CENTRALIZED: Use GamesCentralManager for all games operations
            GamesCentralManager.shared.ensureGamesAvailable { [weak self] success in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if success {
                        // Reload from database after successful fetch
                        let games = self.gamesDB.query()
                        self.gamesList = games
                        
                        if games.isEmpty {
                            self.errorMessage = "No games available. Please try again later."
                            AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() API fetch succeeded but no games in database")
                        } else {
                            AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() fetched and loaded \(games.count) games")
                        }
                    } else {
                        // Check if we have any cached games to show
                        let cachedGames = self.gamesDB.query()
                        if !cachedGames.isEmpty {
                            self.gamesList = cachedGames
                            self.errorMessage = "Using cached games. Unable to update from server."
                            AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() API failed but showing \(cachedGames.count) cached games")
                        } else {
                            self.errorMessage = "Unable to load games. Please check your internet connection and try again."
                            AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() failed to fetch games from API and no cached games available")
                        }
                    }
                    
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Initial load method that checks if data is needed (like OnlineUsersViewModel pattern)
    func initialLoadIfNeeded() {
        AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "initialLoadIfNeeded() checking if games load is needed")
        
        // Check if we already have games data
        if gamesList.isEmpty {
            AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "initialLoadIfNeeded() no games in memory, loading from database/API")
            loadGames()
        } else {
            AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "initialLoadIfNeeded() already have \\(gamesList.count) games in memory, skipping reload")
        }
    }
    
    func refreshGames() {
        AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "refreshGames() force refreshing games from API")
        
        isLoading = true
        errorMessage = nil
        
        // CENTRALIZED: Use GamesCentralManager for force refresh
        GamesCentralManager.shared.forceRefreshGames { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if success {
                    // Reload from database after successful fetch
                    let games = self.gamesDB.query()
                    self.gamesList = games
                    
                    if games.isEmpty {
                        self.errorMessage = "Refresh completed but no games available."
                        AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "refreshGames() refresh succeeded but no games in database")
                    } else {
                        AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "refreshGames() refreshed and loaded \(games.count) games")
                        
                        // Log sample game names for debugging
                        let gameNames = games.prefix(3).map { $0.GameName }
                        AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "refreshGames() sample refreshed games: \(gameNames)")
                    }
                } else {
                    // Keep existing games and show error
                    self.errorMessage = "Failed to refresh games. Showing cached data."
                    AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "refreshGames() failed to refresh games from API, keeping existing data")
                }
                
                self.isLoading = false
            }
        }
    }
    

    

}