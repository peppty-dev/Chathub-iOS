import SwiftUI


struct BannedView: View {
    @State private var banTitle: String = "YOU ARE BANNED FOR 1 HOUR"
    @State private var timeTitle: String = ""
    @State private var block: String = ""
    @State private var time: String = ""
    @State private var permanently: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 50)
                
                // App title
                Text("CHATHUB")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color("dark"))
                    .padding(.horizontal, 20)
                
                // Under maintenance subtitle
                Text("Under Maintenance")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color("dark"))
                    .padding(.horizontal, 20)
                
                // Ban title
                Text(banTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Time label (only show if not permanent)
                if !timeTitle.isEmpty {
                    Text(timeTitle)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }
                
                // Reason for ban
                Text("You maybe banned for reasons listed below")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("1.Sending inappropriate content to strangers.")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color("dark"))
                    
                    Text("2.Sending spam links to strangers")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color("dark"))
                    
                    Text("3.Strangers might have reported you")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color("dark"))
                }
                .padding(.horizontal, 20)
                
                // Warning text
                Text("Please do not send inapproprate content to other users on the app. If you get reported many times you might get banned permanently.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // Contact section
                Text("For any queries contact us:")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color("dark"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                
                Text("chatstrangersapp@gmail.com")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .background(Color("Background Color"))
        .onAppear {
            viewDidLoad()
        }
    }
    
    // MARK: - UIKit Controller Parity Functions
    
    private func viewDidLoad() {
        AppLogger.log(tag: "LOG-APP: BannedView", message: "viewDidLoad() Banned screen displayed")
        
        // Clear all user session data (matching UIKit BannedUserController exactly)
        clearUserSession()
        
        // Load ban details from CoreData and set UI
        loadBanDataFromCoreData()
        
        // Clear user core data
        clearUserCoreData()
    }
    
    private func clearUserSession() {
        AppLogger.log(tag: "LOG-APP: BannedView", message: "clearUserSession() Clearing all user session data")
        
        // Use specialized session managers instead of monolithic SessionManager
        // Note: Individual session managers don't have clear methods, use main SessionManager
        UserSessionManager.shared.clearUserSession()
        
        AppLogger.log(tag: "LOG-APP: BannedView", message: "clearUserSession() User session data cleared")
    }
    
    private func loadBanDataFromCoreData() {
        AppLogger.log(tag: "LOG-APP: BannedView", message: "loadBanDataFromCoreData() Loading ban details from BanManager")
        
        let banManager = BanManager.shared
        
        if banManager.isUserBanned {
            block = banManager.banReason ?? ""
            time = banManager.banTime ?? ""
            permanently = !banManager.isBanExpired() // If not expired, consider it permanent/active
            
            AppLogger.log(tag: "LOG-APP: BannedView", message: "loadBanDataFromCoreData() Loaded: block=\(block), time=\(time), permanently=\(permanently)")
            setData()
        } else {
            AppLogger.log(tag: "LOG-APP: BannedView", message: "loadBanDataFromCoreData() No ban data found in BanManager")
            // Set default temporary ban
            banTitle = "YOU ARE BANNED FOR 1 HOUR"
            timeTitle = ""
        }
    }
    
    private func setData() {
        AppLogger.log(tag: "LOG-APP: BannedView", message: "setData() Setting ban UI data - permanently: \(permanently), time: \(time)")
        
        guard let banTime = Int(time) else {
            AppLogger.log(tag: "LOG-APP: BannedView", message: "setData() Invalid time format: \(time)")
            banTitle = "YOU ARE BANNED"
            timeTitle = ""
            return
        }
        
        let bannerTime = banTime + 3600 // Add 1 hour (3600 seconds)
        let currentTime = Int64(Date().timeIntervalSince1970)
        
        if permanently {
            banTitle = "YOU ARE BANNED PERMANENTLY"
            timeTitle = ""
            AppLogger.log(tag: "LOG-APP: BannedView", message: "setData() Permanent ban set")
        } else if bannerTime < currentTime {
            AppLogger.log(tag: "LOG-APP: BannedView", message: "setData() Ban expired, updating CoreData")
            setLocalData()
            banTitle = "YOU ARE BANNED FOR 1 HOUR"
            timeTitle = "0 Min Remaining"
        } else {
            let diff = (bannerTime - Int(currentTime)) / 60
            banTitle = "YOU ARE BANNED FOR 1 HOUR"
            timeTitle = "\(diff) Min Remaining"
            AppLogger.log(tag: "LOG-APP: BannedView", message: "setData() Temporary ban set with \(diff) minutes remaining")
        }
    }
    
    private func setLocalData() {
        AppLogger.log(tag: "LOG-APP: BannedView", message: "setLocalData() Updating BanManager for expired ban")
        
        let banManager = BanManager.shared
        banManager.clearBanData()
        
        AppLogger.log(tag: "LOG-APP: BannedView", message: "setLocalData() Ban data cleared in BanManager")
    }
    
    private func clearUserCoreData() {
        AppLogger.log(tag: "LOG-APP: BannedView", message: "clearUserCoreData() Clearing user data using centralized CacheManager and SessionManager")
        
        // ANDROID PARITY: Use centralized CacheManager for comprehensive cleanup
        CacheManager.shared.clearCachesForAccountRemoval()
        
        // Clear user profile data from SessionManager (replaces CoreData UserCoreData cleanup)
        UserCoreDataReplacement.clear()
        
        // Delete the SQLite database file (matching UIKit implementation)
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            AppLogger.log(tag: "BannedView", message: "CRITICAL: Cannot access documents directory")
            return
        }
        let documentsPath = documentsURL.path
        let dburl = URL(fileURLWithPath: documentsPath).appendingPathComponent("ChatHub.sqlite")
        do {
            try FileManager.default.removeItem(at: dburl)
            AppLogger.log(tag: "LOG-APP: BannedView", message: "clearUserCoreData() Database file deleted successfully")
        } catch {
            AppLogger.log(tag: "LOG-APP: BannedView", message: "clearUserCoreData() Failed to delete database file: \(error.localizedDescription)")
        }
        
        AppLogger.log(tag: "LOG-APP: BannedView", message: "clearUserCoreData() User data cleared from SessionManager")
    }
}

struct BannedView_Previews: PreviewProvider {
    static var previews: some View {
        BannedView()
    }
} 