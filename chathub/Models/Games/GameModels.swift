import Foundation

// MARK: - Game Models
struct GamePosition: Hashable, Codable {
    let x: Int
    let y: Int
}

struct GameMove: Codable {
    let position: GamePosition
    let player: String // "X" or "O"
    let playerId: String
    let playerName: String
    let timestamp: Double
}

struct GameState: Codable {
    var moves: [GameMove] = []
    var currentPlayer: String = "X"
    var playerX: String = ""
    var playerO: String = ""
    var playerXName: String = ""
    var playerOName: String = ""
    var gameStatus: String = "waiting" // "waiting", "playing", "finished"
    var winner: String? = nil
    var winningLine: [GamePosition]? = nil
    var createdAt: Double = Date().timeIntervalSince1970
} 