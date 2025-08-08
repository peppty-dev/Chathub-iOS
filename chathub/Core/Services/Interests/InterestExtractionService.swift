import Foundation
import NaturalLanguage

/// InterestExtractionService
/// On-device keyword/keyphrase extraction and lightweight scoring with decay/cooldowns.
/// Maintains an in-memory store per chat to surface high-signal suggestions.
final class InterestExtractionService {
    static let shared = InterestExtractionService()

    struct Candidate: Codable {
        var score: Double
        var mentions: Int
        var lastSeenAt: TimeInterval
        var lastShownAt: TimeInterval?
        var cooldownUntil: TimeInterval?
        var dislikedCount: Int
        var accepted: Bool
    }

    private struct Store {
        var candidates: [String: Candidate] = [:]
        var lastMessageAt: TimeInterval = 0
    }

    // MARK: - Tuning
    struct Config {
        var minScoreToSuggest: Double = 2.75
        var minMentions: Int = 2
        var strongSingleMentionThreshold: Double = 4.5
        var triGramBoost: Double = 1.4
        var biGramBoost: Double = 1.2
        var posNerBoostPerToken: Double = 0.25
        var decayTimeConstantSeconds: TimeInterval = 60 * 30 // 30 min half-ish life
        var showCooldownSeconds: TimeInterval = 60 * 10      // 10 min per-candidate after shown
        var dislikeCooldownSeconds: TimeInterval = 60 * 60   // 1 hour suppression after dislike
        var sessionMaxSuggestionsPerHour: Int = 3
        var maxPhraseLength: Int = 30
        var minPhraseLength: Int = 3
    }

    private let config = Config()
    private var lastSuggestionByChat: [String: (phrase: String, timestamp: TimeInterval)] = [:]

    private var storesByChat: [String: Store] = [:]
    private var suggestionsShownTimestamps: [TimeInterval] = []

    private let queue = DispatchQueue(label: "interest.extraction.queue", qos: .userInitiated)

    private init() {}

    // MARK: - Public API

    /// Process a just-sent message, update scores, and optionally return a suggested interest phrase.
    /// - Parameters:
    ///   - chatId: Conversation identifier
    ///   - text: Message content
    ///   - existingInterests: Already accepted interests to avoid duplicates
    /// - Returns: A single suggestion to surface or nil if gating conditions are not met
    func processMessage(chatId: String, text: String, existingInterests: [String]) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var suggestion: String?
        queue.sync {
            var store = storesByChat[chatId] ?? Store()
            let now = Date().timeIntervalSince1970

            // Decay previous scores
            if store.lastMessageAt > 0 {
                let dt = now - store.lastMessageAt
                if dt > 0 {
                    let decayFactor = exp(-dt / config.decayTimeConstantSeconds)
                    for (key, var cand) in store.candidates {
                        cand.score *= decayFactor
                        store.candidates[key] = cand
                    }
                }
            }

            store.lastMessageAt = now

            // Tokenization and POS/NER boosts
            let tokens = tokenize(text: trimmed)
            if tokens.isEmpty { storesByChat[chatId] = store; return }
            let boostedTokens = boostedTokenSet(for: trimmed)

            // Build n-grams and update scores
            let ngrams = buildNgrams(tokens: tokens, nRange: 1...3)
            for phraseTokens in ngrams {
                let phrase = phraseTokens.joined(separator: " ")
                if phrase.count < config.minPhraseLength || phrase.count > config.maxPhraseLength { continue }
                if isAllStopwords(phraseTokens) { continue }

                let size = phraseTokens.count
                var inc: Double = 1.0
                if size == 2 { inc *= config.biGramBoost }
                if size >= 3 { inc *= config.triGramBoost }

                // POS/NER boost if tokens are flagged
                var posBoost = 0.0
                for t in phraseTokens where boostedTokens.contains(t) { posBoost += config.posNerBoostPerToken }
                inc += posBoost

                var cand = store.candidates[phrase] ?? Candidate(score: 0, mentions: 0, lastSeenAt: now, lastShownAt: nil, cooldownUntil: nil, dislikedCount: 0, accepted: false)
                cand.score += inc
                cand.mentions += 1
                cand.lastSeenAt = now
                store.candidates[phrase] = cand
            }

            // Choose a suggestion
            suggestion = selectSuggestion(from: store, now: now, existingInterests: existingInterests, chatId: chatId)

            // Stamp lastShownAt if we chose one and update store
            if let s = suggestion {
                var cand = store.candidates[s]!
                cand.lastShownAt = now
                cand.cooldownUntil = now + config.showCooldownSeconds
                store.candidates[s] = cand
                suggestionsShownTimestamps.append(now)
            }

            storesByChat[chatId] = store
        }

        return suggestion
    }

    /// Mark a suggestion as accepted to keep it from resurfacing and to bias future scoring.
    func markAccepted(chatId: String, phrase: String) {
        queue.sync {
            guard var store = storesByChat[chatId], var cand = store.candidates[phrase] else { return }
            cand.accepted = true
            cand.cooldownUntil = Date().timeIntervalSince1970 + config.dislikeCooldownSeconds // long cooldown anyway
            cand.score *= 0.5
            store.candidates[phrase] = cand
            storesByChat[chatId] = store
        }
    }

    /// Mark a suggestion as disliked and suppress for a cooldown period.
    func markDisliked(chatId: String, phrase: String) {
        queue.sync {
            guard var store = storesByChat[chatId], var cand = store.candidates[phrase] else { return }
            cand.dislikedCount += 1
            cand.cooldownUntil = Date().timeIntervalSince1970 + config.dislikeCooldownSeconds
            cand.score *= 0.3
            store.candidates[phrase] = cand
            storesByChat[chatId] = store
        }
    }

    // MARK: - Selection & Gating

    private func selectSuggestion(from store: Store, now: TimeInterval, existingInterests: [String], chatId: String) -> String? {
        // Per-session rate limit: only a few per hour
        let oneHourAgo = now - 3600
        let shownLastHour = suggestionsShownTimestamps.filter { $0 > oneHourAgo }.count
        if shownLastHour >= config.sessionMaxSuggestionsPerHour { return nil }

        // Avoid repeating the exact last suggestion back-to-back for this chat unless its score improved
        let lastForChat = lastSuggestionByChat[chatId]?.phrase

        // Rank candidates by score, apply gating
        let sorted = store.candidates.sorted { lhs, rhs in
            if abs(lhs.value.score - rhs.value.score) > 0.0001 { return lhs.value.score > rhs.value.score }
            return (lhs.value.lastSeenAt) > (rhs.value.lastSeenAt)
        }

        for (phrase, cand) in sorted {
            if cand.accepted { continue }
            if let cd = cand.cooldownUntil, cd > now { continue }
            if existingInterests.contains(where: { $0.caseInsensitiveCompare(phrase) == .orderedSame }) { continue }
            if let last = lastForChat, last.caseInsensitiveCompare(phrase) == .orderedSame { continue }
            if cand.score < config.minScoreToSuggest { continue }
            if cand.mentions < config.minMentions && cand.score < config.strongSingleMentionThreshold { continue }
            lastSuggestionByChat[chatId] = (phrase, now)
            return phrase
        }
        return nil
    }

    // MARK: - NLP Helpers

    private func tokenize(text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range]).lowercased()
            if token.range(of: "\\p{L}", options: .regularExpression) != nil { // has a letter
                if !Self.stopwords.contains(token) {
                    result.append(token)
                }
            }
            return true
        }
        return result
    }

    private func boostedTokenSet(for text: String) -> Set<String> {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        let opts: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther, .joinNames]
        var boosted: Set<String> = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: opts) { tag, range in
            guard let lex = tag else { return true }
            let token = String(text[range]).lowercased()
            if Self.stopwords.contains(token) { return true }
            if lex == .noun { boosted.insert(token) }
            // Also check nameType
            let nameTag = tagger.tag(at: range.lowerBound, unit: .word, scheme: .nameType).0
            if let nameTag = nameTag, (nameTag == .personalName || nameTag == .placeName || nameTag == .organizationName) {
                boosted.insert(token)
            }
            return true
        }
        return boosted
    }

    private func buildNgrams(tokens: [String], nRange: ClosedRange<Int>) -> [[String]] {
        var out: [[String]] = []
        let nValues = Array(nRange)
        for n in nValues {
            guard n >= 1 else { continue }
            if tokens.count < n { continue }
            for i in 0...(tokens.count - n) {
                let slice = Array(tokens[i..<(i + n)])
                out.append(slice)
            }
        }
        return out
    }

    private func isAllStopwords(_ tokens: [String]) -> Bool {
        for t in tokens { if !Self.stopwords.contains(t) { return false } }
        return true
    }

    // MARK: - Stopwords (EN minimal seed; expand per language as needed)
    private static let stopwords: Set<String> = [
        "a","an","and","are","as","at","be","but","by","for","if","in","into","is","it","no","not","of","on","or","such","that","the","their","then","there","these","they","this","to","was","will","with","i","you","he","she","we","they","me","him","her","them","my","your","our","their","yours","ours","theirs","so","too","very","just","can","could","should","would","from","about","via","over","under","up","down","out","off","than","also","more","most","less","least"
    ]
}


