import Foundation

/// BanManager handles ban/block status using UserDefaults storage
/// Replaces Block CoreData entity with Android SessionManager parity
class BanManager {
    static let shared = BanManager()
    
    // Use specialized session managers instead of monolithic SessionManager
    private let userSessionManager = UserSessionManager.shared
    private let moderationSettingsSessionManager = ModerationSettingsSessionManager.shared
    
    private init() {}
    
    // MARK: - Ban Status Management (Android Parity)
    
    /// Get current ban status - replaces Block.blockeduser
    var isUserBanned: Bool {
        get { moderationSettingsSessionManager.isUserBanned }
        set { 
            moderationSettingsSessionManager.isUserBanned = newValue
            AppLogger.log(tag: "LOG-APP: BanManager", message: "isUserBanned set to: \(newValue)")
        }
    }
    
    /// Get ban reason - replaces Block.block
    var banReason: String? {
        get { moderationSettingsSessionManager.banReason }
        set { 
            moderationSettingsSessionManager.banReason = newValue
            AppLogger.log(tag: "LOG-APP: BanManager", message: "banReason set to: \(newValue ?? "nil")")
        }
    }
    
    /// Get ban time - replaces Block.time
    var banTime: String? {
        get { moderationSettingsSessionManager.banTime }
        set { 
            moderationSettingsSessionManager.banTime = newValue
            AppLogger.log(tag: "LOG-APP: BanManager", message: "banTime set to: \(newValue ?? "nil")")
        }
    }
    
    // MARK: - Ban Operations (Android Parity)
    
    /// Set user ban status with reason and time - Android setBanStatus() equivalent
    func setBanStatus(banned: Bool, reason: String? = nil, time: String? = nil) {
        AppLogger.log(tag: "LOG-APP: BanManager", message: "setBanStatus() banned: \(banned), reason: \(reason ?? "nil"), time: \(time ?? "nil")")
        
        isUserBanned = banned
        banReason = reason
        banTime = time
        
        if banned {
            AppLogger.log(tag: "LOG-APP: BanManager", message: "setBanStatus() User banned: \(reason ?? "Unknown reason")")
        } else {
            AppLogger.log(tag: "LOG-APP: BanManager", message: "setBanStatus() User unbanned")
        }
    }
    
    /// Clear all ban data - Android clearBanData() equivalent
    func clearBanData() {
        AppLogger.log(tag: "LOG-APP: BanManager", message: "clearBanData() Clearing all ban data")
        
        isUserBanned = false
        banReason = nil
        banTime = nil
        
        AppLogger.log(tag: "LOG-APP: BanManager", message: "clearBanData() Ban data cleared")
    }
    
    /// Check if ban has expired based on time - Android isBanExpired() equivalent
    func isBanExpired() -> Bool {
        guard let banTimeString = banTime, !banTimeString.isEmpty else {
            AppLogger.log(tag: "LOG-APP: BanManager", message: "isBanExpired() No ban time set")
            return true
        }
        
        // Parse ban time (assuming it's in milliseconds since epoch)
        guard let banTimeMs = Int64(banTimeString) else {
            AppLogger.log(tag: "LOG-APP: BanManager", message: "isBanExpired() Invalid ban time format: \(banTimeString)")
            return true
        }
        
        let currentTimeMs = Int64(Date().timeIntervalSince1970 * 1000)
        let isExpired = currentTimeMs > banTimeMs
        
        AppLogger.log(tag: "LOG-APP: BanManager", message: "isBanExpired() Ban expired: \(isExpired), current: \(currentTimeMs), ban: \(banTimeMs)")
        
        if isExpired {
            // Auto-clear expired ban
            clearBanData()
        }
        
        return isExpired
    }
    
    /// Get ban status for UI display - Android getBanDisplayInfo() equivalent
    func getBanDisplayInfo() -> (title: String, timeTitle: String) {
        guard isUserBanned else {
            return ("", "")
        }
        
        let reason = banReason ?? ""
        let time = banTime ?? ""
        
        var banTitle = "YOU ARE BANNED"
        var timeTitle = ""
        
        if !reason.isEmpty {
            if reason.lowercased().contains("permanent") {
                banTitle = "YOU ARE PERMANENTLY BANNED"
                timeTitle = ""
            } else {
                banTitle = "YOU ARE BANNED FOR \(reason.uppercased())"
                
                if !time.isEmpty {
                    // Convert time to readable format if needed
                    if let banTimeMs = Int64(time) {
                        let banDate = Date(timeIntervalSince1970: TimeInterval(banTimeMs / 1000))
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        timeTitle = "Until: \(formatter.string(from: banDate))"
                    } else {
                        timeTitle = time
                    }
                }
            }
        }
        
        AppLogger.log(tag: "LOG-APP: BanManager", message: "getBanDisplayInfo() title: \(banTitle), timeTitle: \(timeTitle)")
        return (banTitle, timeTitle)
    }
    
    // MARK: - Device Ban Management (Android Parity)
    
    /// Check if device ID is banned - Android isDeviceIdBanned() equivalent
    var isDeviceIdBanned: Bool {
        get { moderationSettingsSessionManager.isDeviceIdBanned }
        set { 
            moderationSettingsSessionManager.isDeviceIdBanned = newValue
            AppLogger.log(tag: "LOG-APP: BanManager", message: "isDeviceIdBanned set to: \(newValue)")
        }
    }
    
    /// Check if MAC ID is banned - Android isMacIdBanned() equivalent
    var isMacIdBanned: Bool {
        get { moderationSettingsSessionManager.isMacIdBanned }
        set { 
            moderationSettingsSessionManager.isMacIdBanned = newValue
            AppLogger.log(tag: "LOG-APP: BanManager", message: "isMacIdBanned set to: \(newValue)")
        }
    }
    
    /// Check if IP is banned - Android isIpIdBanned() equivalent
    var isIpIdBanned: Bool {
        get { moderationSettingsSessionManager.isIpIdBanned }
        set { 
            moderationSettingsSessionManager.isIpIdBanned = newValue
            AppLogger.log(tag: "LOG-APP: BanManager", message: "isIpIdBanned set to: \(newValue)")
        }
    }
    
    /// Check if any device-level ban is active - Android isDeviceBanned() equivalent
    func isDeviceBanned() -> Bool {
        let deviceBanned = isDeviceIdBanned || isMacIdBanned || isIpIdBanned
        AppLogger.log(tag: "LOG-APP: BanManager", message: "isDeviceBanned() result: \(deviceBanned)")
        return deviceBanned
    }
    
    /// Clear all device ban data - Android clearDeviceBanData() equivalent
    func clearDeviceBanData() {
        AppLogger.log(tag: "LOG-APP: BanManager", message: "clearDeviceBanData() Clearing all device ban data")
        
        isDeviceIdBanned = false
        isMacIdBanned = false
        isIpIdBanned = false
        
        AppLogger.log(tag: "LOG-APP: BanManager", message: "clearDeviceBanData() Device ban data cleared")
    }
    
    // MARK: - Additional Ban Check Methods (WarningView compatibility)
    
    /// Check if user is permanently banned - WarningView compatibility
    func isPermanentlyBanned() -> Bool {
        guard isUserBanned else { return false }
        
        let reason = banReason?.lowercased() ?? ""
        let isPermanent = reason.contains("permanent") || reason.contains("forever") || banTime == nil || banTime?.isEmpty == true
        
        AppLogger.log(tag: "LOG-APP: BanManager", message: "isPermanentlyBanned() result: \(isPermanent), reason: \(reason)")
        return isPermanent
    }
    
    /// Check if user is temporarily banned - WarningView compatibility
    func isTemporarilyBanned() -> Bool {
        guard isUserBanned else { return false }
        
        let isPermanent = isPermanentlyBanned()
        let isTemporary = !isPermanent && !isBanExpired()
        
        AppLogger.log(tag: "LOG-APP: BanManager", message: "isTemporarilyBanned() result: \(isTemporary)")
        return isTemporary
    }
    
    /// Get remaining ban time in minutes - WarningView compatibility
    func getRemainingBanTime() -> Int {
        guard let banTimeString = banTime, !banTimeString.isEmpty else {
            AppLogger.log(tag: "LOG-APP: BanManager", message: "getRemainingBanTime() No ban time set, returning 0")
            return 0
        }
        
        guard let banTimeMs = Int64(banTimeString) else {
            AppLogger.log(tag: "LOG-APP: BanManager", message: "getRemainingBanTime() Invalid ban time format: \(banTimeString), returning 0")
            return 0
        }
        
        let currentTimeMs = Int64(Date().timeIntervalSince1970 * 1000)
        let remainingMs = banTimeMs - currentTimeMs
        
        if remainingMs <= 0 {
            AppLogger.log(tag: "LOG-APP: BanManager", message: "getRemainingBanTime() Ban expired, returning 0")
            return 0
        }
        
        let remainingMinutes = Int(remainingMs / (1000 * 60))
        AppLogger.log(tag: "LOG-APP: BanManager", message: "getRemainingBanTime() Remaining minutes: \(remainingMinutes)")
        
        return remainingMinutes
    }
    
    /// Get ban reason - WarningView compatibility
    func getBanReason() -> String {
        let reason = banReason ?? "Unknown reason"
        AppLogger.log(tag: "LOG-APP: BanManager", message: "getBanReason() returning: \(reason)")
        return reason
    }
    
    /// Check if user has any ban record - WarningView compatibility
    func hasBanRecord() -> Bool {
        let hasRecord = isUserBanned || banReason != nil || banTime != nil
        AppLogger.log(tag: "LOG-APP: BanManager", message: "hasBanRecord() result: \(hasRecord)")
        return hasRecord
    }
} 