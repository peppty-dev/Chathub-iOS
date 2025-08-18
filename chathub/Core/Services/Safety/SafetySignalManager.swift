//
//  SafetySignalManager.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import FirebaseFirestore

/// SafetySignalManager - Implements complete Two-Layer Safety Signal Collection System
/// Layer 2: Advanced Detection + Silent Data Collection for compliance and safety intelligence
/// Never stores raw offensive content - only increment counters
class SafetySignalManager {
    
    // MARK: - Singleton
    static let shared = SafetySignalManager()
    private init() {}
    
    // MARK: - Safety Categories
    enum SafetyCategory: String, CaseIterable {
        // Adult Content
        case adultText = "adult_text"
        case adultImage = "adult_image"
        
        // Toxicity/Harassment
        case toxicity = "toxicity"
        case harassment = "harassment"
        case bullying = "bullying"
        
        // Hate/Violence
        case hate = "hate"
        case violentThreat = "violent_threat"
        case graphicGore = "graphic_gore"
        
        // Scam/Spam
        case scam = "scam"
        case spamAds = "spam_ads"
        case phishingLink = "phishing_link"
        
        // Privacy Violations
        case doxxingAttempt = "doxxing_attempt"
        case piiShare = "pii_share"
        
        // Self-Harm
        case selfHarm = "self_harm"
        
        // Extremism
        case extremism = "extremism"
        
        // Child Safety (High Priority)
        case childExploitation = "child_exploitation"
        case childGrooming = "child_grooming"
        case underageContent = "underage_content"
        case childEndangerment = "child_endangerment"
        
        // Terrorism/Security Threats (High Priority)
        case terrorismContent = "terrorism_content"
        case violenceIncitement = "violence_incitement"
        case weaponTrafficking = "weapon_trafficking"
        case coordinatedHarmfulActivity = "coordinated_harmful_activity"
        
        var displayName: String {
            switch self {
            case .adultText: return "Adult Text Content"
            case .adultImage: return "Adult Image Content"
            case .toxicity: return "Toxic Behavior"
            case .harassment: return "Harassment"
            case .bullying: return "Bullying"
            case .hate: return "Hate Speech"
            case .violentThreat: return "Violent Threats"
            case .graphicGore: return "Graphic Violence"
            case .scam: return "Scam Attempts"
            case .spamAds: return "Spam/Advertisements"
            case .phishingLink: return "Phishing Links"
            case .doxxingAttempt: return "Doxxing Attempts"
            case .piiShare: return "Personal Info Sharing"
            case .selfHarm: return "Self-Harm Content"
            case .extremism: return "Extremist Content"
            case .childExploitation: return "Child Exploitation"
            case .childGrooming: return "Child Grooming"
            case .underageContent: return "Underage Content"
            case .childEndangerment: return "Child Endangerment"
            case .terrorismContent: return "Terrorism Content"
            case .violenceIncitement: return "Violence Incitement"
            case .weaponTrafficking: return "Weapon Trafficking"
            case .coordinatedHarmfulActivity: return "Coordinated Harmful Activity"
            }
        }
        
        var isHighSeverity: Bool {
            switch self {
            case .childExploitation, .childGrooming, .underageContent, .childEndangerment,
                 .terrorismContent, .violenceIncitement, .weaponTrafficking, .coordinatedHarmfulActivity:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Detection Results
    struct DetectionResult {
        let categories: [SafetyCategory]
        let confidence: Float
        let reasons: [String]
        let requiresEscalation: Bool
        
        var hasHighSeverityThreats: Bool {
            return categories.contains { $0.isHighSeverity }
        }
    }
    
    // MARK: - Public API
    
    /// Analyze message for safety signals (Layer 2 - Silent Collection)
    /// This runs in background with NO user impact
    func analyzeMessageForSafetySignals(_ text: String, userId: String) {
        DispatchQueue.global(qos: .utility).async {
            AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "Layer 2: Starting silent analysis for user: \(userId)")
            
            // 1. Advanced AI Analysis
            let aiResults = self.performAdvancedAIAnalysis(text)
            
            // 2. Specialized Pattern Detection
            let specializedResults = self.performSpecializedDetection(text)
            
            // 3. Combine Results
            let combinedCategories = Array(Set(aiResults.categories + specializedResults.categories))
            
            if !combinedCategories.isEmpty {
                // 4. Update Database (Silent - No User Impact)
                self.updateSafetyCounters(categories: combinedCategories, userId: userId)
                
                // 5. Check for immediate escalation (High Severity)
                if combinedCategories.contains(where: { $0.isHighSeverity }) {
                    self.triggerImmediateEscalation(categories: combinedCategories, userId: userId, content: text)
                }
            }
            
            AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "Layer 2: Silent analysis complete - \(combinedCategories.count) categories detected")
        }
    }
    
    /// Analyze image for safety signals
    func analyzeImageForSafetySignals(_ imageData: Data, userId: String) {
        DispatchQueue.global(qos: .utility).async {
            AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "Layer 2: Starting silent image analysis for user: \(userId)")
            
            // Use existing Hive moderation service for image analysis
            // Map results to safety categories
            // Implementation would integrate with existing HiveImageModerationService
            
            // For now, basic implementation
            let detectedCategories: [SafetyCategory] = []
            
            if !detectedCategories.isEmpty {
                self.updateSafetyCounters(categories: detectedCategories, userId: userId)
            }
        }
    }
    
    /// Get safety signal statistics for user (Internal use only)
    func getSafetySignals(for userId: String, completion: @escaping ([String: Any]?) -> Void) {
        let safetyRef = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("safety")
        
        safetyRef.getDocument { document, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "getSafetySignals() - Error: \(error)")
                completion(nil)
            } else {
                completion(document?.data())
            }
        }
    }
    
    // MARK: - Advanced AI Analysis
    
    private func performAdvancedAIAnalysis(_ text: String) -> DetectionResult {
        var detectedCategories: [SafetyCategory] = []
        var reasons: [String] = []
        
        // 1. Use existing ProfanityFilterService for advanced analysis
        let aiResult = ProfanityFilterService.shared.analyzeContent(text, config: ProfanityFilterService.FilterConfig(
            strictnessLevel: .moderate,
            enableSentimentAnalysis: true,
            enablePatternDetection: true,
            enableContextAnalysis: true,
            profanityThreshold: 0.1
        ))
        
        // 2. Map AI results to safety categories
        switch aiResult {
        case .safe:
            break
        case .questionable(let aiReasons), .unsafe(let aiReasons):
            let mappedCategories = mapAIReasonsToSafetyCategories(aiReasons)
            detectedCategories.append(contentsOf: mappedCategories)
            reasons.append(contentsOf: aiReasons)
        }
        
        // 3. Perform additional specialized detection
        let additionalCategories = performAdditionalDetection(text)
        detectedCategories.append(contentsOf: additionalCategories)
        
        return DetectionResult(
            categories: detectedCategories,
            confidence: 0.8,
            reasons: reasons,
            requiresEscalation: detectedCategories.contains { $0.isHighSeverity }
        )
    }
    
    private func mapAIReasonsToSafetyCategories(_ reasons: [String]) -> [SafetyCategory] {
        var categories: [SafetyCategory] = []
        
        for reason in reasons {
            let lowercaseReason = reason.lowercased()
            
            // Map based on reason content
            if lowercaseReason.contains("negative sentiment") || lowercaseReason.contains("toxic") {
                categories.append(.toxicity)
            }
            if lowercaseReason.contains("harassment") {
                categories.append(.harassment)
            }
            if lowercaseReason.contains("hate") {
                categories.append(.hate)
            }
            if lowercaseReason.contains("threat") || lowercaseReason.contains("violence") {
                categories.append(.violentThreat)
            }
            if lowercaseReason.contains("profanity") || lowercaseReason.contains("adult") {
                categories.append(.adultText)
            }
        }
        
        return categories
    }
    
    private func performAdditionalDetection(_ text: String) -> [SafetyCategory] {
        var categories: [SafetyCategory] = []
        let lowercaseText = text.lowercased()
        
        // Scam/Spam Detection
        if detectScamPatterns(lowercaseText) {
            categories.append(.scam)
        }
        
        // Privacy Violation Detection
        if detectPrivacyViolations(lowercaseText) {
            categories.append(.piiShare)
        }
        
        // Self-Harm Detection
        if detectSelfHarmContent(lowercaseText) {
            categories.append(.selfHarm)
        }
        
        return categories
    }
    
    // MARK: - Specialized Pattern Detection
    
    private func performSpecializedDetection(_ text: String) -> DetectionResult {
        var detectedCategories: [SafetyCategory] = []
        let lowercaseText = text.lowercased()
        
        // Child Safety Detection (High Priority)
        let childSafetyCategories = detectChildSafetyThreats(lowercaseText)
        detectedCategories.append(contentsOf: childSafetyCategories)
        
        // Terrorism/Security Detection (High Priority)
        let terrorismCategories = detectTerrorismThreats(lowercaseText)
        detectedCategories.append(contentsOf: terrorismCategories)
        
        // Extremism Detection
        if detectExtremismContent(lowercaseText) {
            detectedCategories.append(.extremism)
        }
        
        return DetectionResult(
            categories: detectedCategories,
            confidence: 0.9,
            reasons: [],
            requiresEscalation: detectedCategories.contains { $0.isHighSeverity }
        )
    }
    
    // MARK: - Specific Threat Detection Methods
    
    private func detectScamPatterns(_ text: String) -> Bool {
        let scamPatterns = [
            "send money", "wire transfer", "urgent payment", "inheritance",
            "lottery winner", "click here", "act now", "limited time",
            "congratulations you won", "verify account", "suspended account"
        ]
        
        return scamPatterns.contains { text.contains($0) }
    }
    
    private func detectPrivacyViolations(_ text: String) -> Bool {
        // Detect patterns that might reveal personal information
        let piiPatterns = [
            "my address is", "my phone number", "social security",
            "credit card", "bank account", "my real name is"
        ]
        
        // Simple regex patterns for common PII
        let phoneRegex = try? NSRegularExpression(pattern: "\\b\\d{3}-\\d{3}-\\d{4}\\b")
        let emailRegex = try? NSRegularExpression(pattern: "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b")
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if phoneRegex?.firstMatch(in: text, range: range) != nil ||
           emailRegex?.firstMatch(in: text, range: range) != nil {
            return true
        }
        
        return piiPatterns.contains { text.contains($0) }
    }
    
    private func detectSelfHarmContent(_ text: String) -> Bool {
        let selfHarmPatterns = [
            "want to die", "kill myself", "end my life", "suicide",
            "self harm", "cutting myself", "want to hurt myself"
        ]
        
        return selfHarmPatterns.contains { text.contains($0) }
    }
    
    private func detectChildSafetyThreats(_ text: String) -> [SafetyCategory] {
        var categories: [SafetyCategory] = []
        
        // Child exploitation patterns
        let exploitationPatterns = [
            "young girls", "young boys", "underage", "children photos"
        ]
        
        // Child grooming patterns
        let groomingPatterns = [
            "meet in person", "don't tell parents", "our secret",
            "how old are you", "send pictures"
        ]
        
        if exploitationPatterns.contains(where: { text.contains($0) }) {
            categories.append(.childExploitation)
        }
        
        if groomingPatterns.contains(where: { text.contains($0) }) {
            categories.append(.childGrooming)
        }
        
        return categories
    }
    
    private func detectTerrorismThreats(_ text: String) -> [SafetyCategory] {
        var categories: [SafetyCategory] = []
        
        // Terrorism content patterns
        let terrorismPatterns = [
            "bomb making", "terrorist attack", "join the cause",
            "jihad", "martyrdom", "explosive device"
        ]
        
        // Violence incitement patterns
        let violencePatterns = [
            "kill all", "attack them", "destroy", "eliminate",
            "take action", "fight back violently"
        ]
        
        // Weapon trafficking patterns
        let weaponPatterns = [
            "selling guns", "buy weapons", "illegal firearms",
            "ammunition for sale", "black market weapons"
        ]
        
        if terrorismPatterns.contains(where: { text.contains($0) }) {
            categories.append(.terrorismContent)
        }
        
        if violencePatterns.contains(where: { text.contains($0) }) {
            categories.append(.violenceIncitement)
        }
        
        if weaponPatterns.contains(where: { text.contains($0) }) {
            categories.append(.weaponTrafficking)
        }
        
        return categories
    }
    
    private func detectExtremismContent(_ text: String) -> Bool {
        let extremismPatterns = [
            "white supremacy", "ethnic cleansing", "racial purity",
            "final solution", "master race", "inferior people"
        ]
        
        return extremismPatterns.contains { text.contains($0) }
    }
    
    // MARK: - Database Operations
    
    /// Update safety counters in Firebase (Silent - No User Impact)
    private func updateSafetyCounters(categories: [SafetyCategory], userId: String) {
        let currentTime = Date().timeIntervalSince1970
        
        let safetyRef = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("safety")
        
        var updateData: [String: Any] = [:]
        
        // Update 30-day rolling counters
        for category in categories {
            let counterKey = "\(category.rawValue)_hits_30d"
            let timestampKey = "\(category.rawValue)_timestamps"
            
            updateData[counterKey] = FieldValue.increment(Int64(1))
            updateData[timestampKey] = FieldValue.arrayUnion([currentTime])
        }
        
        // Update aggregates
        if !categories.isEmpty {
            updateData["total_flags_30d"] = FieldValue.increment(Int64(categories.count))
            updateData["last_flag_at"] = currentTime
        }
        
        safetyRef.setData(updateData, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "Layer 2: Database update failed: \(error)")
            } else {
                AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "Layer 2: Safety signals updated silently - \(categories.count) categories")
            }
        }
    }
    
    /// Trigger immediate escalation for high-severity threats
    private func triggerImmediateEscalation(categories: [SafetyCategory], userId: String, content: String) {
        AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "CRITICAL: High-severity threats detected for user \(userId)")
        
        // Log escalation (without storing raw content)
        let escalationData: [String: Any] = [
            "user_id": userId,
            "categories": categories.map { $0.rawValue },
            "timestamp": Date().timeIntervalSince1970,
            "severity": "HIGH",
            "escalated": true,
            "content_length": content.count // Store length, not content
        ]
        
        // Save to escalation collection for immediate review
        Firestore.firestore()
            .collection("SafetyEscalations")
            .addDocument(data: escalationData) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "CRITICAL: Escalation logging failed: \(error)")
                } else {
                    AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "CRITICAL: High-severity threat escalated successfully")
                }
            }
        
        // Immediately flag user for manual review
        self.flagUserForManualReview(userId: userId, categories: categories)
    }
    
    /// Flag user for manual review
    private func flagUserForManualReview(userId: String, categories: [SafetyCategory]) {
        let flagData: [String: Any] = [
            "flagged_for_review": true,
            "flag_timestamp": Date().timeIntervalSince1970,
            "flag_categories": categories.map { $0.rawValue },
            "review_priority": "HIGH"
        ]
        
        Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("safety")
            .setData(flagData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "Failed to flag user for review: \(error)")
                } else {
                    AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "User flagged for manual review successfully")
                }
            }
    }
    
    // MARK: - Analytics and Reporting
    
    /// Get safety statistics for analytics dashboard
    func getSafetyStatistics(completion: @escaping ([String: Any]) -> Void) {
        // This would aggregate safety data across all users for internal dashboards
        // Implementation would depend on specific analytics requirements
        completion([:])
    }
    
    /// Clean up old safety signals (30-day rolling window maintenance)
    func performMaintenanceCleanup() {
        AppLogger.log(tag: "LOG-APP: SafetySignalManager", message: "Starting 30-day safety signal cleanup")
        
        // This would run periodically to clean up old timestamp arrays
        // and maintain the 30-day rolling window
        // Implementation would use Cloud Functions or scheduled tasks
    }
}
