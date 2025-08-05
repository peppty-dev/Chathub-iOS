import SwiftUI

struct MultiplayerGamesView: View {
    @StateObject private var viewModel = MultiplayerGamesViewModel()
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Games Content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.games.isEmpty {
                    emptyStateView
                } else {
                    gamesList
                }
            }
        }
        .navigationTitle("Multiplayer Games")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadMultiplayerGames()
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            Text("Loading multiplayer games...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.shade6)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 50))
                .foregroundColor(AppTheme.shade5)
            Text("No Multiplayer Games Available")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.darkText)
            Text("Check back later for new games")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.shade6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var gamesList: some View {
        List {
            ForEach(viewModel.games, id: \.GameId) { game in
                // Game Row with NavigationLink
                ZStack {
                    MultiplayerGameRow(game: game)
                    
                    NavigationLink(destination: gameProfileView(for: game)) {
                        EmptyView()
                    }
                    .opacity(0)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .background(AppTheme.background)
    }
    
    // MARK: - Helper Methods
    
    private func gameProfileView(for game: Games) -> GameProfileView {
        let gameDetail = createGameDetail(from: game)
        return GameProfileView(game: gameDetail)
    }
    
    private func createGameDetail(from game: Games) -> GameDetail {
        return GameDetail(
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
    }
}

struct MultiplayerGameRow: View {
    let game: Games
    
    var body: some View {
        HStack(spacing: 0) {
            // Game Icon section - matching GamesTabRowView 65dp size exactly
            ZStack {
                AsyncImage(url: URL(string: game.GameIcon.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 65, height: 65)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 65)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.shade2, lineWidth: 2)
                            )
                            .onAppear {
                                AppLogger.log(tag: "LOG-APP: MultiplayerGamesView", message: "Game icon loaded for \(game.GameName)")
                            }
                    case .failure(let error):
                        // Default game placeholder
                        Image("grayImage")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 65)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.shade2, lineWidth: 2)
                            )
                            .onAppear {
                                AppLogger.log(tag: "LOG-APP: MultiplayerGamesView", message: "Game icon failed for \(game.GameName): \(error.localizedDescription)")
                            }
                    @unknown default:
                        Image("grayImage")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 65)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.shade2, lineWidth: 2)
                            )
                    }
                }
            }
            .frame(width: 65, height: 65)
            .padding(.leading, 15)
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            // Content section - game name and info - matching GamesTabRowView layout
            VStack(alignment: .leading, spacing: 8) {
                // Game Name - matching Android 16sp with theme colors
                Text(game.GameName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppTheme.darkText)
                    .lineLimit(1)
                    .padding(.top, 18)
                
                // Star Rating - matching Android RatingBar
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(star <= Int(Double(game.GameRating) ?? 0) ? Color("StarColor") : AppTheme.shade3)
                    }
                }
                .padding(.top, 2)
                
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.trailing, 15)
            
            Spacer()
            
            // Multiplayer badge - positioned on far right like GamesTabRowView
            ZStack {
                Circle()
                    .fill(AppTheme.shade200)
                    .frame(width: 34, height: 34)
                
                Image(systemName: "person.2.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundColor(AppTheme.buttonColor)
            }
        }
        .padding(.trailing, 20)
        .background(AppTheme.background)
        .contentShape(Rectangle())
    }
}


// MARK: - Previews
struct MultiplayerGamesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MultiplayerGamesView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            MultiplayerGamesView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
} 