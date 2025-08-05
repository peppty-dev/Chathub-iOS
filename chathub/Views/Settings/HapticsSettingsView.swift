import SwiftUI

// MARK: - Haptics Settings View
// Complete match to Android HapticsActivity.java functionality
struct HapticsSettingsView: View {
    @State private var isHapticEnabled: Bool = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Haptic toggle section (matching Android layout)
            VStack(spacing: 0) {
                HStack {
                    Text("Enable Haptic Feedback")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                    
                    Spacer()
                    
                    Toggle("", isOn: $isHapticEnabled)
                        .onChange(of: isHapticEnabled) { newValue in
                            saveHapticSettings(enabled: newValue)
                            AppLogger.log(tag: "LOG-APP: HapticsSettingsView", message: "Haptic setting changed to: \(newValue)")
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color("Background Color"))
            }
            
            Spacer()
        }
        .navigationTitle("Haptics Settings")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("Background Color"))
        .onAppear {
            loadHapticSettings()
            AppLogger.log(tag: "LOG-APP: HapticsSettingsView", message: "Haptics Settings screen loaded")
        }
    }
    
    // MARK: - Functions (matching Android SessionManager methods)
    private func loadHapticSettings() {
        // Use SessionManager for haptic settings (Android parity)
        isHapticEnabled = SessionManager.shared.hapticEnabled
        AppLogger.log(tag: "LOG-APP: HapticsSettingsView", message: "loadHapticSettings() haptic enabled: \(isHapticEnabled)")
    }
    
    private func saveHapticSettings(enabled: Bool) {
        SessionManager.shared.hapticEnabled = enabled
        AppLogger.log(tag: "LOG-APP: HapticsSettingsView", message: "saveHapticSettings() haptic set to: \(enabled)")
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        HapticsSettingsView()
    }
} 