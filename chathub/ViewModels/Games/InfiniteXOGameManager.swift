import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Game Manager
class InfiniteXOGameManager: ObservableObject {
    @Published var gameState = GameState()
    
    private var gameListener: ListenerRegistration?
    private var chatId: String = ""
    private var currentUserId: String = ""
    private var currentUserName: String = ""
    private var otherUserId: String = ""
    private var otherUserName: String = ""
    
    var onGameOver: ((String?, String?) -> Void)?
    
    func setupGame(chatId: String, currentUserId: String, currentUserName: String, otherUserId: String, otherUserName: String) {
        self.chatId = chatId
        self.currentUserId = currentUserId
        self.currentUserName = currentUserName
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        
        AppLogger.log(tag: "LOG-APP: InfiniteXOGameManager", message: "setupGame() Setting up game room: \(chatId)")
        
        // Start listening to game state
        listenToGameState()
        
        // Initialize game if needed
        initializeGameIfNeeded()
    }
    
    private func listenToGameState() {
        let db = Firestore.firestore()
        
        gameListener = db.collection("Games")
            .document("InfiniteXO")
            .collection("Rooms")
            .document(chatId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: InfiniteXOGameManager", message: "listenToGameState() Error: \(error)")
                    return
                }
                
                if let document = documentSnapshot, document.exists {
                    do {
                        let data = document.data()
                        if let jsonData = try? JSONSerialization.data(withJSONObject: data ?? [:]),
                           let gameState = try? JSONDecoder().decode(GameState.self, from: jsonData) {
                            
                            DispatchQueue.main.async {
                                let previousWinner = self.gameState.winner
                                self.gameState = gameState
                                
                                // Check for game over
                                if let winner = gameState.winner, previousWinner == nil {
                                    let winnerName = winner == "X" ? gameState.playerXName : gameState.playerOName
                                    self.onGameOver?(winner, winnerName)
                                }
                            }
                        }
                    }
                }
            }
    }
    
    private func initializeGameIfNeeded() {
        let db = Firestore.firestore()
        let gameRef = db.collection("Games")
            .document("InfiniteXO")
            .collection("Rooms")
            .document(chatId)
        
        gameRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let document = document, document.exists {
                // Game already exists, just join
                self.joinGame()
            } else {
                // Create new game
                self.createNewGame()
            }
        }
    }
    
    private func createNewGame() {
        AppLogger.log(tag: "LOG-APP: InfiniteXOGameManager", message: "createNewGame() Creating new game")
        
        var newGameState = GameState()
        newGameState.playerX = currentUserId
        newGameState.playerXName = currentUserName
        newGameState.gameStatus = "waiting"
        
        saveGameState(newGameState)
    }
    
    private func joinGame() {
        AppLogger.log(tag: "LOG-APP: InfiniteXOGameManager", message: "joinGame() Joining existing game")
        
        let db = Firestore.firestore()
        let gameRef = db.collection("Games")
            .document("InfiniteXO")
            .collection("Rooms")
            .document(chatId)
        
        gameRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let document = document, document.exists {
                do {
                    let data = document.data()
                    if let jsonData = try? JSONSerialization.data(withJSONObject: data ?? [:]),
                       var gameState = try? JSONDecoder().decode(GameState.self, from: jsonData) {
                        
                        // Join as player O if not already in game
                        if gameState.playerX != self.currentUserId && gameState.playerO.isEmpty {
                            gameState.playerO = self.currentUserId
                            gameState.playerOName = self.currentUserName
                            gameState.gameStatus = "playing"
                            
                            self.saveGameState(gameState)
                        }
                    }
                }
            }
        }
    }
    
    func canMakeMove() -> Bool {
        guard gameState.gameStatus == "playing" else { return false }
        
        let isPlayerX = gameState.playerX == currentUserId
        let isPlayerO = gameState.playerO == currentUserId
        let isMyTurn = (gameState.currentPlayer == "X" && isPlayerX) || 
                      (gameState.currentPlayer == "O" && isPlayerO)
        
        return isMyTurn
    }
    
    func makeMove(at position: GamePosition) {
        guard canMakeMove() else { return }
        
        // Check if position is already occupied
        if gameState.moves.contains(where: { $0.position == position }) {
            return
        }
        
        let move = GameMove(
            position: position,
            player: gameState.currentPlayer,
            playerId: currentUserId,
            playerName: currentUserName,
            timestamp: Date().timeIntervalSince1970
        )
        
        var newGameState = gameState
        newGameState.moves.append(move)
        
        // Check for win
        if let winningLine = checkForWin(moves: newGameState.moves, lastMove: move) {
            newGameState.winner = move.player
            newGameState.winningLine = winningLine
            newGameState.gameStatus = "finished"
        } else {
            // Switch turns
            newGameState.currentPlayer = gameState.currentPlayer == "X" ? "O" : "X"
        }
        
        saveGameState(newGameState)
    }
    
    private func checkForWin(moves: [GameMove], lastMove: GameMove) -> [GamePosition]? {
        let playerMoves = moves.filter { $0.player == lastMove.player }.map { $0.position }
        let position = lastMove.position
        
        // Check all 8 directions for 5 in a row
        let directions = [
            (1, 0),   // Horizontal
            (0, 1),   // Vertical
            (1, 1),   // Diagonal \
            (1, -1)   // Diagonal /
        ]
        
        for (dx, dy) in directions {
            var line = [position]
            
            // Check positive direction
            var x = position.x + dx
            var y = position.y + dy
            while playerMoves.contains(GamePosition(x: x, y: y)) {
                line.append(GamePosition(x: x, y: y))
                x += dx
                y += dy
            }
            
            // Check negative direction
            x = position.x - dx
            y = position.y - dy
            while playerMoves.contains(GamePosition(x: x, y: y)) {
                line.insert(GamePosition(x: x, y: y), at: 0)
                x -= dx
                y -= dy
            }
            
            if line.count >= 5 {
                return line
            }
        }
        
        return nil
    }
    
    func restartGame() {
        AppLogger.log(tag: "LOG-APP: InfiniteXOGameManager", message: "restartGame() Restarting game")
        
        var newGameState = GameState()
        newGameState.playerX = gameState.playerX
        newGameState.playerXName = gameState.playerXName
        newGameState.playerO = gameState.playerO
        newGameState.playerOName = gameState.playerOName
        newGameState.gameStatus = gameState.playerO.isEmpty ? "waiting" : "playing"
        
        saveGameState(newGameState)
    }
    
    private func saveGameState(_ gameState: GameState) {
        let db = Firestore.firestore()
        let gameRef = db.collection("Games")
            .document("InfiniteXO")
            .collection("Rooms")
            .document(chatId)
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(gameState)
            if let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                gameRef.setData(dictionary, merge: true) { error in
                    if let error = error {
                        AppLogger.log(tag: "LOG-APP: InfiniteXOGameManager", message: "saveGameState() Error: \(error)")
                    } else {
                        AppLogger.log(tag: "LOG-APP: InfiniteXOGameManager", message: "saveGameState() Game state saved successfully")
                    }
                }
            }
        } catch {
            AppLogger.log(tag: "LOG-APP: InfiniteXOGameManager", message: "saveGameState() Encoding error: \(error)")
        }
    }
    
    func cleanup() {
        gameListener?.remove()
        gameListener = nil
    }
} 