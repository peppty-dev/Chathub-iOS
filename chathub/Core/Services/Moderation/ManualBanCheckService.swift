import Foundation
import FirebaseFirestore
import FirebaseAuth

/// iOS equivalent of Android ManualBanWorker
/// Handles manual ban checks for device ID, MAC address, and IP address with 100% Android parity
class ManualBanCheckService {
    static let shared = ManualBanCheckService()
    
    private let db = Firestore.firestore()
    private let sessionManager = SessionManager.shared
    
    private var deviceBanListener: ListenerRegistration?
    private var macIdBanListener: ListenerRegistration?
    private var ipBanListener: ListenerRegistration?
    private var banListener: ListenerRegistration?
    
    // MARK: - Continuous Retry Properties (Android Parity)
    private static let TAG = "ManualBanCheckService"
    private static let RETRY_DELAY_SECONDS: TimeInterval = 30.0 // 30 seconds like current implementation
    private var retryTimer: Timer?
    private var retryCount = 0
    private var isRetryingForUserId: String? = nil
    
    private init() {}
    
    /// Starts the ban listener - equivalent to FirebaseServices.getBanListener()
    /// This is the main method that should be called to start listening for user ban updates
    func startBanListener() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startBanListener() starting Firebase ban listener")
        
        guard let userId = sessionManager.userId, !userId.isEmpty else {
            // Android parity: Continuous retry until user is authenticated
            if isRetryingForUserId == nil {
                retryCount += 1
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startBanListener() no user ID available, scheduling CONTINUOUS retry attempt \(retryCount) in \(Self.RETRY_DELAY_SECONDS)s")
                isRetryingForUserId = nil // Mark that we're retrying for null user
                scheduleContinuousRetry()
            } else {
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startBanListener() already retrying for user authentication")
            }
            return
        }
        
        // User authenticated successfully - stop any retry timers and proceed
        stopRetryTimer()
        retryCount = 0
        isRetryingForUserId = userId
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startBanListener() User authenticated, starting listener for userId: \(userId)")
        
        // Remove existing listener if active
        if let existingListener = banListener {
            existingListener.remove()
            banListener = nil
        }
        
        // Set up Firebase listener (matching FirebaseServices.getBanListener exactly)
        banListener = db.collection("Ban")
            .document(userId)
            .collection("Ban")
            .document(userId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                guard let document = documentSnapshot else {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "startBanListener() Error fetching document: \(error?.localizedDescription ?? "unknown")")
                    self.sessionManager.isUserBanned = false
                    BanManager.shared.clearBanData()
                    return
                }

                if !document.exists {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "startBanListener() Document does not exist for user \(userId)")
                    self.sessionManager.isUserBanned = false
                    BanManager.shared.clearBanData()
                    return
                }

                guard let dataDescription = document.data() else {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "startBanListener() Document data was empty for user \(userId)")
                    self.sessionManager.isUserBanned = false
                    BanManager.shared.clearBanData()
                    return
                }

                // Process ban data (matching FirebaseServices exactly)
                let bannedpermanent = dataDescription["banned_permanent"] as? Bool ?? false
                let blockReportCount = dataDescription["Reports"] as? Int ?? 0
                let banEndTimeStamp = dataDescription["Reported_time"] as? Int64 ?? 0

                var isCurrentlyBanned = false

                if bannedpermanent == true {
                    isCurrentlyBanned = true
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "startBanListener() User \(userId) is permanently banned.")
                    BanManager.shared.setBanStatus(
                        banned: true,
                        reason: "permanent",
                        time: String(banEndTimeStamp)
                    )
                    // Show banned user screen
                    self.showBannedUserScreen()

                } else if blockReportCount > 0 && banEndTimeStamp > 0 {
                    if banEndTimeStamp > Int64(Date().timeIntervalSince1970) {
                        isCurrentlyBanned = true
                        AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "startBanListener() User \(userId) is temporarily banned until \(Date(timeIntervalSince1970: TimeInterval(banEndTimeStamp))).")
                        BanManager.shared.setBanStatus(
                            banned: true,
                            reason: "reports:\(blockReportCount)",
                            time: String(banEndTimeStamp)
                        )
                        // Show banned user screen
                        self.showBannedUserScreen()
                    } else {
                        // Temp ban expired
                        isCurrentlyBanned = false
                        AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "startBanListener() User \(userId) temporary ban has expired.")
                        BanManager.shared.clearBanData()
                    }
                } else {
                    // Not banned
                    isCurrentlyBanned = false
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "startBanListener() User \(userId) is not banned.")
                    BanManager.shared.clearBanData()
                }
                
                self.sessionManager.isUserBanned = isCurrentlyBanned
                AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "startBanListener() Setting isUserBanned to \(isCurrentlyBanned) for user \(userId)")
            }
    }
    
    /// Stops the ban listener
    func stopBanListener() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "stopBanListener() stopping Firebase ban listener")
        
        // Stop continuous retry mechanism
        stopRetryTimer()
        retryCount = 0
        isRetryingForUserId = nil
        
        if let listener = banListener {
            listener.remove()
            banListener = nil
        }
    }
    
    // MARK: - Continuous Retry Methods (Android Parity)
    
    /// Schedules continuous retry until user authentication - iOS equivalent of Android Handler.postDelayed loop
    private func scheduleContinuousRetry() {
        stopRetryTimer() // Cancel any existing timer
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: Self.RETRY_DELAY_SECONDS, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "scheduleContinuousRetry() Executing scheduled retry attempt")
            self.startBanListener() // CONTINUOUS RETRY - calls itself again until user is authenticated
        }
    }
    
    /// Stops the retry timer
    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    /// Shows banned user screen
    private func showBannedUserScreen() {
        DispatchQueue.main.async {
            // Navigate to banned user screen - will be implemented when UI is ready
            AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "showBannedUserScreen() User is banned - should show banned screen")
        }
    }
    
    /// Android parity: ManualBanWorker.doWork()
    /// Checks all ban types (device, MAC, IP) from Firebase
    func checkAllBanTypes(completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkAllBanTypes() Starting manual ban checks")
        
        var completedChecks = 0
        let totalChecks = 3
        
        let checkCompletion = {
            completedChecks += 1
            if completedChecks >= totalChecks {
                AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkAllBanTypes() All manual ban checks completed")
                
                // CRITICAL FIX: Check actual ban status from SessionManager (Android parity)
                // Android logic: banned if deviceId is null OR any ban flag is true
                let isDeviceIdBanned = self.sessionManager.getDeviceIdBanned()
                let isMacIdBanned = self.sessionManager.getMacIdBanned()
                let isIpIdBanned = self.sessionManager.getIpIdBanned()
                let hasValidDeviceId = self.sessionManager.deviceId != nil && !(self.sessionManager.deviceId?.isEmpty ?? true)
                
                let isUserBanned = !hasValidDeviceId || isDeviceIdBanned || isMacIdBanned || isIpIdBanned
                
                AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkAllBanTypes() Ban status check - deviceIdBanned: \(isDeviceIdBanned), macIdBanned: \(isMacIdBanned), ipIdBanned: \(isIpIdBanned), hasValidDeviceId: \(hasValidDeviceId)")
                AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkAllBanTypes() Final ban status: \(isUserBanned)")
                
                completion(isUserBanned)
            }
        }
        
        // Check device ID ban (Android parity)
        if let deviceId = sessionManager.deviceId, !deviceId.isEmpty && deviceId != "null" && deviceId != " " {
            checkDeviceIdBanFirebase(completion: checkCompletion)
        } else {
            AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkAllBanTypes() No valid device ID, skipping device ban check")
            checkCompletion()
        }
        
        // Check MAC address ban (Android parity)
        if let macAddress = sessionManager.macAddress, !macAddress.isEmpty && macAddress != "null" && macAddress != " " {
            checkMacIdBanFirebase(completion: checkCompletion)
        } else {
            AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkAllBanTypes() No valid MAC address, skipping MAC ban check")
            checkCompletion()
        }
        
        // Check IP ban (Android parity)
        if let userIp = sessionManager.userRetrievedIp, !userIp.isEmpty && userIp != "null" && userIp != " " {
            checkIpBanFirebase(completion: checkCompletion)
        } else {
            AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkAllBanTypes() No valid IP address, skipping IP ban check")
            checkCompletion()
        }
    }
    
    /// Android parity: ManualBanWorker.checkDeviceIdBanFirebase()
    private func checkDeviceIdBanFirebase(completion: @escaping () -> Void) {
        guard let deviceId = sessionManager.deviceId else {
            completion()
            return
        }
        
        AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkDeviceIdBanFirebase() Checking device ID: \(deviceId)")
        
        // Use one-time check for login validation (not listener)
        db.collection("DeviceBans")
            .document(deviceId)
            .getDocument { documentSnapshot, error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkDeviceIdBanFirebase() Error: \(error.localizedDescription)")
                    self.sessionManager.setDeviceIdBanned(false)
                    completion()
                    return
                }
                
                guard let document = documentSnapshot else {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkDeviceIdBanFirebase() No document found")
                    self.sessionManager.setDeviceIdBanned(false)
                    completion()
                    return
                }
                
                // Check ban status (Android parity: exact same field check)
                if document.exists, let banned = document.get("banned") as? Bool {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkDeviceIdBanFirebase() Device banned status: \(banned)")
                    self.sessionManager.setDeviceIdBanned(banned)
                } else {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkDeviceIdBanFirebase() No banned field found")
                    self.sessionManager.setDeviceIdBanned(false)
                }
                
                completion()
            }
    }
    
    /// Android parity: ManualBanWorker.checkMacIdBanFirebase()
    private func checkMacIdBanFirebase(completion: @escaping () -> Void) {
        guard let macAddress = sessionManager.macAddress else {
            completion()
            return
        }
        
        AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkMacIdBanFirebase() Checking MAC address: \(macAddress)")
        
        // Use one-time check for login validation (not listener)
        db.collection("MacBans")
            .document(macAddress)
            .getDocument { documentSnapshot, error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkMacIdBanFirebase() Error: \(error.localizedDescription)")
                    self.sessionManager.setMacIdBanned(false)
                    completion()
                    return
                }
                
                guard let document = documentSnapshot else {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkMacIdBanFirebase() No document found")
                    self.sessionManager.setMacIdBanned(false)
                    completion()
                    return
                }
                
                // Check ban status (Android parity: exact same field check)
                if document.exists, let banned = document.get("banned") as? Bool {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkMacIdBanFirebase() MAC banned status: \(banned)")
                    self.sessionManager.setMacIdBanned(banned)
                } else {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkMacIdBanFirebase() No banned field found")
                    self.sessionManager.setMacIdBanned(false)
                }
                
                completion()
            }
    }
    
    /// Android parity: ManualBanWorker.checkIpBanFirebase()
    private func checkIpBanFirebase(completion: @escaping () -> Void) {
        guard let userIp = sessionManager.userRetrievedIp else {
            completion()
            return
        }
        
        AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkIpBanFirebase() Checking IP address: \(userIp)")
        
        // Use one-time check for login validation (not listener)
        db.collection("IpBans")
            .document(userIp)
            .getDocument { documentSnapshot, error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkIpBanFirebase() Error: \(error.localizedDescription)")
                    self.sessionManager.setIpIdBanned(false)
                    completion()
                    return
                }
                
                guard let document = documentSnapshot else {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkIpBanFirebase() No document found")
                    self.sessionManager.setIpIdBanned(false)
                    completion()
                    return
                }
                
                // Check ban status (Android parity: exact same field check)
                if document.exists, let banned = document.get("banned") as? Bool {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkIpBanFirebase() IP banned status: \(banned)")
                    self.sessionManager.setIpIdBanned(banned)
                } else {
                    AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "checkIpBanFirebase() No banned field found")
                    self.sessionManager.setIpIdBanned(false)
                }
                
                completion()
            }
    }
    
    /// Clean up all listeners (Android parity: onStopped)
    func stopAllListeners() {
        AppLogger.log(tag: "LOG-APP: ManualBanCheckService", message: "stopAllListeners() Stopping all ban listeners")
        
        if let listener = deviceBanListener {
            listener.remove()
            deviceBanListener = nil
        }
        
        if let listener = macIdBanListener {
            listener.remove()
            macIdBanListener = nil
        }
        
        if let listener = ipBanListener {
            listener.remove()
            ipBanListener = nil
        }
    }
} 