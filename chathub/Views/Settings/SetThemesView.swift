import SwiftUI


// MARK: - SetThemes Manager for Global Theme Control
class SetThemesManager: ObservableObject {
    @Published var currentTheme: ThemeMode = .basedOnPhone
    
    enum ThemeMode: Int16, CaseIterable {
        case white = 0
        case black = 1 
        case basedOnPhone = 2
        case basedOnTime = 3
        
        var title: String {
            switch self {
            case .white: return "Light Mode"
            case .black: return "Dark Mode"
            case .basedOnPhone: return "System Default"
            case .basedOnTime: return "Time-Based"
            }
        }
        
        var description: String {
            switch self {
            case .white: return "Always use light theme"
            case .black: return "Always use dark theme"
            case .basedOnPhone: return "Follow device settings"
            case .basedOnTime: return "Light during day, dark at night"
            }
        }
        
        var iconName: String {
            switch self {
            case .white: return "sun.max.fill"
            case .black: return "moon.fill"
            case .basedOnPhone: return "gear"
            case .basedOnTime: return "clock.fill"
            }
        }
    }
    
    static let shared = SetThemesManager()
    
    private init() {
        loadThemeFromCoreData()
    }
    
    func loadThemeFromCoreData() {
        AppLogger.log(tag: "LOG-APP: SetThemesManager", message: "loadThemeFromCoreData() Loading theme from SessionManager")
        
        let savedThemeValue = UserDefaults.standard.integer(forKey: "themeMode")
        
        if savedThemeValue != 0 {
            currentTheme = ThemeMode(rawValue: Int16(savedThemeValue)) ?? .basedOnPhone
            AppLogger.log(tag: "LOG-APP: SetThemesManager", message: "loadThemeFromCoreData() Loaded theme: \(currentTheme.title)")
        } else {
            currentTheme = .basedOnPhone
            AppLogger.log(tag: "LOG-APP: SetThemesManager", message: "loadThemeFromCoreData() No saved theme, using default: \(currentTheme.title)")
        }
    }
    
    func saveTheme(_ theme: ThemeMode) {
        AppLogger.log(tag: "LOG-APP: SetThemesManager", message: "saveTheme() Saving theme to SessionManager: \(theme.title)")
        
        UserDefaults.standard.set(Int(theme.rawValue), forKey: "themeMode")
        
        // Update published property
        DispatchQueue.main.async {
            self.currentTheme = theme
        }
        
        AppLogger.log(tag: "LOG-APP: SetThemesManager", message: "saveTheme() Theme saved: \(theme.title)")
    }
    
    func applyTheme(_ theme: ThemeMode) {
        guard let window = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive })
                .flatMap({ $0 as? UIWindowScene })?.windows
                .first(where: { $0.isKeyWindow }) else { return }
        
        switch theme {
        case .white:
            window.overrideUserInterfaceStyle = .light
        case .black:
            window.overrideUserInterfaceStyle = .dark
        case .basedOnTime:
            let hour = Calendar.current.component(.hour, from: Date())
            if hour > 6 && hour < 18 {
                window.overrideUserInterfaceStyle = .light
            } else {
                window.overrideUserInterfaceStyle = .dark
            }
        case .basedOnPhone:
            window.overrideUserInterfaceStyle = .unspecified
        }
        
        AppLogger.log(tag: "LOG-APP: SetThemesManager", message: "applyTheme() Applied theme: \(theme.title)")
    }
}

// MARK: - SetThemes ViewModel
class SetThemesViewModel: ObservableObject {
    @Published var selectedTheme: SetThemesManager.ThemeMode = .basedOnPhone
    
    private let themeManager = SetThemesManager.shared
    
    init() {
        loadCurrentTheme()
    }
    
    private func loadCurrentTheme() {
        selectedTheme = themeManager.currentTheme
        AppLogger.log(tag: "LOG-APP: SetThemesViewModel", message: "loadCurrentTheme() Current theme: \(selectedTheme.title)")
    }
    
    func selectTheme(_ theme: SetThemesManager.ThemeMode) {
        // Update selection immediately for visual feedback
        selectedTheme = theme
        
        // Save theme first
        themeManager.saveTheme(theme)
        
        // Apply theme with a delay to prevent navigation disruption
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.themeManager.applyTheme(theme)
        }
        
        AppLogger.log(tag: "LOG-APP: SetThemesViewModel", message: "selectTheme() Selected theme: \(theme.title)")
    }
}

// MARK: - SetThemes View
struct SetThemesView: View {
    @StateObject private var viewModel = SetThemesViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section with description only
                    VStack(spacing: 12) {
                        Text("Personalize your app's appearance to match your style. Your selection will be applied instantly across the entire app.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color("shade7"))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(nil)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                    
                    // Theme Options Section
                    VStack(spacing: 16) {
                        ForEach(SetThemesManager.ThemeMode.allCases, id: \.rawValue) { theme in
                            themeOptionCard(for: theme)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Bottom spacing
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("Background Color"))
        .onAppear {
            AppLogger.log(tag: "LOG-APP: SetThemesView", message: "onAppear() View appeared")
        }
    }
    
    private func themeOptionCard(for theme: SetThemesManager.ThemeMode) -> some View {
        Button(action: {
            viewModel.selectTheme(theme)
        }) {
            HStack(spacing: 16) {
                // Icon with consistent styling
                Image(systemName: theme.iconName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(viewModel.selectedTheme == theme ? .white : Color("dark"))
                    .frame(width: 28, height: 28)
                
                // Text content with proper hierarchy
                VStack(alignment: .leading, spacing: 6) {
                    Text(theme.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(viewModel.selectedTheme == theme ? .white : Color("dark"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(theme.description)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(viewModel.selectedTheme == theme ? Color.white.opacity(0.85) : Color("shade7"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .lineSpacing(1)
                }
                
                // Selection indicator
                if viewModel.selectedTheme == theme {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .stroke(Color("shade5"), lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.selectedTheme == theme ? Color("blue") : Color("Background Color"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                viewModel.selectedTheme == theme ? Color("blue") : Color("shade3"),
                                lineWidth: viewModel.selectedTheme == theme ? 0 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(theme.title). \(theme.description)")
        .accessibilityHint(viewModel.selectedTheme == theme ? "Currently selected" : "Tap to select this theme")
    }
}

// MARK: - UIHostingController Integration
class SetThemesHostingController: UIHostingController<SetThemesView> {
    
    init() {
        super.init(rootView: SetThemesView())
        self.hidesBottomBarWhenPushed = true
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        // CRITICAL FIX: Replace fatalError with safer fallback to prevent binary corruption
        // during App Store validation process
        super.init(coder: aDecoder)
        AppLogger.log(tag: "LOG-APP: SetThemesView", message: "init(coder:) called - this should not happen in normal flow")
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        navigationItem.title = "Themes"
        
        // Set custom font for navigation title
        let customFont = UIFont.systemFont(ofSize: 17, weight: .medium)
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.font: customFont
        ]
    }
}

// MARK: - Preview
#if DEBUG
struct SetThemesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SetThemesView()
        }
        .preferredColorScheme(.light)
        
        NavigationView {
            SetThemesView()
        }
        .preferredColorScheme(.dark)
    }
}
#endif 