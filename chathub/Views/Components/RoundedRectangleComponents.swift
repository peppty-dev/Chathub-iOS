import SwiftUI

// MARK: - Rounded Rectangle Button Style
/// A reusable button style that applies a rounded rectangle background with theme-aware colours.
struct RoundedRectangleButtonStyle: ButtonStyle {
    /// Fill colour for the button. Defaults to the global "ButtonColor" asset.
    var fillColor: Color = Color("ButtonColor")
    /// Optional colour when the button is pressed. Defaults to a slightly darker variant of `fillColor`.
    var pressedColor: Color? = nil
    /// Corner radius for the rounded rectangle.
    var cornerRadius: CGFloat = 12
    /// Whether the button should expand to fill available width. Defaults to false for normal sizing.
    var expandWidth: Bool = false
    /// Padding for the button content. Defaults to 16 for backward compatibility.
    var padding: CGFloat = 16
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(padding)
            .frame(maxWidth: expandWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(configuration.isPressed ? (pressedColor ?? fillColor.opacity(0.8)) : fillColor)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview
#if DEBUG
struct RoundedRectangleComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Button("Primary Action") {}
                .buttonStyle(RoundedRectangleButtonStyle())
            Button("Secondary") {}
                .buttonStyle(RoundedRectangleButtonStyle(fillColor: Color("shade5")))
            Button(action: {}) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.white)
                    .padding()
            }
            .buttonStyle(RoundedRectangleButtonStyle())
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif 
