import Foundation
import FirebaseFirestore

/// GetReportsService - iOS equivalent of Android GetReportsWorker
/// Provides Firebase report listener functionality with 100% Android parity
class GetReportsService {
    
    // MARK: - Singleton
    static let shared = GetReportsService()
    private init() {}
    
    // MARK: - Properties (Android Parity) - Use specialized managers
    private let userSessionManager = UserSessionManager.shared
    private let database = Firestore.firestore()
    private var getReportsListener: ListenerRegistration?
    private var isListenerActive = false
    
    // MARK: - Public Methods (Android Parity)
    
    /// Starts the reports listener - Android doWork() equivalent
    func startReportsListener() {
        AppLogger.log(tag: "LOG-APP: GetReportsService", message: "startReportsListener() starting Firebase reports listener")
        
        guard let deviceId = userSessionManager.deviceId, !deviceId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: GetReportsService", message: "startReportsListener() no device ID available")
            return
        }
        
        // Remove existing listener if active
        if isListenerActive {
            stopReportsListener()
        }
        
        // Clear Firebase persistence - Android parity
        database.clearPersistence()
        
        // Android equivalent: Firebase snapshot listener setup
        getReportsListener = database.collection("UserDevData")
            .document(deviceId)
            .collection("Reports")
            .document("Reports")
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: GetReportsService", message: "startReportsListener() error: \(error.localizedDescription)")
                    return
                }
                
                if let document = documentSnapshot, document.exists {
                    self.processReportsData(document: document)
                }
            }
        
        isListenerActive = true
        AppLogger.log(tag: "LOG-APP: GetReportsService", message: "startReportsListener() reports listener started successfully")
    }
    
    /// Stops the reports listener - Android onStopped() equivalent
    func stopReportsListener() {
        AppLogger.log(tag: "LOG-APP: GetReportsService", message: "stopReportsListener() stopping Firebase reports listener")
        
        getReportsListener?.remove()
        getReportsListener = nil
        isListenerActive = false
        
        AppLogger.log(tag: "LOG-APP: GetReportsService", message: "stopReportsListener() reports listener stopped")
    }
    
    /// Gets listener status
    func isReportsListenerActive() -> Bool {
        return isListenerActive
    }
    
    /// Forces a refresh of reports data
    func refreshReportsData() {
        AppLogger.log(tag: "LOG-APP: GetReportsService", message: "refreshReportsData() forcing reports data refresh")
        
        guard let deviceId = userSessionManager.deviceId, !deviceId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: GetReportsService", message: "refreshReportsData() no device ID available")
            return
        }
        
        // One-time fetch for immediate data
        database.collection("UserDevData")
            .document(deviceId)
            .collection("Reports")
            .document("Reports")
            .getDocument { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: GetReportsService", message: "refreshReportsData() error: \(error.localizedDescription)")
                    return
                }
                
                if let document = documentSnapshot, document.exists {
                    self.processReportsData(document: document)
                }
            }
    }
    
    // MARK: - Private Methods (Android Parity)
    
    /// Processes reports data - Android processReportsData() equivalent
    private func processReportsData(document: DocumentSnapshot) {
        AppLogger.log(tag: "LOG-APP: GetReportsService", message: "processReportsData() processing reports data")
        
        let data = document.data()
        
        // Process reports count - Android parity
        if let reportsCount = data?["Reports"] as? Int64 {
            AppLogger.log(tag: "LOG-APP: GetReportsService", message: "processReportsData() reports count: \(reportsCount)")
            userSessionManager.setTotalReports(reportsCount)
        }
        
        // Process last report time - Android parity
        if let reportedTime = data?["Reported_time"] as? Int64 {
            AppLogger.log(tag: "LOG-APP: GetReportsService", message: "processReportsData() last report time: \(reportedTime)")
            userSessionManager.setLastReportTime(reportedTime)
        }
        
        AppLogger.log(tag: "LOG-APP: GetReportsService", message: "processReportsData() reports data processed successfully")
    }
}

// MARK: - SessionManager Extension for Reports Data (Android Parity)
extension UserSessionManager {
    
    /// Gets total reports count - Android getTotalReports() equivalent
    var totalReports: Int64 {
        get { Int64(UserDefaults.standard.integer(forKey: "totalReports")) }
        set { 
            UserDefaults.standard.set(Int(newValue), forKey: "totalReports")
            synchronize()
        }
    }
    
    /// Gets last report time - Android getLastReportTime() equivalent
    var lastReportTime: Int64 {
        get { Int64(UserDefaults.standard.integer(forKey: "lastReportTime")) }
        set { 
            UserDefaults.standard.set(Int(newValue), forKey: "lastReportTime")
            synchronize()
        }
    }
    
    /// Sets total reports count - Android setTotalReports() equivalent
    func setTotalReports(_ count: Int64) {
        totalReports = count
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setTotalReports() total reports set to: \(count)")
    }
    
    /// Gets total reports count - Android getTotalReports() equivalent
    func getTotalReports() -> Int64 {
        return totalReports
    }
    
    /// Sets last report time - Android setLastReportTime() equivalent
    func setLastReportTime(_ time: Int64) {
        lastReportTime = time
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setLastReportTime() last report time set to: \(time)")
    }
    
    /// Gets last report time - Android getLastReportTime() equivalent
    func getLastReportTime() -> Int64 {
        return lastReportTime
    }
} 