import Foundation
import FirebaseFirestore

/// TimeCheckService - iOS equivalent of Android TimeValidationWorker
/// Handles time mismatch detection and warnings with 100% Android parity
class TimeCheckService {
    
    // MARK: - Singleton
    static let shared = TimeCheckService()
    private init() {}
    
    // MARK: - Properties
    private let defaults = UserDefaults.standard
    private let sessionManager = SessionManager.shared
    private var validationTimer: Timer?
    private var isMonitoring = false
    private var retryCount = 0
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    // CRITICAL FIX: Add multiple fallback endpoints for time validation
    private let timeEndpoints = [
        "https://worldtimeapi.org/api/timezone/Etc/UTC",
        "https://timeapi.io/api/Time/current/zone?timeZone=UTC",
        "https://api.timezonedb.com/v2.1/get-time-zone?key=demo&format=json&by=zone&zone=UTC"
    ]
    
    // MARK: - Constants
    private let oneHourInSeconds: TimeInterval = 3600
    
    // MARK: - Public Methods
    
    /// Fetch world time from API and store for validation
    func fetchWorldTimeAndStore(completion: ((Bool) -> Void)? = nil) {
        AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchWorldTimeAndStore() attempting to fetch time from worldtimeapi.org")
        
        // CRITICAL FIX: Try multiple endpoints with SSL configuration
        fetchTimeFromEndpoints(endpointIndex: 0, completion: completion)
    }
    
    /// Check time mismatch and set warning if needed - Android parity
    func checkAndSetTimeMismatchWarningIfNeeded() {
        AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "checkAndSetTimeMismatchWarningIfNeeded() starting")
        
        let currentTime = Date().timeIntervalSince1970
        let cooldownUntil = defaults.double(forKey: AppSettingsKeys.timeMismatchShowWarningCooldownUntilTimestamp)
        
        if currentTime < cooldownUntil {
            AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "checkAndSetTimeMismatchWarningIfNeeded() still in cooldown")
            return
        }
        
        let serverTimeAtLastFetch = defaults.double(forKey: AppSettingsKeys.timeMismatchServerTime)
        let systemUptimeAtLastFetch = defaults.double(forKey: AppSettingsKeys.timeMismatchServerPullSystemTime)
        
        guard serverTimeAtLastFetch > 0 && systemUptimeAtLastFetch > 0 else {
            AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "checkAndSetTimeMismatchWarningIfNeeded() server time not yet fetched, skipping check")
            return
        }
        
        // Calculate estimated current server time
        let currentSystemUptime = ProcessInfo.processInfo.systemUptime
        let uptimeDifference = currentSystemUptime - systemUptimeAtLastFetch
        let estimatedCurrentServerTime = serverTimeAtLastFetch + uptimeDifference
        
        // Compare with current device time
        let currentDeviceTime = Date().timeIntervalSince1970
        let timeDifference = abs(currentDeviceTime - estimatedCurrentServerTime)
        
        AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "checkAndSetTimeMismatchWarningIfNeeded() DeviceTime=\(Date(timeIntervalSince1970: currentDeviceTime)), EstimatedServerTime=\(Date(timeIntervalSince1970: estimatedCurrentServerTime)), Diff=\(timeDifference)s")
        
        if timeDifference > oneHourInSeconds {
            // Time mismatch detected
            sessionManager.showTimeMismatchWarning = true
            defaults.set(currentTime + oneHourInSeconds, forKey: AppSettingsKeys.timeMismatchShowWarningCooldownUntilTimestamp)
            AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "checkAndSetTimeMismatchWarningIfNeeded() time difference > 1 hour, setting warning true")
            updateTimeMismatchStatusInFirestore(isMismatched: true)
        } else {
            // Time is acceptable
            sessionManager.showTimeMismatchWarning = false
            defaults.set(0, forKey: AppSettingsKeys.timeMismatchShowWarningCooldownUntilTimestamp) // Reset cooldown
            AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "checkAndSetTimeMismatchWarningIfNeeded() time difference acceptable, setting warning false")
            // updateTimeMismatchStatusInFirestore(isMismatched: false) // Optional: update if resolved
        }
    }
    
    /// Start time validation monitoring - Android parity
    func startTimeValidationMonitoring() {
        AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "startTimeValidationMonitoring() starting")
        guard !isMonitoring else { return }
        
        isMonitoring = true
        fetchWorldTimeAndStore()
        
        // Schedule periodic time validation
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            self.fetchWorldTimeAndStore()
        }
    }
    
    /// Stop time validation monitoring - Android parity
    func stopTimeValidationMonitoring() {
        AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "stopTimeValidationMonitoring() stopping monitoring")
        isMonitoring = false
        retryCount = 0
    }
    
    /// Reset time mismatch warning state - Android parity
    func resetTimeMismatchWarning() {
        AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "resetTimeMismatchWarning() resetting warning state")
        
        sessionManager.showTimeMismatchWarning = false
        defaults.set(0, forKey: AppSettingsKeys.timeMismatchShowWarningCooldownUntilTimestamp)
        defaults.set(0, forKey: AppSettingsKeys.timeMismatchServerTime)
        defaults.set(0, forKey: AppSettingsKeys.timeMismatchServerPullSystemTime)
    }
    
    /// Get current time mismatch status - Android parity
    func isTimeMismatched() -> Bool {
        return sessionManager.showTimeMismatchWarning
    }
    
    // MARK: - Private Methods
    
    /// Update time mismatch status in Firestore
    private func updateTimeMismatchStatusInFirestore(isMismatched: Bool) {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "updateTimeMismatchStatusInFirestore() no userId found")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        let updateData: [String: Any] = [
            "time_mismatched": isMismatched,
            "time_mismatch_last_checked": Date().timeIntervalSince1970
        ]
        
        AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "updateTimeMismatchStatusInFirestore() updating Firestore with mismatch status: \(isMismatched)")
        
        userRef.updateData(updateData) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "updateTimeMismatchStatusInFirestore() error updating Firestore: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "updateTimeMismatchStatusInFirestore() successfully updated Firestore")
            }
        }
    }
    
    private func fetchTimeFromEndpoints(endpointIndex: Int, completion: ((Bool) -> Void)? = nil) {
        guard endpointIndex < timeEndpoints.count else {
            AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchTimeFromEndpoints() all endpoints failed")
            completion?(false)
            return
        }
        
        guard let url = URL(string: timeEndpoints[endpointIndex]) else {
            AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchTimeFromEndpoints() invalid URL: \(timeEndpoints[endpointIndex])")
            // Try next endpoint
            fetchTimeFromEndpoints(endpointIndex: endpointIndex + 1, completion: completion)
            return
        }
        
        // CRITICAL FIX: Configure URLSession with proper SSL/TLS handling
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15.0
        configuration.timeoutIntervalForResource = 30.0
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        
        // CRITICAL FIX: Add TLS configuration to handle SSL errors
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        
        let session = URLSession(configuration: configuration)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ChatHub/1.11 (iOS)", forHTTPHeaderField: "User-Agent")
        
        AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchTimeFromEndpoints() trying endpoint \(endpointIndex + 1)/\(timeEndpoints.count): \(url.absoluteString)")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchTimeFromEndpoints() endpoint \(endpointIndex + 1) error: \(error.localizedDescription)")
                
                // CRITICAL FIX: Handle specific SSL errors
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .secureConnectionFailed, .serverCertificateUntrusted, .cannotConnectToHost:
                        AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchTimeFromEndpoints() SSL/TLS error detected, trying next endpoint")
                    default:
                        AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchTimeFromEndpoints() network error: \(urlError.localizedDescription)")
                    }
                }
                
                // Try next endpoint
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.fetchTimeFromEndpoints(endpointIndex: endpointIndex + 1, completion: completion)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchTimeFromEndpoints() invalid response type")
                // Try next endpoint
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.fetchTimeFromEndpoints(endpointIndex: endpointIndex + 1, completion: completion)
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchTimeFromEndpoints() HTTP error: \(httpResponse.statusCode)")
                // Try next endpoint
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.fetchTimeFromEndpoints(endpointIndex: endpointIndex + 1, completion: completion)
                }
                return
            }
            
            guard let data = data else {
                AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchTimeFromEndpoints() no data received")
                // Try next endpoint
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.fetchTimeFromEndpoints(endpointIndex: endpointIndex + 1, completion: completion)
                }
                return
            }
            
            // CRITICAL FIX: Parse different endpoint response formats
            if self.parseTimeResponse(data: data, endpointIndex: endpointIndex) {
                AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchTimeFromEndpoints() successfully fetched time from endpoint \(endpointIndex + 1)")
                completion?(true)
            } else {
                AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "fetchTimeFromEndpoints() failed to parse response from endpoint \(endpointIndex + 1)")
                // Try next endpoint
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.fetchTimeFromEndpoints(endpointIndex: endpointIndex + 1, completion: completion)
                }
            }
        }.resume()
    }
    
    private func parseTimeResponse(data: Data, endpointIndex: Int) -> Bool {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "parseTimeResponse() invalid JSON format")
                return false
            }
            
            // CRITICAL FIX: Handle different API response formats
            var unixtime: Int64 = 0
            
            switch endpointIndex {
            case 0: // worldtimeapi.org
                if let unixtimeValue = json["unixtime"] as? Int64 {
                    unixtime = unixtimeValue
                } else if let unixtimeValue = json["unixtime"] as? Int {
                    unixtime = Int64(unixtimeValue)
                }
            case 1: // timeapi.io
                if let timestamp = json["timestamp"] as? String,
                   let timestampValue = Int64(timestamp) {
                    unixtime = timestampValue / 1000 // Convert milliseconds to seconds
                }
            case 2: // timezonedb.com
                if let timestamp = json["timestamp"] as? Int64 {
                    unixtime = timestamp
                } else if let timestamp = json["timestamp"] as? Int {
                    unixtime = Int64(timestamp)
                }
            default:
                break
            }
            
            guard unixtime > 0 else {
                AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "parseTimeResponse() no valid timestamp found")
                return false
            }
            
            // Store the validated time
            let currentTime = Date().timeIntervalSince1970
            let serverTime = TimeInterval(unixtime)
            let timeDifference = abs(currentTime - serverTime)
            
            AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "parseTimeResponse() server time: \(serverTime), local time: \(currentTime), difference: \(timeDifference)s")
            
            // Store server time and system uptime for later validation (Android parity)
            defaults.set(serverTime, forKey: AppSettingsKeys.timeMismatchServerTime)
            defaults.set(ProcessInfo.processInfo.systemUptime, forKey: AppSettingsKeys.timeMismatchServerPullSystemTime)
            
            return true
        } catch {
            AppLogger.log(tag: "LOG-APP: TimeCheckService", message: "parseTimeResponse() JSON parsing error: \(error.localizedDescription)")
            return false
        }
    }
} 