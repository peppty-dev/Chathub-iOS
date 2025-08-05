import SwiftUI
import FirebaseFirestore

// MARK: - InfiniteXOGameView
struct InfiniteXOGameView: View {
    let chatId: String
    let currentUserId: String
    let currentUserName: String
    let otherUserId: String
    let otherUserName: String
    
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject private var gameManager = InfiniteXOGameManager()
    @State private var viewportOffset = CGSize.zero
    @State private var lastViewportOffset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showGameOverAlert = false
    @State private var alertMessage = ""
    @State private var showInstructions = true
    
    // Grid constants
    private let cellSize: CGFloat = 40
    private let gridRange = -20...20 // 41x41 grid for infinite feel
    
    var body: some View {
        ZStack {
            Color("Background Color").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Game Board
                gameboardView
                
                // Footer with controls
                footerView
            }
            
            // Instructions overlay
            if showInstructions {
                instructionsOverlay
            }
            
            // Game Over Alert
            if showGameOverAlert {
                gameOverAlert
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            setupGame()
        }
        .onDisappear {
            gameManager.cleanup()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            // Top bar with back button and title
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color("ColorAccent"))
                        .frame(width: 42, height: 42)
                }
                
                Spacer()
                
                Text("Infinite X/O")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("dark"))
                
                Spacer()
                
                Button(action: {
                    showInstructions = true
                }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color("ColorAccent"))
                        .frame(width: 42, height: 42)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(Color("Background Color"))
            
            // Game status bar
            gameStatusBar
        }
        .background(Color("Background Color"))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color("shade3"))
                .opacity(0.3),
            alignment: .bottom
        )
    }
    
    // MARK: - Game Status Bar
    private var gameStatusBar: some View {
        HStack(spacing: 16) {
            // Player X info
            playerInfoView(
                symbol: "X",
                name: gameManager.gameState.playerXName.isEmpty ? "Waiting..." : gameManager.gameState.playerXName,
                isCurrentPlayer: gameManager.gameState.currentPlayer == "X",
                isCurrentUser: gameManager.gameState.playerX == currentUserId
            )
            
            // VS separator
            Text("VS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color("shade6"))
            
            // Player O info
            playerInfoView(
                symbol: "O",
                name: gameManager.gameState.playerOName.isEmpty ? "Waiting..." : gameManager.gameState.playerOName,
                isCurrentPlayer: gameManager.gameState.currentPlayer == "O",
                isCurrentUser: gameManager.gameState.playerO == currentUserId
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("shade1"))
    }
    
    private func playerInfoView(symbol: String, name: String, isCurrentPlayer: Bool, isCurrentUser: Bool) -> some View {
        HStack(spacing: 8) {
            // Symbol
            Text(symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(symbol == "X" ? Color("Red1") : Color("ColorAccent"))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color("Background Color"))
                        .overlay(
                            Circle()
                                .stroke(isCurrentPlayer ? Color("ColorAccent") : Color("shade3"), lineWidth: 2)
                        )
                )
            
            // Player name
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("dark"))
                    .lineLimit(1)
                
                if isCurrentUser {
                    Text("You")
                        .font(.system(size: 12))
                        .foregroundColor(Color("ColorAccent"))
                } else if isCurrentPlayer && gameManager.gameState.gameStatus == "playing" {
                    Text("Turn")
                        .font(.system(size: 12))
                        .foregroundColor(Color("ColorAccent"))
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Game Board View
    private var gameboardView: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color("Background Color")
                
                // Grid lines
                gridLinesView(in: geometry)
                
                // Game pieces
                gamePiecesView(in: geometry)
                
                // Winning line
                if let winningLine = gameManager.gameState.winningLine {
                    winningLineView(winningLine, in: geometry)
                }
            }
            .clipped()
            .scaleEffect(scale)
            .offset(viewportOffset)
            .gesture(
                SimultaneousGesture(
                    // Pan gesture for moving around
                    DragGesture()
                        .onChanged { value in
                            viewportOffset = CGSize(
                                width: lastViewportOffset.width + value.translation.width,
                                height: lastViewportOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastViewportOffset = viewportOffset
                        },
                    
                    // Magnification gesture for zooming
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            // Constrain scale
                            if scale < 0.5 {
                                scale = 0.5
                                lastScale = 0.5
                            } else if scale > 3.0 {
                                scale = 3.0
                                lastScale = 3.0
                            }
                        }
                )
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        handleTap(at: value.location, in: geometry)
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Grid Lines
    private func gridLinesView(in geometry: GeometryProxy) -> some View {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        return ZStack {
            // Vertical lines
            ForEach(gridRange, id: \.self) { x in
                Path { path in
                    let xPos = centerX + CGFloat(x) * cellSize
                    path.move(to: CGPoint(x: xPos, y: 0))
                    path.addLine(to: CGPoint(x: xPos, y: geometry.size.height))
                }
                .stroke(Color("shade3"), lineWidth: x == 0 ? 2 : (x % 5 == 0 ? 1 : 0.5))
                .opacity(x == 0 ? 0.8 : (x % 5 == 0 ? 0.4 : 0.2))
            }
            
            // Horizontal lines
            ForEach(gridRange, id: \.self) { y in
                Path { path in
                    let yPos = centerY + CGFloat(y) * cellSize
                    path.move(to: CGPoint(x: 0, y: yPos))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: yPos))
                }
                .stroke(Color("shade3"), lineWidth: y == 0 ? 2 : (y % 5 == 0 ? 1 : 0.5))
                .opacity(y == 0 ? 0.8 : (y % 5 == 0 ? 0.4 : 0.2))
            }
        }
    }
    
    // MARK: - Game Pieces
    private func gamePiecesView(in geometry: GeometryProxy) -> some View {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        return ZStack {
            ForEach(gameManager.gameState.moves.indices, id: \.self) { index in
                let move = gameManager.gameState.moves[index]
                let xPos = centerX + CGFloat(move.position.x) * cellSize
                let yPos = centerY + CGFloat(move.position.y) * cellSize
                
                Text(move.player)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(move.player == "X" ? Color("Red1") : Color("ColorAccent"))
                    .frame(width: cellSize, height: cellSize)
                    .background(
                        Circle()
                            .fill(Color("Background Color"))
                            .overlay(
                                Circle()
                                    .stroke(move.player == "X" ? Color("Red1") : Color("ColorAccent"), lineWidth: 2)
                            )
                    )
                    .position(x: xPos, y: yPos)
                    .scaleEffect(1.2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: gameManager.gameState.moves.count)
            }
        }
    }
    
    // MARK: - Winning Line
    private func winningLineView(_ line: [GamePosition], in geometry: GeometryProxy) -> some View {
        guard line.count >= 2 else { return AnyView(EmptyView()) }
        
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        guard let startPos = line.first,
              let endPos = line.last else {
            AppLogger.log(tag: "InfiniteXOGameView", message: "CRITICAL: Invalid game line data")
            return AnyView(EmptyView())
        }
        
        let startX = centerX + CGFloat(startPos.x) * cellSize
        let startY = centerY + CGFloat(startPos.y) * cellSize
        let endX = centerX + CGFloat(endPos.x) * cellSize
        let endY = centerY + CGFloat(endPos.y) * cellSize
        
        return AnyView(
            Path { path in
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
            .stroke(Color("AndroidGreen"), lineWidth: 4)
            .opacity(0.8)
        )
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        VStack(spacing: 12) {
            // Game controls
            HStack(spacing: 16) {
                // Reset viewport button
                Button(action: resetViewport) {
                    HStack(spacing: 8) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 16))
                        Text("Center")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color("ColorAccent"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("shade2"))
                    )
                }
                
                Spacer()
                
                // Game status text
                Text(gameStatusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                // Restart game button
                Button(action: restartGame) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                        Text("Restart")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("Red1"))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color("Background Color"))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color("shade3"))
                .opacity(0.3),
            alignment: .top
        )
    }
    
    // MARK: - Instructions Overlay
    private var instructionsOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    showInstructions = false
                }
            
            VStack(spacing: 20) {
                Text("How to Play Infinite X/O")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color("dark"))
                
                VStack(alignment: .leading, spacing: 12) {
                    instructionRow(icon: "target", text: "Get 5 in a row to win (horizontal, vertical, or diagonal)")
                    instructionRow(icon: "hand.draw", text: "Tap any cell to place your symbol")
                    instructionRow(icon: "move.3d", text: "Drag to move around the infinite board")
                    instructionRow(icon: "magnifyingglass", text: "Pinch to zoom in/out")
                    instructionRow(icon: "viewfinder", text: "Use 'Center' button to return to origin")
                }
                
                Button(action: {
                    showInstructions = false
                }) {
                    Text("Got it!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("ColorAccent"))
                        .cornerRadius(8)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("Background Color"))
            )
            .padding(.horizontal, 32)
        }
    }
    
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color("ColorAccent"))
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
    
    // MARK: - Game Over Alert
    private var gameOverAlert: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text(alertMessage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    Button(action: {
                        showGameOverAlert = false
                    }) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("ColorAccent"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("ColorAccent"), lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        showGameOverAlert = false
                        restartGame()
                    }) {
                        Text("Play Again")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color("ColorAccent"))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("Background Color"))
            )
            .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Computed Properties
    private var gameStatusText: String {
        switch gameManager.gameState.gameStatus {
        case "waiting":
            return "Waiting for other player..."
        case "playing":
            let currentPlayerName = gameManager.gameState.currentPlayer == "X" ? 
                gameManager.gameState.playerXName : gameManager.gameState.playerOName
            let isMyTurn = (gameManager.gameState.currentPlayer == "X" && gameManager.gameState.playerX == currentUserId) ||
                          (gameManager.gameState.currentPlayer == "O" && gameManager.gameState.playerO == currentUserId)
            return isMyTurn ? "Your turn" : "\(currentPlayerName)'s turn"
        case "finished":
            if let _ = gameManager.gameState.winner {
                let winnerName = gameManager.gameState.winner == "X" ? gameManager.gameState.playerXName : gameManager.gameState.playerOName
                return "\(winnerName) wins!"
            } else {
                return "Game ended"
            }
        default:
            return ""
        }
    }
    
    // MARK: - Helper Methods
    private func setupGame() {
        AppLogger.log(tag: "LOG-APP: InfiniteXOGameView", message: "setupGame() Setting up game for chatId: \(chatId)")
        gameManager.setupGame(
            chatId: chatId,
            currentUserId: currentUserId,
            currentUserName: currentUserName,
            otherUserId: otherUserId,
            otherUserName: otherUserName
        )
        
        // Listen for game over events
        gameManager.onGameOver = { winner, winnerName in
            DispatchQueue.main.async {
                if let _ = winner, let winnerName = winnerName {
                    alertMessage = "\(winnerName) wins with 5 in a row!"
                } else {
                    alertMessage = "Game ended"
                }
                showGameOverAlert = true
            }
        }
    }
    
    private func handleTap(at location: CGPoint, in geometry: GeometryProxy) {
        guard gameManager.canMakeMove() else { return }
        
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        // Convert tap location to grid coordinates
        let adjustedX = (location.x - centerX - viewportOffset.width) / scale
        let adjustedY = (location.y - centerY - viewportOffset.height) / scale
        
        let gridX = Int(round(adjustedX / cellSize))
        let gridY = Int(round(adjustedY / cellSize))
        
        let position = GamePosition(x: gridX, y: gridY)
        gameManager.makeMove(at: position)
    }
    
    private func resetViewport() {
        withAnimation(.easeInOut(duration: 0.5)) {
            viewportOffset = .zero
            lastViewportOffset = .zero
            scale = 1.0
            lastScale = 1.0
        }
    }
    
    private func restartGame() {
        gameManager.restartGame()
        resetViewport()
    }
}

// MARK: - Preview
struct InfiniteXOGameView_Previews: PreviewProvider {
    static var previews: some View {
        InfiniteXOGameView(
            chatId: "preview_chat",
            currentUserId: "user1",
            currentUserName: "Player 1",
            otherUserId: "user2",
            otherUserName: "Player 2"
        )
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")
        
        InfiniteXOGameView(
            chatId: "preview_chat",
            currentUserId: "user1",
            currentUserName: "Player 1",
            otherUserId: "user2",
            otherUserName: "Player 2"
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}