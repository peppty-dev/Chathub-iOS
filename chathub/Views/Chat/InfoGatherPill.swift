import SwiftUI

struct InfoGatherPill: View {
    let title: String
    let text: String
    var onYes: () -> Void
    var onNo: () -> Void

    @State private var appear = false
    @State private var isYesButtonPressed = false
    @Environment(\.colorScheme) private var colorScheme

    private var pillBackgroundColor: Color {
        // Use same background as interest pills and status pills
        Color("shade2")
    }
    
    private var pillTextColor: Color {
        // Back to adaptive text colors (white/black) for better contrast
        colorScheme == .dark ? .white : .black
    }
    
    private var pillTitleColor: Color {
        // Back to adaptive title colors with slight transparency
        colorScheme == .dark ? .white.opacity(0.95) : .black.opacity(0.7)
    }
    
    private var adaptiveButtonBackground: Color {
        // Different background color for visual differentiation from main pill
        if colorScheme == .dark {
            return Color("shade3") // Slightly different from shade2
        } else {
            return Color("shade1") // Lighter than shade2 for contrast
        }
    }
    
    private var heartIconColor: Color {
        // White when pressed, otherwise red for heart icon (love/positive)
        isYesButtonPressed ? .white : Color.red
    }
    
    private var xIconColor: Color {
        // Use same color as text for X icon (less prominent)
        pillTextColor
    }
    
    private var yesButtonBackground: Color {
        // Red background when pressed, otherwise use adaptive background
        isYesButtonPressed ? .red : adaptiveButtonBackground
    }
    
    private var yesButtonTextColor: Color {
        // White text when pressed, otherwise use normal text color
        isYesButtonPressed ? .white : pillTextColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(pillTitleColor)
            
            HStack(alignment: .bottom, spacing: 8) {
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(pillTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 2) // Match button baseline alignment
                
                HStack(spacing: 6) {
                    Button(action: {
                        // Trigger press effect
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isYesButtonPressed = true
                        }
                        
                        // Reset after a brief moment and call the action
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isYesButtonPressed = false
                            }
                            onYes()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(heartIconColor)
                            Text("Yes")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(yesButtonTextColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(yesButtonBackground)
                        .clipShape(Capsule())
                    }
                    Button(action: onNo) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(xIconColor)
                            Text("No")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(pillTextColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(adaptiveButtonBackground)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(pillBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .scaleEffect(appear ? 1.0 : 0.95)
        .opacity(appear ? 1.0 : 0.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appear)
        .onAppear { appear = true }
    }
}


