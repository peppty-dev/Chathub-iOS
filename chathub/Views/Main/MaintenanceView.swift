import SwiftUI
import FirebaseFirestore

struct MaintenanceView: View {
    @State private var maintenanceListener: ListenerRegistration?
    
    var body: some View {
        VStack(spacing: 15) {
            Spacer()
                .frame(height: 50)
            
            // App title
            Text("CHATHUB")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color("dark"))
                .frame(height: 40)
                .padding(.horizontal, 20)
            
            // Under maintenance title
            Text("Under Maintenance")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color("dark"))
                .padding(.horizontal, 20)
            
            // Apology message
            Text("We are sorry for your Inconvience.")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 25)
            
            // Maintenance message
            Text("App is under maintenance.")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Estimated time
            Text("Estimated Time : 1 Hour")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(Color("Background Color"))
        .onAppear {
            viewDidLoad()
        }
        .onDisappear {
            viewWillDisappear()
        }
    }
    
    // MARK: - UIKit Controller Parity Functions
    
    private func viewDidLoad() {
        AppLogger.log(tag: "LOG-APP: MaintenanceView", message: "viewDidLoad() Maintenance screen displayed")
        updateAvailable()
    }
    
    private func viewWillDisappear() {
        AppLogger.log(tag: "LOG-APP: MaintenanceView", message: "viewWillDisappear() Removing maintenance listener")
        if let listener = maintenanceListener {
            listener.remove()
            maintenanceListener = nil
        }
    }
    
    private func updateAvailable() {
        AppLogger.log(tag: "LOG-APP: MaintenanceView", message: "updateAvailable() Setting up Firebase maintenance listener")
        
        maintenanceListener = Firestore.firestore()
            .collection("VersionControle")
            .document("LiveAppVersion")
            .addSnapshotListener { (snapshot, error) in
                guard let document = snapshot else {
                    AppLogger.log(tag: "LOG-APP: MaintenanceView", message: "updateAvailable() Error: No document in snapshot")
                    return
                }
                
                guard let data = document.data() else {
                    AppLogger.log(tag: "LOG-APP: MaintenanceView", message: "updateAvailable() Error: No data in document")
                    return
                }
                
                let ios_maintenance = data["ios_maintenance"] as? Bool ?? false
                AppLogger.log(tag: "LOG-APP: MaintenanceView", message: "updateAvailable() Firebase listener - ios_maintenance: \(ios_maintenance)")
                
                if !ios_maintenance {
                    AppLogger.log(tag: "LOG-APP: MaintenanceView", message: "updateAvailable() Maintenance disabled, navigating to MainView")
                    // Navigate to SwiftUI MainView using NavigationManager (consistent with newer architecture)
                    DispatchQueue.main.async {
                        NavigationManager.shared.navigateToMainApp()
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: MaintenanceView", message: "updateAvailable() Maintenance still active, staying on maintenance screen")
                }
                
                AppLogger.log(tag: "LOG-APP: MaintenanceView", message: "updateAvailable() Firebase listener maintenance")
            }
    }
}

struct MaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        MaintenanceView()
    }
} 