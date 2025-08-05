import SwiftUI

// MARK: - iOS Version Compatibility Modifier
struct ScrollDisabledModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDisabled(true)
        } else {
            content
        }
    }
} 