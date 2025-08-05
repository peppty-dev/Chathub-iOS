import Foundation
import SwiftUI

class MultiplayerGamesViewModel: ObservableObject {
    @Published var games: [Games] = []
    @Published var isLoading = true
    
    func loadMultiplayerGames() {
        AppLogger.log(tag: "LOG-APP: MultiplayerGamesViewModel", message: "loadMultiplayerGames() Loading multiplayer games from database")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Load multiplayer games from database
            let multiplayerGames = GamesDB.shared.querymultiplayer()
            
            DispatchQueue.main.async {
                self.games = multiplayerGames
                self.isLoading = false
                AppLogger.log(tag: "LOG-APP: MultiplayerGamesViewModel", message: "loadMultiplayerGames() Loaded \(multiplayerGames.count) multiplayer games")
            }
        }
    }
}