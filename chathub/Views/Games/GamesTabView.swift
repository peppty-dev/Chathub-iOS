import SwiftUI
import SDWebImageSwiftUI



struct GamesTabView: View {
    @ObservedObject var viewModel: GamesTabViewModel
    @State private var selectedGame: Games?
    @State private var navigateToGameProfile = false
    @State private var navigateToMultiplayer = false
    @State private var navigateToRecent = false
    
    // Use AppStorage for persistent state that survives tab switching
    @AppStorage("gamesTabView_hasInitiallyLoaded") private var hasInitiallyLoaded = false
    
    // Default initializer for backwards compatibility
    init(viewModel: GamesTabViewModel? = nil) {
        self.viewModel = viewModel ?? GamesTabViewModel()
    }
    
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
                        VStack(spacing: 12) {
                            Button("Retry") {
                                viewModel.loadGames()
                            }
                            .foregroundColor(AppTheme.buttonColor)
                            

                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.gamesList.isEmpty {
                    // Empty State with Debug Info
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
            Group {
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
            AppLogger.log(tag: "LOG-APP: GamesTabView", message: "viewDidAppear() - Games tab view appeared")
            AppLogger.log(tag: "LOG-APP: GamesTabView", message: "viewDidAppear() - Current games count: \(viewModel.gamesList.count)")
            AppLogger.log(tag: "LOG-APP: GamesTabView", message: "viewDidAppear() - isLoading: \(viewModel.isLoading)")
            AppLogger.log(tag: "LOG-APP: GamesTabView", message: "viewDidAppear() - hasInitiallyLoaded: \(hasInitiallyLoaded)")
            
            // EFFICIENCY FIX: Only load if we haven't loaded before or have no data
            if !hasInitiallyLoaded || viewModel.gamesList.isEmpty {
                AppLogger.log(tag: "LOG-APP: GamesTabView", message: "viewDidAppear() - First time loading or no data present, checking if data load needed")
                
                // Use proper initial load method that respects data state
                AppLogger.log(tag: "LOG-APP: GamesTabView", message: "viewDidAppear() - Calling initialLoadIfNeeded")
                viewModel.initialLoadIfNeeded()
                
                // Only set the flag to true if we actually have data now
                if !viewModel.gamesList.isEmpty {
                    hasInitiallyLoaded = true
                    AppLogger.log(tag: "LOG-APP: GamesTabView", message: "viewDidAppear() - Data loaded successfully, setting hasInitiallyLoaded to true")
                } else {
                    AppLogger.log(tag: "LOG-APP: GamesTabView", message: "viewDidAppear() - No data loaded yet, will retry on next view appearance")
                }
            } else {
                AppLogger.log(tag: "LOG-APP: GamesTabView", message: "viewDidAppear() - Already loaded before with data (\(viewModel.gamesList.count) games), skipping reload")
            }
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
                        .stroke(AppTheme.shade2, lineWidth: 2)
                )
            }
            .frame(width: 65, height: 65)
            .padding(.leading, 15)
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            // Content section - game name and info - matching OnlineUserRow layout
            VStack(alignment: .leading, spacing: 8) {
                // Game Name - matching Android 16sp with theme colors
                Text(game.GameName)
                    .font(.system(size: 16, weight: .medium))
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