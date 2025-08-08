import SwiftUI

struct InterestSuggestionPill: View {
    let text: String
    var onAccept: () -> Void
    var onReject: () -> Void

    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Are you interested in")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.95))
            Text(text.interestDisplayFormatted)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Button(action: onAccept) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    Button(action: onReject) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color("liteGradientStart"), Color("liteGradientEnd")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .scaleEffect(appear ? 1.0 : 0.95)
        .opacity(appear ? 1.0 : 0.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appear)
        .onAppear { appear = true }
    }
}

// Inline adaptive layout helper (single-row when fits, otherwise two-row)
// Removed inline adaptive helper to reduce vertical overhead and return to simpler layout

struct InterestSuggestionPill_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            InterestSuggestionPill(text: "digital painting") {
            } onReject: {
            }
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}


