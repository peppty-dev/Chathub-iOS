import Foundation
import UIKit
import SDWebImage


/// iOS equivalent of Android cache management
/// Provides centralized cache clearing functionality with 100% Android parity
class CacheManager {
    static let shared = CacheManager()
    
    private init() {}
    
    // MARK: - Complete Cache Clearing (Android Parity)
    
    /// Clears all application caches - Android parity: deleteCache() + clearAppData()
    func clearAllCaches() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearAllCaches() Starting comprehensive cache cleanup")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Use background queue for heavy operations
        DispatchQueue.global(qos: .userInitiated).async {
            let group = DispatchGroup()
            
            // Clear URL cache
            group.enter()
            DispatchQueue.main.async {
                URLCache.shared.removeAllCachedResponses()
                AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearAllCaches() URL cache cleared")
                group.leave()
            }
            
            // Clear SDWebImage cache
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                SDImageCache.shared.clearMemory()
                SDImageCache.shared.clearDisk()
                AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearAllCaches() SDWebImage cache cleared")
                group.leave()
            }
            
            // Clear temporary files
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                self.clearTemporaryFiles()
                group.leave()
            }
            
            // Clear Core Data caches
            group.enter()
            DispatchQueue.main.async {
                self.clearUserDefaultsDataCaches()
                group.leave()
            }
            
            // Clear UserDefaults cache keys
            group.enter()
            DispatchQueue.main.async {
                self.clearUserDefaultsCaches()
                group.leave()
            }
            
            group.wait()
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearAllCaches() Comprehensive cache cleanup completed in \(String(format: "%.2f", timeElapsed)) seconds")
        }
    }
    
    /// Clears only image caches - Android parity: Glide.get(context).clearMemory()
    func clearImageCaches() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearImageCaches() Clearing image caches")
        
        DispatchQueue.global(qos: .utility).async {
            // Clear SDWebImage cache (equivalent to Glide cache clearing)
            SDImageCache.shared.clearMemory()
            SDImageCache.shared.clearDisk { 
                AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearImageCaches() SDWebImage disk cache cleared")
            }
            
            // Clear URL cache for images
            DispatchQueue.main.async {
                URLCache.shared.removeAllCachedResponses()
                AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearImageCaches() URL cache cleared")
            }
        }
    }
    
    /// Clears only network caches - Android parity: OkHttp cache clearing
    func clearNetworkCaches() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearNetworkCaches() Clearing network caches")
        
        // Clear URL cache (equivalent to OkHttp cache)
        URLCache.shared.removeAllCachedResponses()
        
        // Clear any Firebase offline cache
        // Note: Firebase Firestore has its own cache management
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearNetworkCaches() Network caches cleared")
    }
    
    /// Clears database caches - Android parity: Room database cache clearing
    func clearDatabaseCaches() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearDatabaseCaches() Clearing database caches")
        
        // Delegate to AsyncClass for comprehensive database cleanup
        DatabaseCleanupService.shared.deleteDatabase()
        
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearDatabaseCaches() Database caches cleared")
    }
    
    /// Clears session caches - Android parity: SessionManager cache clearing
    func clearSessionCaches() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearSessionCaches() Clearing session caches")
        
        let sessionManager = SessionManager.shared
        
        // Clear filters but preserve user session
        sessionManager.clearAllFilters()
        
        // Clear temporary session data
        sessionManager.onlineUsersRefreshTime = 0
        sessionManager.synchronize()
        
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearSessionCaches() Session caches cleared")
    }
    
    /// Clears session caches - Android parity: session cache clearing
    func clearAdCaches() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearAdCaches() Clearing ad caches")
        
        // Session cache clearing (advertising functionality removed)
        
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearAdCaches() Ad caches cleared")
    }
    
    // MARK: - Selective Cache Clearing (Android Parity)
    
    /// Clears caches for account removal - Android parity: complete cleanup for account deletion
    func clearCachesForAccountRemoval() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearCachesForAccountRemoval() Starting account removal cache cleanup")
        
        // Clear all caches
        clearAllCaches()
        
        // Clear session data
        SessionManager.shared.clearUserSession()
        
        // Clear session data (advertising functionality removed)
        
        // Clear database
        DatabaseCleanupService.shared.deleteDatabase()
        
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearCachesForAccountRemoval() Account removal cache cleanup completed")
    }
    
    /// Clears caches for app restart - Android parity: selective cleanup for app restart
    func clearCachesForRestart() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearCachesForRestart() Starting restart cache cleanup")
        
        // Clear temporary caches but preserve user session
        clearImageCaches()
        clearNetworkCaches()
        clearTemporaryFiles()
        
        // Clear database cache but preserve user data
        DatabaseCleanupService.shared.deleteOnlineUsersOnly()
        
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearCachesForRestart() Restart cache cleanup completed")
    }
    
    /// Clears caches for settings reset - Android parity: settings-specific cache clearing
    func clearCachesForSettingsReset() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearCachesForSettingsReset() Starting settings reset cache cleanup")
        
        // Clear filters and preferences
        SessionManager.shared.clearAllFilters()
        
        // Clear app-specific caches
        clearUserDefaultsCaches()
        
        // Clear temporary data
        clearTemporaryFiles()
        
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearCachesForSettingsReset() Settings reset cache cleanup completed")
    }
    
    // MARK: - Private Helper Methods
    
    /// Clears temporary files - Android parity: temp directory cleanup
    private func clearTemporaryFiles() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearTemporaryFiles() Clearing temporary files")
        
        autoreleasepool {
            let tempDir = FileManager.default.temporaryDirectory
            do {
                let tempContents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                var clearedCount = 0
                
                for url in tempContents {
                    do {
                        try FileManager.default.removeItem(at: url)
                        clearedCount += 1
                    } catch {
                        // Continue with other files if one fails
                        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearTemporaryFiles() Failed to remove \(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
                
                AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearTemporaryFiles() Successfully cleared \(clearedCount) temporary files")
            } catch {
                AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearTemporaryFiles() Error accessing temp directory: \(error.localizedDescription)")
            }
        }
    }
    
    /// Clears UserDefaults cache data (replaces CoreData caches)
    private func clearUserDefaultsDataCaches() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearUserDefaultsDataCaches() Clearing UserDefaults cache data")
        
        // Clear cache-related data that was previously in CoreData entities
        UserDefaults.standard.removeObject(forKey: "online_refresh_time")      // Replaces OnlineRefresh
        UserDefaults.standard.removeObject(forKey: "badwords_count")           // Replaces BadwordsCount
        UserDefaults.standard.removeObject(forKey: "notification_new_count")   // Replaces NotificationNew
        
        // Clear profanity words cache (now handled by ProfanityService)
        UserDefaults.standard.removeObject(forKey: "last_profanity_check")
        UserDefaults.standard.removeObject(forKey: "profanity_words_version")
        UserDefaults.standard.removeObject(forKey: "profanityAppNamesVersion")
        
        UserDefaults.standard.synchronize()
        
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearUserDefaultsDataCaches() UserDefaults cache data cleared")
    }
    
    /// Clears UserDefaults cache keys - Android parity: SharedPreferences cache clearing
    private func clearUserDefaultsCaches() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearUserDefaultsCaches() Clearing UserDefaults cache keys")
        
        let defaults = UserDefaults.standard
        
        // Cache-specific keys that can be safely cleared
        let cacheKeys = [
            "onlineUsersRefreshTime",
            "lastImageCacheCleanup",
            "lastNetworkCacheCleanup",
            "tempDataCleanupTime",
            "appCacheVersion"
        ]
        
        for key in cacheKeys {
            defaults.removeObject(forKey: key)
        }
        
        defaults.synchronize()
        
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearUserDefaultsCaches() UserDefaults cache keys cleared")
    }
    
    // MARK: - Cache Size Calculation (Android Parity)
    
    /// Gets total cache size - Android parity: cache size calculation
    func getTotalCacheSize(completion: @escaping (Int64) -> Void) {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "getTotalCacheSize() Calculating total cache size")
        
        DispatchQueue.global(qos: .utility).async {
            var totalSize: Int64 = 0
            
            // URL cache size
            totalSize += Int64(URLCache.shared.currentMemoryUsage)
            totalSize += Int64(URLCache.shared.currentDiskUsage)
            
            // SDWebImage cache size
            SDImageCache.shared.calculateSize { (fileCount, diskSize) in
                totalSize += Int64(diskSize)
                
                // Temporary files size
                let tempSize = self.getTemporaryFilesSize()
                totalSize += tempSize
                
                DispatchQueue.main.async {
                    AppLogger.log(tag: "LOG-APP: CacheManager", message: "getTotalCacheSize() Total cache size: \(totalSize) bytes")
                    completion(totalSize)
                }
            }
        }
    }
    
    /// Gets temporary files size
    private func getTemporaryFilesSize() -> Int64 {
        var totalSize: Int64 = 0
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            let tempContents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.fileSizeKey])
            
            for url in tempContents {
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                    if let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                } catch {
                    // Continue with other files if one fails
                }
            }
        } catch {
            AppLogger.log(tag: "LOG-APP: CacheManager", message: "getTemporaryFilesSize() Error calculating temp files size: \(error.localizedDescription)")
        }
        
        return totalSize
    }
    
    // MARK: - Cache Maintenance (Android Parity)
    
    /// Performs routine cache maintenance - Android parity: scheduled cache cleanup
    func performRoutineMaintenance() {
        AppLogger.log(tag: "LOG-APP: CacheManager", message: "performRoutineMaintenance() Starting routine cache maintenance")
        
        DispatchQueue.global(qos: .background).async {
            // Clear old temporary files (older than 24 hours)
            self.clearOldTemporaryFiles()
            
            // Trim image cache if too large
            self.trimImageCacheIfNeeded()
            
            // Clear corrupted data
            DatabaseCleanupService.shared.clearCorruptedOnlineUsersData()
            
            AppLogger.log(tag: "LOG-APP: CacheManager", message: "performRoutineMaintenance() Routine cache maintenance completed")
        }
    }
    
    /// Clears old temporary files
    private func clearOldTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
        
        do {
            let tempContents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey])
            var removedCount = 0
            
            for url in tempContents {
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
                    if let creationDate = resourceValues.creationDate, creationDate < cutoffDate {
                        try FileManager.default.removeItem(at: url)
                        removedCount += 1
                    }
                } catch {
                    // Continue with other files if one fails
                }
            }
            
            AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearOldTemporaryFiles() Removed \(removedCount) old temporary files")
        } catch {
            AppLogger.log(tag: "LOG-APP: CacheManager", message: "clearOldTemporaryFiles() Error: \(error.localizedDescription)")
        }
    }
    
    /// Trims image cache if needed
    private func trimImageCacheIfNeeded() {
        SDImageCache.shared.calculateSize { (fileCount, diskSize) in
            let maxCacheSize: UInt = 200 * 1024 * 1024 // 200MB
            
            if diskSize > maxCacheSize {
                AppLogger.log(tag: "LOG-APP: CacheManager", message: "trimImageCacheIfNeeded() Cache size (\(diskSize)) exceeds limit (\(maxCacheSize)), trimming")
                
                SDImageCache.shared.clearDisk {
                    AppLogger.log(tag: "LOG-APP: CacheManager", message: "trimImageCacheIfNeeded() Image cache trimmed")
                }
            }
        }
    }
} 