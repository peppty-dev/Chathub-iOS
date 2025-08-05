import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea(.all) // Ensure complete edge-to-edge coverage
            VStack(spacing: 24) {
                Image("chathub")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                Text("ChatHub")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.tabColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure full screen coverage
    }
}

#Preview {
    LaunchScreenView()
} 