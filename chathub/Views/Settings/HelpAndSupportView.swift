import SwiftUI

// MARK: - HelpAndSupport View
struct HelpAndSupportView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Support text (matching 
                        supportTextView
                        
                        // Email address (matching 
                        emailAddressView
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                .background(Color.primary.colorInvert())
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.primary.colorInvert())
            .onAppear {
                AppLogger.log(tag: "LOG-APP: HelpAndSupportView", message: "viewDidAppear() Help and Support screen displayed")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Support Text View
    private var supportTextView: some View {
        Text("In case of any support or help, please write to us a detailed email regarding the subject. We will get back to you under 24 hours.")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(Color("dark"))
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 5)
    }
    
    // MARK: - Email Address View
    private var emailAddressView: some View {
        VStack(spacing: 10) {
            Text("chatstrangersapps@gmail.com")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color("ButtonColor"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    openEmailClient()
                }
            
            Text("Tap to open email client")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .opacity(0.7)
        }
    }
    
    // MARK: - Helper Functions
    private func openEmailClient() {
        AppLogger.log(tag: "LOG-APP: HelpAndSupportView", message: "openEmailClient() User tapped email address")
        
        let email = "chatstrangersapps@gmail.com"
        let subject = "CHATHUB-SUPPORT: Help Request"
        let body = "Please describe your issue in detail:"
        
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            openURL(url)
        }
    }
    
    private func openURL(_ url: URL) {
        #if os(iOS)
        if let _ = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                AppLogger.log(tag: "LOG-APP: HelpAndSupportView", message: "Email client opened: \(success)")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: HelpAndSupportView", message: "No email client available")
        }
        #endif
    }
}

// MARK: - Preview
#if DEBUG
struct HelpAndSupportView_Previews: PreviewProvider {
    static var previews: some View {
        HelpAndSupportView()
            .preferredColorScheme(.light)
        
        HelpAndSupportView()
            .preferredColorScheme(.dark)
    }
}
#endif 