import Foundation

// MARK: - Settings Models

// Data model for each settings row
struct SettingsRow: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String // Asset name in Assets.xcassets/Icons/
    let isDestructive: Bool
    let showsChevron: Bool
    let category: SettingsCategory // Add category for grouping
}

// Settings categories for proper grouping
enum SettingsCategory {
    case navigation    // Items that open new views
    case actions      // Items that perform actions/show popups
    case destructive  // Remove account
} 