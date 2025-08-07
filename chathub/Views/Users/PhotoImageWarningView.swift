import SwiftUI

/**
 * PhotoImageWarningView
 * 
 * A popup dialog that warns users about potentially adult content in images.
 * Requires the user to click "OPEN IMAGE" twice before showing the actual image.
 * 
 * This implementation maintains Android parity for the photo viewing flow.
 */

// MARK: - Photo Image Warning Dialog (Android Parity)
struct PhotoImageWarningView: View {
    let onOpenImage: () -> Void
    let onDismiss: () -> Void
    let clickCount: Int // Passed from parent
    
    @State private var buttonPressed = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Image might contain Adult Content. If you are sure to see the image, click Open Image TWICE.")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color("dark"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    
                    if clickCount > 0 {
                        Text("Click \(2 - clickCount) more time\(2 - clickCount == 1 ? "" : "s")")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("ColorAccent"))
                            .transition(.opacity)
                    }
                }
                
                Button(action: {
                    AppLogger.log(tag: "LOG-APP: PhotoImageWarningView", message: "OPEN IMAGE button tapped - click count: \(clickCount)")
                    buttonPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        buttonPressed = false
                    }
                    onOpenImage()
                }) {
                    Text("OPEN IMAGE")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("ColorAccent"))
                        .cornerRadius(8)
                        .scaleEffect(buttonPressed ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: buttonPressed)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 24)
            }
            .background(Color("Background Color"))
            .cornerRadius(15)
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Preview
struct PhotoImageWarningView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoImageWarningView(
            onOpenImage: { print("Open Image tapped") },
            onDismiss: { print("Dismiss tapped") },
            clickCount: 1
        )
    }
} 