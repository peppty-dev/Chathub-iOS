import SwiftUI

struct GameDetail: Identifiable {
    let id: UUID
    let gameId: String
    let gameUrl: String
    let gameName: String
    let gameDescription: String
    let gameIcon: String
    let gameCover: String
    let gameRating: String
    let gamePlays: Int
    let isMultiplayer: Bool
    let adAvailable: Bool
    
    init(gameId: String = "", gameUrl: String = "", gameName: String, gameDescription: String, gameIcon: String = "", gameCover: String = "", gameRating: String = "4.5", gamePlays: Int = 0, isMultiplayer: Bool = false, adAvailable: Bool = false) {
        self.id = UUID()
        self.gameId = gameId
        self.gameUrl = gameUrl
        self.gameName = gameName
        self.gameDescription = gameDescription
        self.gameIcon = gameIcon
        self.gameCover = gameCover
        self.gameRating = gameRating
        self.gamePlays = gamePlays
        self.isMultiplayer = isMultiplayer
        self.adAvailable = adAvailable
    }
}

struct GameProfileView: View {
    let game: GameDetail
    @State private var isLoading: Bool = false
    @State private var showGameDisplay: Bool = false
    @State private var constructedGameUrl: String = ""
    @Environment(\.dismiss) private var dismiss
    
    private let gamesDB = GamesDB.shared
    private let sessionManager = SessionManager.shared
    
    init(game: GameDetail? = nil) {
        // Default game for preview/testing
        self.game = game ?? GameDetail(
            gameName: "Chess",
            gameDescription: "Classic strategy board game for two players. Plan your moves carefully and try to checkmate your opponent's king.",
            gamePlays: 2,
            isMultiplayer: true
        )
    }
    
    @ViewBuilder
    private func coverImageView() -> some View {
        AsyncImage(url: URL(string: game.gameCover.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .foregroundColor(.white)
                    )
                    .frame(height: 300)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 300)
                    .clipped()
                    .onAppear {
                        AppLogger.log(tag: "LOG-APP: GameProfileView", message: "setupGameProfile() Game cover loaded for \(game.gameName)")
                    }
            case .failure(let error):
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        VStack {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            Text("Game Cover")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    )
                    .frame(height: 300)
                    .onAppear {
                        AppLogger.log(tag: "LOG-APP: GameProfileView", message: "setupGameProfile() Game cover failed for \(game.gameName): \(error.localizedDescription)")
                    }
            @unknown default:
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 300)
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Main game cover image, edge-to-edge
                coverImageView()
                
                // Game name (Android parity)
                Text(game.gameName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Game type and plays (Android parity)
                Text(gameUserDetailsText)
                    .font(.system(size: 12))
                    .foregroundColor(Color("shade5"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Game description (Android parity)
                Text(game.gameDescription)
                    .font(.system(size: 14))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // Play button (Android parity)
                Button(action: {
                    playGame()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                        Text("PLAY GAME")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color("Red1"))
                    .cornerRadius(8)
                }
                .disabled(isLoading)
                .padding(.horizontal, 15)
                .padding(.top, 10)
                .padding(.bottom, 20)
                
                Spacer()
            }
        }
        .background(Color("Background Color"))
        .navigationTitle(game.gameName)
        .navigationBarTitleDisplayMode(.inline)
        .background(
            NavigationLink(
                destination: GameDisplayView(gameUrl: constructedGameUrl),
                isActive: $showGameDisplay
            ) {
                EmptyView()
            }
            .hidden()
        )
        .onAppear {
            setupGameProfile()
            AppLogger.log(tag: "LOG-APP: GameProfileView", message: "viewDidLoad() Game profile displayed for: \(game.gameName)")
        }
    }
    
    private var gameUserDetailsText: String {
        if game.isMultiplayer {
            return "Multiplayer · \(game.gamePlays) plays"
        } else {
            return "Single player · \(game.gamePlays) plays"
        }
    }
    
    private func setupGameProfile() {
        // Setup game profile details similar to Android design() method
        AppLogger.log(tag: "LOG-APP: GameProfileView", message: "setupGameProfile() Setting up profile for game: \(game.gameName)")
    }
    
    private func playGame() {
        isLoading = true
        AppLogger.log(tag: "LOG-APP: GameProfileView", message: "playGame() Starting game: \(game.gameName)")
        
        // Insert recent game record (Android parity - gamesdb.insertrecent)
        insertRecentGameRecord()
        
        // Construct game URL with Android parity logic
        constructGameUrl { [self] gameUrl in
            DispatchQueue.main.async {
                self.constructedGameUrl = gameUrl
                self.isLoading = false
                self.showGameDisplay = true
                
                AppLogger.log(tag: "LOG-APP: GameProfileView", message: "playGame() Game launched successfully with URL: \(gameUrl)")
            }
        }
    }
    
    // MARK: - Android Parity Methods
    
    private func insertRecentGameRecord() {
        // Android parity: Insert game into recent games database
        let currentTime = Date()
        
        // IMPROVED FIX: Ensure game exists in main database before setting played time
        // Check if game exists in main database, if not, insert it first (Android parity)
        let allGames = gamesDB.query()
        let gameExists = allGames.contains { $0.GameId == game.gameId }
        
        AppLogger.log(tag: "LOG-APP: GameProfileView", message: "insertRecentGameRecord() DEBUG - gameExists in main DB: \(gameExists)")
        
        if !gameExists {
            AppLogger.log(tag: "LOG-APP: GameProfileView", message: "insertRecentGameRecord() Game not in main database, inserting: \(game.gameName)")
            
            // Insert game into main database first
            gamesDB.insert(
                GameId: game.gameId as NSString,
                GameUrl: game.gameUrl as NSString,
                GameName: game.gameName as NSString,
                GameDescription: game.gameDescription as NSString,
                GameIcon: game.gameIcon as NSString,
                GameCover: game.gameCover as NSString,
                GameRating: game.gameRating as NSString,
                GamePlays: game.gamePlays,
                Multiplayer: game.isMultiplayer ? 1 : 0
            )
            
            // Wait a moment to ensure insertion is processed before calling setGamePlayedTime
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
                AppLogger.log(tag: "LOG-APP: GameProfileView", message: "insertRecentGameRecord() Calling setGamePlayedTime after insertion delay")
                self.gamesDB.setGamePlayedTime(game_id: self.game.gameId, time: Int64(currentTime.timeIntervalSince1970))
                AppLogger.log(tag: "LOG-APP: GameProfileView", message: "insertRecentGameRecord() Recent game record inserted for: \(self.game.gameName)")
            }
        } else {
            // Game exists, directly call setGamePlayedTime
            AppLogger.log(tag: "LOG-APP: GameProfileView", message: "insertRecentGameRecord() Calling setGamePlayedTime for existing game")
            gamesDB.setGamePlayedTime(game_id: game.gameId, time: Int64(currentTime.timeIntervalSince1970))
            AppLogger.log(tag: "LOG-APP: GameProfileView", message: "insertRecentGameRecord() Recent game record inserted for: \(game.gameName)")
        }
    }
    
    private func constructGameUrl(completion: @escaping (String) -> Void) {
        // Android parity: Construct game URL with game details and Base64 encoding
        guard let userId = sessionManager.userId,
              let userName = sessionManager.userName else {
            AppLogger.log(tag: "LOG-APP: GameProfileView", message: "constructGameUrl() Missing user session data")
            completion(game.gameUrl)
            return
        }
        
        // Create user object (Android parity)
        let user: [String: Any] = [
            "name": userName,
            "photo": "x",
            "sub": userId
        ]
        
        // Create game details object (Android parity)
        let gameDetails: [String: Any] = [
            "gameId": userName,
            "user": user,
            "maxPlayers": "4",
            "minPlayers": "2",
            "maxWait": "60",
            "rounds": "1",
            "cta": "",
            "text": "go_home"
        ]
        
        AppLogger.log(tag: "LOG-APP: GameProfileView", message: "constructGameUrl() Game details: \(gameDetails)")
        
        // Convert to JSON and encode (Android parity)
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: gameDetails)
            let base64Encoded = jsonData.base64EncodedString()
            
            // Construct final URL (Android parity)
            let gameUrl = "https://www.gamezop.com/g/\(game.gameId)?id=3190&sub=\(userId)&gameDetails=\(base64Encoded)"
            
            AppLogger.log(tag: "LOG-APP: GameProfileView", message: "constructGameUrl() Final URL constructed: \(gameUrl)")
            
            completion(gameUrl)
        } catch {
            AppLogger.log(tag: "LOG-APP: GameProfileView", message: "constructGameUrl() JSON encoding error: \(error.localizedDescription)")
            completion(game.gameUrl)
        }
    }
}

struct GameProfileView_Previews: PreviewProvider {
    static var previews: some View {
        GameProfileView()
    }
} 