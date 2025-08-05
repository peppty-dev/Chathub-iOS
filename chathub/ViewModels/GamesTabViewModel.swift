import Foundation
import SwiftUI

class GamesTabViewModel: ObservableObject {
    @Published var gamesList: [Games] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    
    private let gamesDB = GamesDB.shared
    private let gamesService = GamesService.shared
    
    func loadGames() {
        AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() loading games data")
        
        isLoading = true
        errorMessage = nil
        
        // First try to load from database
        let existingGames = gamesDB.query()
        
        if !existingGames.isEmpty {
            // Update UI with existing games immediately (Android parity)
            DispatchQueue.main.async {
                self.gamesList = existingGames
                self.isLoading = false
                AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() loaded \(existingGames.count) games from database")
            }
        } else {
            // No games in database, fetch from API (Android parity)
            AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "loadGames() no games in database, fetching from API")
            
            gamesService.fetchGamesIfNeeded { [weak self] success in
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
    
    func refreshGames() {
        AppLogger.log(tag: "LOG-APP: GamesTabViewModel", message: "refreshGames() force refreshing games from API")
        
        isLoading = true
        errorMessage = nil
        
        gamesService.fetchAndStoreGames { [weak self] success in
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