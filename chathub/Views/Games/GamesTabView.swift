import SwiftUI

struct GamesTabView: View {
    @StateObject private var viewModel = GamesTabViewModel()
    @State private var selectedGame: Games?
    @State private var navigateToGameProfile = false
    @State private var navigateToMultiplayer = false
    @State private var navigateToRecent = false
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    // Loading State
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    // Error State
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(Color("Red1"))
                        Text("Error Loading Games")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.darkText)
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.shade6)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            viewModel.loadGames()
                        }
                        .foregroundColor(AppTheme.buttonColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.gamesList.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.shade5)
                        Text("No Games Available")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.darkText)
                        Text("Check back later for new games!")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.shade6)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Games List - matching OnlineUsersView structure
                    List {
                        // Quick Access Buttons Row - matching OnlineUsersView filter/refresh layout
                        HStack(spacing: 10) {
                            // Recent Games Button - matching Android new_filters_layout style
                            Button(action: {
                                AppLogger.log(tag: "LOG-APP: GamesTabView", message: "recentGamesTapped() recent games button tapped")
                                navigateToRecent = true
                            }) {
                                HStack {
                                    Text("Recent games")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(AppTheme.darkText)
                                        .padding(.leading, 5)
                                    
                                    Spacer()
                                    
                                    ZStack {
                                        Circle()
                                            .fill(Color.yellow)
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.top, 2)
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.yellow.opacity(0.2))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Multiplayer Games Button - matching Android new_refresh_layout style
                            Button(action: {
                                AppLogger.log(tag: "LOG-APP: GamesTabView", message: "multiplayerGamesTapped() multiplayer games button tapped")
                                navigateToMultiplayer = true
                            }) {
                                HStack {
                                    Text("Multiplayer")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(AppTheme.darkText)
                                        .padding(.leading, 5)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "person.2.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color("Red1"))
                                        .font(.system(size: 32, weight: .medium))
                                        .padding(.top, 2)
                                        .padding(.trailing, 2)
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color("red_50"))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(AppTheme.background)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        
                        // Games List - matching OnlineUsersView user rows
                        ForEach(viewModel.gamesList.indices, id: \.self) { index in
                            let game = viewModel.gamesList[index]
                            
                            ZStack {
                                // Game Row with OnlineUserRow-inspired design
                                GamesTabRowView(game: game)
                                
                                NavigationLink(destination: GameProfileView(game: GameDetail(
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
                                ))) {
                                    EmptyView()
                                }
                                .opacity(0)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        viewModel.refreshGames()
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .background(
            VStack {
                // Hidden NavigationLinks for button navigation
                NavigationLink(
                    destination: RecentGamesView(),
                    isActive: $navigateToRecent
                ) {
                    EmptyView()
                }
                .hidden()
                
                NavigationLink(
                    destination: MultiplayerGamesView(),
                    isActive: $navigateToMultiplayer
                ) {
                    EmptyView()
                }
                .hidden()
            }
        )
        .onAppear {
            AppLogger.log(tag: "LOG-APP: GamesTabView", message: "onAppear() setting up games view")
            
            // Debug: Check current status
            let status = GamesService.shared.getDatabaseStatus()
            AppLogger.log(tag: "LOG-APP: GamesTabView", message: "onAppear() current status: \(status)")
            
            // Debug: Test API connectivity
            GamesService.shared.testAPIConnection()
            
            viewModel.loadGames()
        }
    }
}

// MARK: - GamesTabRowView - Android-matching GameRow with 100% parity - AppTheme Compliant
struct GamesTabRowView: View {
    let game: Games
    
    var body: some View {
        HStack(spacing: 0) {
            // Game Icon section - matching Android 65dp size exactly like OnlineUserRow
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
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    case .failure(_):
                        // Default game placeholder
                        Image("grayImage")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 65)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    @unknown default:
                        Image("grayImage")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 65)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .frame(width: 65, height: 65)
            .padding(.leading, 15)
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            // Content section - game name and info - matching OnlineUserRow layout
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
            
            // Play indicator or multiplayer badge - positioned on far right like country flag in OnlineUserRow
            if game.Multiplayer {
                // Multiplayer badge
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
            } else {
                // Single player indicator
                ZStack {
                    Circle()
                        .fill(AppTheme.shade200)
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: "gamecontroller.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(AppTheme.shade6)
                }
            }
        }
        .padding(.trailing, 20)
        .background(AppTheme.background)
        .contentShape(Rectangle())
    }
}


#Preview {
    GamesTabView()
} 