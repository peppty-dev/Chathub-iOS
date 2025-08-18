import Foundation
import NaturalLanguage
import CoreML

/// Advanced Profanity Filtering Service using Apple's AI/ML Frameworks
/// Provides comprehensive content moderation capabilities using on-device ML models
final class ProfanityFilterService {
    static let shared = ProfanityFilterService()
    private init() {}
    
    // MARK: - Configuration
    struct FilterConfig {
        var strictnessLevel: StrictnessLevel = .moderate
        var enableSentimentAnalysis: Bool = true
        var enablePatternDetection: Bool = true
        var enableContextAnalysis: Bool = true
        var profanityThreshold: Double = 0.1 // 10% of words
    }
    
    enum StrictnessLevel: Int, CaseIterable {
        case permissive = 1
        case moderate = 2
        case strict = 3
        
        var threshold: Double {
            switch self {
            case .permissive: return 0.2  // 20%
            case .moderate: return 0.1    // 10%
            case .strict: return 0.05     // 5%
            }
        }
    }
    
    enum ContentSafety {
        case safe
        case questionable(reasons: [String])
        case unsafe(reasons: [String])
    }
    
    private var config = FilterConfig()
    
    // MARK: - Public API
    
    /// Analyze text content for profanity and offensive language
    func analyzeContent(_ text: String, config: FilterConfig? = nil) -> ContentSafety {
        let activeConfig = config ?? self.config
        var reasons: [String] = []
        var unsafeCount = 0
        
        // 1. Sentiment Analysis using Apple's NL framework
        if activeConfig.enableSentimentAnalysis {
            let sentimentResult = analyzeSentiment(text)
            if sentimentResult.isHighlyNegative {
                reasons.append("Negative sentiment detected")
                unsafeCount += 1
            }
        }
        
        // 2. Pattern-based detection
        if activeConfig.enablePatternDetection {
            let patternResult = detectOffensivePatterns(text, strictness: activeConfig.strictnessLevel)
            if !patternResult.isEmpty {
                reasons.append("Offensive patterns: \(patternResult.joined(separator: ", "))")
                unsafeCount += patternResult.count
            }
        }
        
        // 3. Context analysis
        if activeConfig.enableContextAnalysis {
            let contextResult = analyzeContext(text)
            if contextResult.isSuspicious {
                reasons.append("Suspicious context detected")
                unsafeCount += 1
            }
        }
        
        // 4. Word-level analysis
        let wordAnalysis = analyzeWords(text, strictness: activeConfig.strictnessLevel)
        if wordAnalysis.profanityRatio > activeConfig.profanityThreshold {
            reasons.append("High profanity ratio: \(String(format: "%.1f%%", wordAnalysis.profanityRatio * 100))")
            unsafeCount += 1
        }
        
        // Determine final safety level
        if unsafeCount == 0 {
            return .safe
        } else if unsafeCount <= 1 {
            return .questionable(reasons: reasons)
        } else {
            return .unsafe(reasons: reasons)
        }
    }
    
    /// Quick check if text is safe for display
    func isSafeContent(_ text: String) -> Bool {
        switch analyzeContent(text) {
        case .safe:
            return true
        case .questionable, .unsafe:
            return false
        }
    }
    
    /// Clean text by removing or replacing profane content
    func cleanText(_ text: String, replacement: String = "***") -> String {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var cleanedText = text
        var offset = 0
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            if isProfaneWord(word) {
                let adjustedRange = Range(
                    uncheckedBounds: (
                        text.index(range.lowerBound, offsetBy: offset),
                        text.index(range.upperBound, offsetBy: offset)
                    )
                )
                cleanedText.replaceSubrange(adjustedRange, with: replacement)
                offset += replacement.count - word.count
            }
            return true
        }
        
        return cleanedText
    }
    
    // MARK: - Analysis Methods
    
    private struct SentimentResult {
        let score: Double
        let isHighlyNegative: Bool
    }
    
    private func analyzeSentiment(_ text: String) -> SentimentResult {
        // Note: .sentiment is not available in all iOS versions
        // Using lexical analysis as fallback for sentiment detection
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var negativeScore: Double = 0
        var totalWords = 0
        
        // Analyze sentiment by looking for negative/positive words
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            let word = String(text[range]).lowercased()
            totalWords += 1
            
            // Basic sentiment analysis using word lists
            let negativeWords = ["hate", "angry", "terrible", "awful", "disgusting", "horrible", "stupid", "worst", "sucks", "pathetic"]
            let positiveWords = ["love", "great", "awesome", "wonderful", "amazing", "fantastic", "excellent", "best", "beautiful", "perfect"]
            
            if negativeWords.contains(word) {
                negativeScore += 1.0
            } else if positiveWords.contains(word) {
                negativeScore -= 0.5 // Reduce negative score for positive content
            }
            
            return true
        }
        
        let avgNegativeScore = totalWords > 0 ? negativeScore / Double(totalWords) : 0
        
        return SentimentResult(
            score: avgNegativeScore,
            isHighlyNegative: avgNegativeScore > 0.7
        )
    }
    
    private func detectOffensivePatterns(_ text: String, strictness: StrictnessLevel) -> [String] {
        var detectedPatterns: [String] = []
        let lowercased = text.lowercased()
        
        // Basic profanity patterns (masked for code safety)
        let basicPatterns = [
            "f[u*@#]+ck", "sh[i*@#]+t", "d[a*@#]+mn", "b[i*@#]+tch",
            "a[s*@#]+s", "cr[a*@#]+p", "h[e*@#]+ll", "st[u*@#]+pid"
        ]
        
        // Moderate level patterns
        let moderatePatterns = [
            "[@#$%*]{2,}", // Multiple symbols (often used to mask profanity)
            "([a-z])\\1{4,}", // Excessive repeated characters
            "wtf", "omfg", "fml" // Common abbreviations
        ]
        
        // Strict patterns (harassment, threats)
        let strictPatterns = [
            "kill yourself", "go die", "kys",
            "hate you", "you suck", "loser",
            "retard", "stupid idiot"
        ]
        
        var patterns = basicPatterns
        if strictness.rawValue >= 2 { patterns += moderatePatterns }
        if strictness.rawValue >= 3 { patterns += strictPatterns }
        
        for pattern in patterns {
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                detectedPatterns.append(pattern)
            }
        }
        
        return detectedPatterns
    }
    
    private struct ContextResult {
        let isSuspicious: Bool
        let suspiciousElements: [String]
    }
    
    private func analyzeContext(_ text: String) -> ContextResult {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var suspiciousElements: [String] = []
        var aggressiveWords = 0
        var totalWords = 0
        
        // Check for aggressive language patterns
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            let word = String(text[range]).lowercased()
            totalWords += 1
            
            // Look for aggressive verbs and adjectives
            if let pos = tag {
                if pos == .verb || pos == .adjective {
                    let aggressiveWordsList = ["hate", "kill", "destroy", "murder", "attack", "fight", "angry", "furious", "rage"]
                    if aggressiveWordsList.contains(word) {
                        aggressiveWords += 1
                        suspiciousElements.append(word)
                    }
                }
            }
            return true
        }
        
        // Check for excessive capitalization (shouting)
        let uppercaseRatio = Double(text.filter { $0.isUppercase }.count) / Double(text.count)
        if uppercaseRatio > 0.5 && text.count > 10 {
            suspiciousElements.append("excessive_caps")
        }
        
        // Check for excessive punctuation
        let punctuationCount = text.filter { "!?.,;:".contains($0) }.count
        if punctuationCount > text.count / 4 {
            suspiciousElements.append("excessive_punctuation")
        }
        
        let isSuspicious = suspiciousElements.count > 0 || (Double(aggressiveWords) / Double(max(totalWords, 1))) > 0.2
        
        return ContextResult(isSuspicious: isSuspicious, suspiciousElements: suspiciousElements)
    }
    
    private struct WordAnalysis {
        let profaneWords: [String]
        let profanityRatio: Double
        let totalWords: Int
    }
    
    private func analyzeWords(_ text: String, strictness: StrictnessLevel) -> WordAnalysis {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var profaneWords: [String] = []
        var totalWords = 0
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            if word.range(of: "\\p{L}", options: .regularExpression) != nil {
                totalWords += 1
                if isProfaneWord(word, strictness: strictness) {
                    profaneWords.append(word)
                }
            }
            return true
        }
        
        let ratio = totalWords > 0 ? Double(profaneWords.count) / Double(totalWords) : 0
        
        return WordAnalysis(
            profaneWords: profaneWords,
            profanityRatio: ratio,
            totalWords: totalWords
        )
    }
    
    private func isProfaneWord(_ word: String, strictness: StrictnessLevel = .moderate) -> Bool {
        let lowercased = word.lowercased()
        
        // Basic profanity list (you can expand this)
        let basicProfanity = ["fuck", "shit", "damn", "bitch", "ass", "crap", "hell"]
        let moderateProfanity = ["stupid", "idiot", "dumb", "moron", "retard"]
        let strictProfanity = ["hate", "sucks", "loser", "ugly", "fat"]
        
        if basicProfanity.contains(lowercased) { return true }
        if strictness.rawValue >= 2 && moderateProfanity.contains(lowercased) { return true }
        if strictness.rawValue >= 3 && strictProfanity.contains(lowercased) { return true }
        
        return false
    }
}

// MARK: - Extensions for easy usage

extension String {
    /// Quick check if string is safe
    var isSafeContent: Bool {
        return ProfanityFilterService.shared.isSafeContent(self)
    }
    
    /// Clean the string of profanity
    var cleaned: String {
        return ProfanityFilterService.shared.cleanText(self)
    }
    
    /// Get detailed content analysis
    var contentSafety: ProfanityFilterService.ContentSafety {
        return ProfanityFilterService.shared.analyzeContent(self)
    }
}
