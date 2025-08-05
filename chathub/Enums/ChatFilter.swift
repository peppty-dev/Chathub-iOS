import Foundation

// MARK: - Chat Filter Enum
enum ChatFilter: String, CaseIterable {
    case all = "all"
    case inbox = "inbox"
    
    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .inbox:
            return "Inbox"
        }
    }
} 