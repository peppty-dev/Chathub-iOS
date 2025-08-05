import SwiftUI
import WebKit
import FirebaseFirestore
import Dispatch

struct GameDisplayView: View {
    let gameUrl: String
    @StateObject private var viewModel: GameDisplayViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(gameUrl: String = "https://example.com/game") {
        self.gameUrl = gameUrl
        self._viewModel = StateObject(wrappedValue: GameDisplayViewModel(gameUrl: gameUrl))
    }
    
    var body: some View {
        ZStack {
            // Game WebView - True Full Screen (under status bar)
            GameWebView(url: gameUrl, isLoading: $viewModel.isLoading)
                .ignoresSafeArea(.all) // True edge to edge including under status bar
            
            // Overlay controls - Back button positioned to account for status bar
            VStack {
                HStack {
                    // Back Button - positioned to be visible over status bar area
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 15)
                    .padding(.top, 60) // Increased padding to account for status bar + safe area
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true) // to allow true full screen gaming
        .onAppear {
            viewModel.startGameSession()
            AppLogger.log(tag: "LOG-APP: GameDisplayView", message: "viewDidLoad() Game display loaded with URL: \(gameUrl)")
        }
        .onDisappear {
            viewModel.endGameSession()
            AppLogger.log(tag: "LOG-APP: GameDisplayView", message: "viewWillDisappear() Game session ended")
        }
    }
}


// MARK: - WebView Component
struct GameWebView: UIViewRepresentable {
    let url: String
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor.black
        
        // Configure WebView for games (Android parity)
        let configuration = webView.configuration
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        
        // Enable JavaScript (Android parity)
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences
        
        // Use the modern way to enable JavaScript
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Enable DOM storage (Android parity)
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Load URL only once during creation to prevent continuous reloading
        if let url = URL(string: url) {
            let request = URLRequest(url: url)
            webView.load(request)
            AppLogger.log(tag: "LOG-APP: GameWebView", message: "makeUIView() Loading game URL: \(url)")
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Don't reload the URL here - this was causing continuous reloading
        // The URL is loaded once in makeUIView() and that's sufficient
        AppLogger.log(tag: "LOG-APP: GameWebView", message: "updateUIView() WebView updated (no reload)")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @objc(GameWebViewCoordinator)
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: GameWebView
        
        init(_ parent: GameWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            AppLogger.log(tag: "LOG-APP: GameWebView", message: "didStartProvisionalNavigation() Game loading started")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            AppLogger.log(tag: "LOG-APP: GameWebView", message: "didFinish() Game loading completed")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            AppLogger.log(tag: "LOG-APP: GameWebView", message: "didFail() Game loading failed: \(error.localizedDescription)")
            
            // Load error page
            let errorHTML = """
                <html>
                <body style="background-color: #000000; color: white; text-align: center; padding-top: 100px;">
                    <h2>Error loading game</h2>
                    <p>Please check your internet connection and try again.</p>
                </body>
                </html>
            """
            webView.loadHTMLString(errorHTML, baseURL: nil)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation (Android parity)
            decisionHandler(.allow)
        }
    }
}

// MARK: - Previews
struct GameDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        GameDisplayView(gameUrl: "https://example.com/test-game")
    }
} 