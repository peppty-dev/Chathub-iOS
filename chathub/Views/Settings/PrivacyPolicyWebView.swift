import SwiftUI
import WebKit

struct PrivacyPolicyWebView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = true
    @State private var loadError: String?
    
    var body: some View {
        NavigationView {
            PrivacyPolicyContentView(isLoading: $isLoading, loadError: $loadError, colorScheme: colorScheme)
                .navigationTitle("Privacy Policy")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("ColorAccent"))
                    }
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            setupNavigationBarAppearance()
        }
    }
    
    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Use theme-aware colors
        if colorScheme == .dark {
            appearance.backgroundColor = UIColor(named: "Background Color") ?? UIColor.systemBackground
            appearance.titleTextAttributes = [.foregroundColor: UIColor(named: "bright") ?? UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(named: "bright") ?? UIColor.label]
        } else {
            appearance.backgroundColor = UIColor(named: "Background Color") ?? UIColor.systemBackground
            appearance.titleTextAttributes = [.foregroundColor: UIColor(named: "dark") ?? UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(named: "dark") ?? UIColor.label]
        }
        
        // Remove shadow for cleaner look
        appearance.shadowColor = .clear
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct PrivacyPolicyContentView: View {
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    let colorScheme: ColorScheme
    
    var body: some View {
        ZStack {
            // Use theme-aware background colors from Assets
            Color("Background Color")
                .ignoresSafeArea(.all)
            
            // ANDROID PARITY: Always create WebView to ensure loading starts properly
            // WebView - Always present but may be hidden during loading
            Group {
                if let privacyURL = URL(string: "https://www.peppty.com/chatappprivacy.php") {
                    WebView(
                        url: privacyURL,
                        colorScheme: colorScheme,
                        isLoading: $isLoading,
                        loadError: $loadError
                    )
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(Color("ErrorRed"))
                        
                        Text("Invalid URL")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color("dark"))
                        
                        Text("Unable to load privacy policy URL")
                            .font(.system(size: 14))
                            .foregroundColor(Color("dark").opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color("Background Color"))
                    .onAppear {
                        AppLogger.log(tag: "LOG-APP: PrivacyPolicyWebView", message: "Invalid privacy policy URL - cannot create URL from string")
                    }
                }
            }
            .opacity(isLoading ? 0 : 1) // Hide during loading, show when loaded
            
            // Overlay loading indicator when needed
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color("ColorAccent"))
                    
                    Text("Loading Privacy Policy...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark").opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("Background Color"))
            }
            
            // Error state overlay
            if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(Color("ErrorRed"))
                    
                    Text("Unable to Load")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color("dark"))
                    
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(Color("dark").opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button("Try Again") {
                        isLoading = true
                        loadError = nil
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color("ColorAccent"))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("Background Color"))
            }
        }
    }
}

struct PrivacyPolicyEmbeddedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = true
    @State private var loadError: String?
    
    var onBack: (() -> Void)?
    
    var body: some View {
        PrivacyPolicyContentView(isLoading: $isLoading, loadError: $loadError, colorScheme: colorScheme)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        onBack?()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("ColorAccent"))
                }
            }
            .onAppear {
                AppLogger.log(tag: "LOG-APP: PrivacyPolicyWebView", message: "PrivacyPolicyEmbeddedView onAppear() - Privacy policy view appeared")
            }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    let colorScheme: ColorScheme
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    
    func makeUIView(context: Context) -> WKWebView {
        AppLogger.log(tag: "LOG-APP: PrivacyPolicyWebView", message: "makeUIView() - Creating WebView for privacy policy")
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Set delegate
        webView.navigationDelegate = context.coordinator
        
        // Configure appearance
        updateWebViewAppearance(webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update appearance when color scheme changes
        updateWebViewAppearance(webView)
        
        // Load URL only if not already loading
        if webView.url != url {
            AppLogger.log(tag: "LOG-APP: PrivacyPolicyWebView", message: "updateUIView() - Loading privacy policy URL: \(url.absoluteString)")
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updateWebViewAppearance(_ webView: WKWebView) {
        // ANDROID PARITY: Let website control its own appearance without app interference
        // Remove all custom styling to preserve website's original design
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = true
        webView.scrollView.backgroundColor = UIColor.systemBackground
        
        // Remove any existing user scripts to prevent CSS injection
        webView.configuration.userContentController.removeAllUserScripts()
    }
    
    @objc(PrivacyPolicyWebViewCoordinator)
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            AppLogger.log(tag: "LOG-APP: PrivacyPolicyWebView", message: "didStartProvisionalNavigation() - Starting to load privacy policy")
            parent.isLoading = true
            parent.loadError = nil
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            AppLogger.log(tag: "LOG-APP: PrivacyPolicyWebView", message: "didFinish() - Privacy policy loaded successfully")
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            AppLogger.log(tag: "LOG-APP: PrivacyPolicyWebView", message: "didFail() - Failed to load privacy policy: \(error.localizedDescription)")
            parent.isLoading = false
            parent.loadError = "Failed to load page: \(error.localizedDescription)"
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            AppLogger.log(tag: "LOG-APP: PrivacyPolicyWebView", message: "didFailProvisionalNavigation() - Network error loading privacy policy: \(error.localizedDescription)")
            parent.isLoading = false
            parent.loadError = "Network error: Please check your internet connection"
        }
    }
}

#Preview("Light Mode") {
    PrivacyPolicyWebView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    PrivacyPolicyWebView()
        .preferredColorScheme(.dark)
} 