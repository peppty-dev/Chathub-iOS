import SwiftUI
import SDWebImageSwiftUI

// MARK: - Make Games conform to Identifiable for recent games list
extension Games: Identifiable {
    var id: String { 
        return GameId.isEmpty ? "game_\(GameName.hashValue)" : GameId
    }
}

struct RecentGamesView: View {
    @StateObject private var gamesViewModel = GamesTabViewModel()
    private let gamesDB = GamesDB.shared

    @State private var recentGames: [Games] = []
    @State private var isLoading: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Games list
            if isLoading {
                ProgressView("Loading recent games...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if recentGames.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Recent Games")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Games you've played recently will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(recentGames) { game in
                    ZStack {
                        RecentGameSimpleRow(game: game)
                        
                        NavigationLink(destination: {
                            // Convert Games to GameDetail (Android parity)
                            let gameDetail = GameDetail(
                                gameId: game.GameId,
                                gameUrl: game.GameUrl,
                                gameName: game.GameName,
                                gameDescription: game.GameDescription,
                                gameIcon: game.GameIcon,
                                gameCover: game.GameCover,
                                gameRating: game.GameRating,
                                gamePlays: game.GamePlays,
                                isMultiplayer: game.Multiplayer,
                                adAvailable: game.Adavailable
                            )
                            return GameProfileView(game: gameDetail)
                        }) {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Recent Games")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("Background Color"))
        .onAppear {
            loadRecentGames()
            AppLogger.log(tag: "LOG-APP: RecentGamesView", message: "viewDidLoad() Recent games screen displayed")
        }
        .refreshable {
            // Pull to refresh functionality
            loadRecentGames()
            AppLogger.log(tag: "LOG-APP: RecentGamesView", message: "refreshable() Recent games refreshed by user")
        }
    }
    
    private func loadRecentGames() {
        AppLogger.log(tag: "LOG-APP: RecentGamesView", message: "loadRecentGames() Loading recent games from database")
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Load recent games from database
            let recentGamesData = self.gamesDB.queryrecent()
            
            DispatchQueue.main.async {
                self.recentGames = recentGamesData
                self.isLoading = false
                
                if recentGamesData.isEmpty {
                    AppLogger.log(tag: "LOG-APP: RecentGamesView", message: "loadRecentGames() No recent games found in database")
                } else {
                    AppLogger.log(tag: "LOG-APP: RecentGamesView", message: "loadRecentGames() Loaded \(recentGamesData.count) recent games")
                }
            }
        }
    }
}

struct RecentGameSimpleRow: View {
    let game: Games
    
    var body: some View {
        HStack(spacing: 0) {
            // Game Icon section
            ZStack {
                WebImage(url: URL(string: game.GameIcon.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                        .frame(width: 65, height: 65)
                }
                .onFailure { error in
                    // Fallback will be handled by the placeholder
                }
                .indicator(.activity)
                .transition(.opacity)
                .frame(width: 65, height: 65)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color("shade2"), lineWidth: 2)
                )
            }
            .frame(width: 65, height: 65)
            .padding(.leading, 15)
            .padding(.vertical, 10)
            
            // Content section
            VStack(alignment: .leading, spacing: 8) {
                Text(game.GameName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("dark"))
                    .lineLimit(1)
                    .padding(.top, 18)
                
                HStack(spacing: 4) {
                    Text("\(game.GamePlays) plays")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color("shade6"))
                    
                    Text("•")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color("shade6"))
                    
                    Text("Recently played")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color("shade6"))
                }
                .padding(.top, 2)

                
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.trailing, 15)
            
            Spacer()
            
            // Multiplayer badge
            if game.Multiplayer {
                ZStack {
                    Circle()
                        .fill(Color("shade2"))
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: "person.2.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(Color("ButtonColor"))
                }
            } else {
                // Single player indicator
                ZStack {
                    Circle()
                        .fill(Color("shade2"))
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: "gamecontroller.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(Color("shade6"))
                }
            }
        }
        .padding(.trailing, 20)
        .background(Color("Background Color"))
        .contentShape(Rectangle())
    }
}

struct RecentGamesView_Previews: PreviewProvider {
    static var previews: some View {
        RecentGamesView()
    }
} 