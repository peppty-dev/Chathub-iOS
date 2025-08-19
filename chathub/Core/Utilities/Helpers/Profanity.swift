import Foundation
import UIKit

class ProfanityClass {
    private static let digitsPattern = NSRegularExpression.try(pattern: "\\d")
    private static let defaultCacheSize = 2048
    private static var instance: ProfanityClass?
    private static let lock = NSLock()
    
    // iOS singleton pattern for compatibility with existing code
    static let share = ProfanityClass.getInstance()
    
    private let backgroundQueue = DispatchQueue(label: "profanity.background", qos: .utility)
    private var pendingProfanityTasks: [String: DispatchWorkItem] = [:]
    private var sessionManager: SessionManager
    private var profanitySet: Set<String> = []
    private var profanitySetAppNames: Set<String> = []
    
    // Separate caches for each method
    private var removeProfanityCache: NSCache<NSString, NSString>
    private var removeProfanityNumbersCache: NSCache<NSString, NSString>
    private var containsProfanityCache: NSCache<NSString, NSNumber>
    private var containsProfanityNumbersCache: NSCache<NSString, NSNumber>
    private var containsProfanityAppNameCache: NSCache<NSString, NSNumber>
    private var patternCache: NSCache<NSString, NSRegularExpression>
    
    private init() {
        self.sessionManager = SessionManager.shared
        
        // Initialize caches with a reasonable size
        let cacheSize = Self.defaultCacheSize
        removeProfanityCache = NSCache<NSString, NSString>()
        removeProfanityCache.countLimit = cacheSize
        
        removeProfanityNumbersCache = NSCache<NSString, NSString>()
        removeProfanityNumbersCache.countLimit = cacheSize
        
        containsProfanityCache = NSCache<NSString, NSNumber>()
        containsProfanityCache.countLimit = cacheSize
        
        containsProfanityNumbersCache = NSCache<NSString, NSNumber>()
        containsProfanityNumbersCache.countLimit = cacheSize
        
        containsProfanityAppNameCache = NSCache<NSString, NSNumber>()
        containsProfanityAppNameCache.countLimit = cacheSize
        
        patternCache = NSCache<NSString, NSRegularExpression>()
        patternCache.countLimit = 256 // Smaller cache for patterns might be sufficient
        
        initializeProfanityWords()
    }
    
    static func getInstance() -> ProfanityClass {
        if instance == nil {
            lock.lock()
            if instance == nil {
                instance = ProfanityClass()
            }
            lock.unlock()
        }
        return instance!
    }
    
    private func initializeProfanityWords() {
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "initializeProfanityWords sessionManager.profanityWords = \(sessionManager.profanityWords ?? "nil")")
        
        if let sessionProfanity = sessionManager.profanityWords {
            do {
                if let data = sessionProfanity.data(using: .utf8) {
                    if let profanityArray = try JSONSerialization.jsonObject(with: data, options: []) as? [String] {
                        profanitySet.removeAll()
                        for word in profanityArray {
                            if !word.isEmpty {
                                profanitySet.insert(word)
                            }
                        }
                    }
                }
            } catch {
                AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "Error initializing profanity words: \(error.localizedDescription)")
                // Initialize with empty set if there's an error
                profanitySet = Set<String>()
            }
        } else {
            // Initialize with empty set if no words are loaded yet
            profanitySet = Set<String>()
        }
        
        if let sessionProfanityAppNames = sessionManager.profanityAppNameWords {
            do {
                if let data = sessionProfanityAppNames.data(using: .utf8) {
                    if let profanityArray2 = try JSONSerialization.jsonObject(with: data, options: []) as? [String] {
                        profanitySetAppNames.removeAll()
                        for word in profanityArray2 {
                            if !word.isEmpty {
                                profanitySetAppNames.insert(word)
                            }
                        }
                    }
                }
            } catch {
                AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "Error initializing app name profanity words: \(error.localizedDescription)")
                // Initialize with empty set if there's an error
                profanitySetAppNames = Set<String>()
            }
        } else {
            // Initialize with empty set if no words are loaded yet
            profanitySetAppNames = Set<String>()
        }
    }
    
    private func getOrCreatePattern(_ word: String) -> NSRegularExpression? {
        if word.isEmpty {
            return try? NSRegularExpression(pattern: "", options: [])
        }
        
        let cacheKey = NSString(string: word)
        if let pattern = patternCache.object(forKey: cacheKey) {
            return pattern
        }
        
        do {
            // Escape any regex special characters and wrap in word boundaries
            let safePattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
            let pattern = try NSRegularExpression(pattern: safePattern, options: .caseInsensitive)
            patternCache.setObject(pattern, forKey: cacheKey)
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "Created new pattern for word")
            return pattern
        } catch {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "Failed to create pattern, error: \(error.localizedDescription)")
            // Return a safe default pattern that matches nothing
            return try? NSRegularExpression(pattern: "", options: [])
        }
    }
    
    func removeProfanity(_ text: String) -> String {
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanity() input: \(text), profanitySet size: \(profanitySet.count)")
        
        if sessionManager.isUserSubscribedToPro() {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanity() premium user")
            return text
        }
        
        if text.isEmpty || profanitySet.isEmpty {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanity() no text or empty profanity set")
            return text
        }
        
        let cacheKey = NSString(string: text)
        if let cachedResult = removeProfanityCache.object(forKey: cacheKey) as String? {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanity() from cache = \(cachedResult)")
            return cachedResult
        }
        
        var cleanText = text
        var lowerText = text.lowercased()
        
        for word in profanitySet {
            if !word.isEmpty {
                // First try exact word boundary match
                if let pattern = getOrCreatePattern(word) {
                    let tempText = pattern.stringByReplacingMatches(in: cleanText, options: [], range: NSRange(location: 0, length: cleanText.count), withTemplate: "")
                    
                    // If no change, try more aggressive matching without word boundaries
                    if tempText == cleanText && lowerText.contains(word.lowercased()) {
                        if let aggressivePattern = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: word), options: .caseInsensitive) {
                            let aggressiveTempText = aggressivePattern.stringByReplacingMatches(in: cleanText, options: [], range: NSRange(location: 0, length: cleanText.count), withTemplate: "")
                            if aggressiveTempText != cleanText {
                                cleanText = aggressiveTempText
                                lowerText = cleanText.lowercased()
                                AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanity() removed word: \(word)")
                            }
                        }
                    } else if tempText != cleanText {
                        cleanText = tempText
                        lowerText = cleanText.lowercased()
                        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanity() removed word: \(word)")
                    }
                }
            }
        }
        
        removeProfanityCache.setObject(NSString(string: cleanText), forKey: cacheKey)
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanity() final text = \(cleanText)")
        
        return cleanText
    }
    
    func removeProfanityNumbersAllowed(_ text: String) -> String {
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanityNumbersAllowed() text length: \(text.count), profanitySet size: \(profanitySet.count)")
        
        if sessionManager.isUserSubscribedToPro() {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanityNumbersAllowed() premium user")
            return text
        }
        
        if text.isEmpty || profanitySet.isEmpty {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanityNumbersAllowed() no text or empty profanity set")
            return text
        }
        
        // Check cache first
        let cacheKey = NSString(string: text)
        if let cachedResult = removeProfanityNumbersCache.object(forKey: cacheKey) as String? {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanityNumbersAllowed() from cache = \(cachedResult)")
            return cachedResult
        }
        
        // For main thread calls, do a quick check for obvious profanity
        // This is a fast path that doesn't use regex
        if Thread.isMainThread {
            let lowerText = text.lowercased()
            var mightContainProfanity = false
            
            // Quick check without regex
            for word in profanitySet {
                if !word.isEmpty && Self.digitsPattern?.firstMatch(in: word, options: [], range: NSRange(location: 0, length: word.count)) == nil
                    && lowerText.contains(word.lowercased()) {
                    mightContainProfanity = true
                    break
                }
            }
            
            if !mightContainProfanity {
                // No profanity detected in quick check, cache and return original
                removeProfanityNumbersCache.setObject(NSString(string: text), forKey: cacheKey)
                return text
            }
            
            // Submit task for background processing and return original text for now
            // This will be cached for next time
            let workItem = DispatchWorkItem { [weak self] in
                let result = self?.processTextForProfanity(text) ?? text
                DispatchQueue.main.async {
                    self?.removeProfanityNumbersCache.setObject(NSString(string: result), forKey: cacheKey)
                    self?.pendingProfanityTasks.removeValue(forKey: text)
                }
            }
            pendingProfanityTasks[text] = workItem
            backgroundQueue.async(execute: workItem)
            return text
        }
        
        // If we're already on a background thread, process synchronously
        return processTextForProfanity(text)
    }
    
    private func processTextForProfanity(_ text: String) -> String {
        var cleanText = text
        
        if sessionManager.isUserSubscribedToPro() {
            return text
        }
        
        var lowerText = text.lowercased()
        
        for word in profanitySet {
            do {
                // Skip null, empty, or digit-only words
                if word.isEmpty || Self.digitsPattern?.firstMatch(in: word, options: [], range: NSRange(location: 0, length: word.count)) != nil {
                    continue
                }
                
                // First try exact word boundary match
                if let pattern = getOrCreatePattern(word) {
                    let tempText = pattern.stringByReplacingMatches(in: cleanText, options: [], range: NSRange(location: 0, length: cleanText.count), withTemplate: "")
                    
                    // If no change, try more aggressive matching without word boundaries
                    if tempText == cleanText && lowerText.contains(word.lowercased()) {
                        if let aggressivePattern = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: word), options: .caseInsensitive) {
                            let aggressiveTempText = aggressivePattern.stringByReplacingMatches(in: cleanText, options: [], range: NSRange(location: 0, length: cleanText.count), withTemplate: "")
                            if aggressiveTempText != cleanText {
                                cleanText = aggressiveTempText
                                lowerText = cleanText.lowercased()
                                AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanityNumbersAllowed() removed word: \(word)")
                            }
                        }
                    } else if tempText != cleanText {
                        cleanText = tempText
                        lowerText = cleanText.lowercased()
                        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanityNumbersAllowed() removed word: \(word)")
                    }
                }
            } catch {
                AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "Error processing word: \(error.localizedDescription)")
                continue
            }
        }
        
        // Only cache if actually modified
        let cacheKey = NSString(string: text)
        if cleanText != text {
            removeProfanityNumbersCache.setObject(NSString(string: cleanText), forKey: cacheKey)
        } else {
            removeProfanityNumbersCache.setObject(NSString(string: text), forKey: cacheKey)
        }
        
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfanityNumbersAllowed() final = \(cleanText)")
        return cleanText
    }
    
    func doesContainProfanity(_ text: String) -> Bool {
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanity() text: \(text), profanitySet size: \(profanitySet.count)")
        
        if sessionManager.isUserSubscribedToPro() {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanity() premium user")
            return false
        }
        
        if text.isEmpty || profanitySet.isEmpty {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanity() no text or empty profanity set")
            return false
        }
        
        let cacheKey = NSString(string: text)
        if let cachedResult = containsProfanityCache.object(forKey: cacheKey) {
            let result = cachedResult.boolValue
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanity() from cache = \(result)")
            return result
        }
        
        let lowerText = text.lowercased()
        for word in profanitySet {
            if !word.isEmpty {
                // First try exact word boundary match
                if let pattern = getOrCreatePattern(word) {
                    if pattern.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) != nil {
                        containsProfanityCache.setObject(NSNumber(value: true), forKey: cacheKey)
                        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanity() true found word: \(word)")
                        return true
                    }
                }
                
                // If no match, try more aggressive matching without word boundaries
                if lowerText.contains(word.lowercased()) {
                    containsProfanityCache.setObject(NSNumber(value: true), forKey: cacheKey)
                    AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanity() true found word: \(word)")
                    return true
                }
            }
        }
        
        containsProfanityCache.setObject(NSNumber(value: false), forKey: cacheKey)
        return false
    }
    
    func doesContainProfanityNumbersAllowed(_ text: String) -> Bool {
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityNumbersAllowed() text: \(text), profanitySet size: \(profanitySet.count)")
        
        if sessionManager.isUserSubscribedToPro() {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityNumbersAllowed() premium user")
            return false
        }
        
        if text.isEmpty || profanitySet.isEmpty {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityNumbersAllowed() no text or empty profanity set")
            return false
        }
        
        let cacheKey = NSString(string: text)
        if let cachedResult = containsProfanityNumbersCache.object(forKey: cacheKey) {
            let result = cachedResult.boolValue
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityNumbersAllowed() from cache = \(result)")
            return result
        }
        
        let lowerText = text.lowercased()
        for word in profanitySet {
            do {
                // Skip null, empty, or digit-only words
                if word.isEmpty || Self.digitsPattern?.firstMatch(in: word, options: [], range: NSRange(location: 0, length: word.count)) != nil {
                    continue
                }
                
                // First try exact word boundary match
                if let pattern = getOrCreatePattern(word) {
                    if pattern.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) != nil {
                        containsProfanityNumbersCache.setObject(NSNumber(value: true), forKey: cacheKey)
                        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityNumbersAllowed() true found word: \(word)")
                        return true
                    }
                }
                
                // If no match, try more aggressive matching without word boundaries
                if lowerText.contains(word.lowercased()) {
                    containsProfanityNumbersCache.setObject(NSNumber(value: true), forKey: cacheKey)
                    AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityNumbersAllowed() true found word: \(word)")
                    return true
                }
            } catch {
                AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "Error processing word: \(error.localizedDescription)")
                continue
            }
        }
        
        containsProfanityNumbersCache.setObject(NSNumber(value: false), forKey: cacheKey)
        return false
    }
    
    func doesContainProfanityAppName(_ text: String) -> Bool {
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityAppName() text: \(text), profanitySetAppNames size: \(profanitySetAppNames.count)")
        
        if text.isEmpty || profanitySetAppNames.isEmpty {
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityAppName() no text or empty profanity set")
            return false
        }
        
        let cacheKey = NSString(string: text)
        if let cachedResult = containsProfanityAppNameCache.object(forKey: cacheKey) {
            let result = cachedResult.boolValue
            AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityAppName() from cache = \(result)")
            return result
        }
        
        let lowerText = text.lowercased()
        for word in profanitySetAppNames {
            if !word.isEmpty {
                // First try exact word boundary match
                if let pattern = getOrCreatePattern(word) {
                    if pattern.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) != nil {
                        containsProfanityAppNameCache.setObject(NSNumber(value: true), forKey: cacheKey)
                        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityAppName() true found word: \(word)")
                        return true
                    }
                }
                
                // If no match, try more aggressive matching without word boundaries
                if lowerText.contains(word.lowercased()) {
                    containsProfanityAppNameCache.setObject(NSNumber(value: true), forKey: cacheKey)
                    AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityAppName() true found word: \(word)")
                    return true
                }
            }
        }
        
        containsProfanityAppNameCache.setObject(NSNumber(value: false), forKey: cacheKey)
        return false
    }
    
    /**
     * Cleans up resources used by this class.
     * Should be called when the app is being destroyed.
     */
    func cleanup() {
        // Clear pending tasks map if needed, but keep queue running
        pendingProfanityTasks.removeAll()
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "Cleanup called, cleared pending tasks map.")
    }
    
    /// Refreshes profanity words from SessionManager - Android parity method
    /// Called when ProfanityService updates the word lists
    func refreshProfanityWords() {
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "refreshProfanityWords() called - reinitializing profanity word sets")
        
        // Clear all caches since word lists have changed
        removeProfanityCache.removeAllObjects()
        removeProfanityNumbersCache.removeAllObjects()
        containsProfanityCache.removeAllObjects()
        containsProfanityNumbersCache.removeAllObjects()
        containsProfanityAppNameCache.removeAllObjects()
        patternCache.removeAllObjects()
        
        // Reinitialize profanity words from SessionManager
        initializeProfanityWords()
        
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "refreshProfanityWords() completed - profanitySet size: \(profanitySet.count), profanitySetAppNames size: \(profanitySetAppNames.count)")
    }
    
    // MARK: - Enhanced Methods with Elongation Support
    
    /// Remove profane words from text but keep clean words for interest extraction
    /// Uses elongation normalization for better detection
    func removeProfaneWordsOnly(_ text: String) -> String {
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfaneWordsOnly() input: '\(text)'")
        
        // Skip for premium users
        if sessionManager.isUserSubscribedToPro() {
            return text
        }
        
        guard !text.isEmpty, !profanitySet.isEmpty else {
            return text
        }
        
        // Check cache first
        let cacheKey = "removeProfaneOnly_\(text)" as NSString
        if let cached = removeProfanityCache.object(forKey: cacheKey) {
            return cached as String
        }
        
        // Tokenize the text to work on individual words
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var cleanWords: [String] = []
        
        for word in words {
            let trimmedWord = word.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            
            if trimmedWord.isEmpty {
                cleanWords.append(word) // Keep original spacing/punctuation
                continue
            }
            
            // Normalize elongation before checking profanity
            let normalizedWord = normalizeElongationForProfanity(trimmedWord)
            
            // Check if normalized word is profane
            if isProfaneWord(normalizedWord) {
                AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfaneWordsOnly() removed profane word: '\(word)' (normalized: '\(normalizedWord)')")
                // Skip this word (remove it)
                continue
            } else {
                cleanWords.append(word) // Keep the word
            }
        }
        
        let result = cleanWords.joined(separator: " ")
        
        // Cache the result
        removeProfanityCache.setObject(result as NSString, forKey: cacheKey)
        
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "removeProfaneWordsOnly() result: '\(result)'")
        return result
    }
    
    /// Enhanced profanity detection with elongation normalization
    func doesContainProfanityWithElongation(_ text: String) -> Bool {
        AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityWithElongation() input: '\(text)'")
        
        // Skip for premium users
        if sessionManager.isUserSubscribedToPro() {
            return false
        }
        
        guard !text.isEmpty, !profanitySet.isEmpty else {
            return false
        }
        
        // Check cache first
        let cacheKey = "containsElongated_\(text)" as NSString
        if let cached = containsProfanityCache.object(forKey: cacheKey) {
            return cached.boolValue
        }
        
        // Check individual words with elongation normalization
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            let trimmedWord = word.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            
            if trimmedWord.isEmpty { continue }
            
            // Normalize elongation before checking profanity
            let normalizedWord = normalizeElongationForProfanity(trimmedWord)
            
            if isProfaneWord(normalizedWord) {
                AppLogger.log(tag: "LOG-APP: ProfanityClass", message: "doesContainProfanityWithElongation() found profane word: '\(word)' (normalized: '\(normalizedWord)')")
                
                // Cache the result
                containsProfanityCache.setObject(NSNumber(value: true), forKey: cacheKey)
                return true
            }
        }
        
        // Cache the result
        containsProfanityCache.setObject(NSNumber(value: false), forKey: cacheKey)
        return false
    }
    
    /// Normalize elongated words for profanity detection (similar to interest extraction)
    private func normalizeElongationForProfanity(_ word: String) -> String {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Multi-pass normalization to handle elongation anywhere in the word
        var normalized = trimmed
        var previousNormalized = ""
        var passCount = 0
        
        // Keep normalizing until no more changes (handles complex cases)
        while normalized != previousNormalized && passCount < 5 {
            previousNormalized = normalized
            passCount += 1
            
            // Replace all instances of 3+ consecutive identical characters with single character
            let consecutivePattern = "(.)\\1{2,}"
            if let regex = try? NSRegularExpression(pattern: consecutivePattern, options: []) {
                let range = NSRange(location: 0, length: normalized.utf16.count)
                normalized = regex.stringByReplacingMatches(in: normalized, options: [], range: range, withTemplate: "$1")
            }
        }
        
        return normalized
    }
    
    /// Check if a single word is profane (helper method)
    private func isProfaneWord(_ word: String) -> Bool {
        let lowerWord = word.lowercased()
        
        // Direct lookup first
        if profanitySet.contains(lowerWord) {
            return true
        }
        
        // Pattern-based checking for partial matches
        for profaneWord in profanitySet {
            if !profaneWord.isEmpty {
                // Check if profane word is contained in the input word
                if lowerWord.contains(profaneWord.lowercased()) {
                    return true
                }
            }
        }
        
        return false
    }
}

// MARK: - Convenience Typealias for iOS Compatibility
typealias Profanity = ProfanityClass

// MARK: - NSRegularExpression Extension
extension NSRegularExpression {
    static func `try`(pattern: String) -> NSRegularExpression? {
        return try? NSRegularExpression(pattern: pattern, options: [])
    }
}
