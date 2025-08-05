import Foundation
import UIKit

/// ModerationManagerService - iOS equivalent of Android AppOpenManager moderation logic
/// Handles automatic moderation score checking and restriction enforcement
class ModerationManagerService {
    
    // MARK: - Singleton
    static let shared = ModerationManagerService()
    private init() {}
    
    // MARK: - Properties - Use specialized session managers instead of monolithic SessionManager
    private let userSessionManager = UserSessionManager.shared
    private let moderationSettingsSessionManager = ModerationSettingsSessionManager.shared
    
    // MARK: - Public Methods
    
    /// Checks and applies moderation restrictions - Android AppOpenManager equivalent
    /// Should be called on app launch and periodically
    func checkAndApplyModerationRestrictions() {
        AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkAndApplyModerationRestrictions() starting")
        
        checkTextModerationRestrictions()
        checkImageModerationRestrictions()
    }
    
    // MARK: - Text Moderation Logic (Android Parity)
    
    /// Checks text moderation score and applies restrictions - Android AppOpenManager equivalent
    private func checkTextModerationRestrictions() {
        AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkTextModerationRestrictions() starting")
        
        let currentTime = Int64(Date().timeIntervalSince1970)
        let coolDownTime = moderationSettingsSessionManager.textModerationIssueCoolDownTime
        
        // ANDROID PARITY: Check if cooldown period (1 hour = 3600 seconds) has passed
        if (coolDownTime + 3600) < currentTime {
            let moderationScore = moderationSettingsSessionManager.hiveTextModerationScore
            
            AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkTextModerationRestrictions() cooldown expired, checking score: \(moderationScore)")
            
            // ANDROID PARITY: If score > 100, apply restrictions for 1 hour
            if moderationScore > 100 {
                AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkTextModerationRestrictions() applying text moderation restrictions")
                
                moderationSettingsSessionManager.showTextModerationWarning = true
                moderationSettingsSessionManager.textModerationIssueCoolDownTime = currentTime
                moderationSettingsSessionManager.textModerationIssueSB = true
                moderationSettingsSessionManager.hiveTextModerationScore = 0 // Reset score
                
                AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkTextModerationRestrictions() restrictions applied, score reset")
            } else {
                AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkTextModerationRestrictions() score acceptable, removing restrictions")
                
                moderationSettingsSessionManager.showTextModerationWarning = false
                moderationSettingsSessionManager.textModerationIssueCoolDownTime = 0
                moderationSettingsSessionManager.textModerationIssueSB = false
            }
        } else {
            AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkTextModerationRestrictions() still in cooldown period")
        }
    }
    
    /// Checks image moderation score and applies restrictions - Android AppOpenManager equivalent
    private func checkImageModerationRestrictions() {
        AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkImageModerationRestrictions() starting")
        
        let currentTime = Int64(Date().timeIntervalSince1970)
        let coolDownTime = moderationSettingsSessionManager.imageModerationIssueCoolDownTime
        
        // ANDROID PARITY: Check if cooldown period (1 hour = 3600 seconds) has passed
        if (coolDownTime + 3600) < currentTime {
            let imageModerationScore = moderationSettingsSessionManager.hiveImageModerationScore
            
            AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkImageModerationRestrictions() cooldown expired, checking score: \(imageModerationScore)")
            
            // ANDROID PARITY: If score > 2, apply restrictions for 1 hour
            if imageModerationScore > 2 {
                AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkImageModerationRestrictions() applying image moderation restrictions")
                
                moderationSettingsSessionManager.showImageModerationWarning = true
                moderationSettingsSessionManager.imageModerationIssueCoolDownTime = currentTime
                moderationSettingsSessionManager.imageModerationIssueSB = true
                moderationSettingsSessionManager.hiveImageModerationScore = 0 // Reset score
                
                AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkImageModerationRestrictions() restrictions applied, score reset")
            } else {
                AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkImageModerationRestrictions() score acceptable, removing restrictions")
                
                moderationSettingsSessionManager.showImageModerationWarning = false
                moderationSettingsSessionManager.imageModerationIssueCoolDownTime = 0
                moderationSettingsSessionManager.imageModerationIssueSB = false
            }
        } else {
            AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "checkImageModerationRestrictions() still in cooldown period")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Forces a check of moderation restrictions - can be called manually
    func forceCheckModerationRestrictions() {
        AppLogger.log(tag: "LOG-APP: ModerationManagerService", message: "forceCheckModerationRestrictions() forcing immediate check")
        checkAndApplyModerationRestrictions()
    }
    
    /// Gets current restriction status for debugging
    func getCurrentRestrictionStatus() -> [String: Any] {
        return [
            "textModerationSB": moderationSettingsSessionManager.textModerationIssueSB,
            "imageModerationSB": moderationSettingsSessionManager.imageModerationIssueSB,
            "textModerationScore": moderationSettingsSessionManager.hiveTextModerationScore,
            "imageModerationScore": moderationSettingsSessionManager.hiveImageModerationScore,
            "textCooldownTime": moderationSettingsSessionManager.textModerationIssueCoolDownTime,
            "showTextWarning": moderationSettingsSessionManager.showTextModerationWarning,
            "showImageWarning": moderationSettingsSessionManager.showImageModerationWarning
        ]
    }
} 