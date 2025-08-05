import SwiftUI

// MARK: - View Extensions

extension View {
    /// Conditionally applies a modifier based on a boolean condition
    /// Used for iOS version-specific modifiers like scrollContentBackground
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
} 