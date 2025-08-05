import SwiftUI

// MARK: - FlippedUpsideDown Modifier for Chat Scrolling
// This modifier flips the view upside down to achieve inverted scrolling like messaging apps
struct FlippedUpsideDown: ViewModifier {
    func body(content: Content) -> some View {
        content
            .rotationEffect(.radians(Double.pi))
            .scaleEffect(x: -1, y: 1, anchor: .center)
    }
}

extension View {
    func flippedUpsideDown() -> some View {
        modifier(FlippedUpsideDown())
    }
} 