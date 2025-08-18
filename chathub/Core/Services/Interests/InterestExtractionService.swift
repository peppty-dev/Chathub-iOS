import Foundation
import NaturalLanguage
import CoreML

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
        var minScoreToSuggest: Double = 2.0  // Lower threshold since we're boosting activity words
        var minMentions: Int = 1  // Allow single mentions for strong activity words
        var strongSingleMentionThreshold: Double = 3.0  // Lower for activity words with boost
        var posNerBoostPerToken: Double = 0.5  // Increased boost for nouns/named entities
        var decayTimeConstantSeconds: TimeInterval = 60 * 30 // 30 min half-ish life
        var showCooldownSeconds: TimeInterval = 60 * 10      // 10 min per-candidate after shown
        var dislikeCooldownSeconds: TimeInterval = 60 * 60   // 1 hour suppression after dislike
        var sessionMaxSuggestionsPerHour: Int = 3
        var maxPhraseLength: Int = 20  // Shorter since we're focusing on single words
        var minPhraseLength: Int = 3   // Keep minimum word length
        var maxDislikesBeforePermanentRemoval: Int = 2  // Remove suggestion after 2 rejections
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
        
        // PROFANITY CHECK: Don't process messages with offensive content
        if containsProfanity(trimmed) {
            AppLogger.log(tag: "InterestExtraction", message: "Message contains profanity, skipping interest extraction")
            return nil
        }

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

            // Extract single words with ML-based significance scoring
            for token in tokens {
                let phrase = token
                if phrase.count < config.minPhraseLength || phrase.count > config.maxPhraseLength { continue }

                // Base score with ML-enhanced weighting
                var inc: Double = 1.0
                
                // Get linguistic analysis for this token
                let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
                tagger.string = trimmed
                
                if let wordRange = trimmed.range(of: phrase, options: [.caseInsensitive]) {
                    let lexicalClass = tagger.tag(at: wordRange.lowerBound, unit: .word, scheme: .lexicalClass).0
                    let nameType = tagger.tag(at: wordRange.lowerBound, unit: .word, scheme: .nameType).0
                    
                    // ML-based scoring adjustments
                    if lexicalClass == .noun {
                        inc *= 2.0  // Nouns are strong interest candidates
                    } else if lexicalClass == .adjective {
                        inc *= 1.5  // Adjectives can indicate preferences
                    } else if lexicalClass == .verb && phrase.hasSuffix("ing") {
                        inc *= 1.8  // Activity verbs (playing, cooking, etc.)
                    }
                    
                    // Named entity boost
                    if let name = nameType, [.personalName, .placeName, .organizationName].contains(name) {
                        inc *= 1.7
                    }
                }
                
                // Activity keyword boost (refined list)
                if Self.activityKeywords.contains(phrase) {
                    inc *= 2.5  // Strong but not overwhelming boost
                }
                
                // POS/NER boost from boosted tokens
                if boostedTokens.contains(phrase) {
                    inc += config.posNerBoostPerToken
                }

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
            
            AppLogger.log(tag: "InterestExtraction", message: "Marked '\(phrase)' as disliked (count: \(cand.dislikedCount)/\(config.maxDislikesBeforePermanentRemoval))")
        }
    }
    
    /// Get the number of times a suggestion has been disliked
    func getDislikedCount(chatId: String, phrase: String) -> Int {
        return queue.sync {
            guard let store = storesByChat[chatId], let cand = store.candidates[phrase] else { return 0 }
            return cand.dislikedCount
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
            // Skip suggestions that have been rejected too many times
            if cand.dislikedCount >= config.maxDislikesBeforePermanentRemoval { continue }
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
                if isSignificantWord(token, in: text) {
                    result.append(token)
                }
            }
            return true
        }
        return result
    }
    
    /// ML-based word significance detection using NL framework and linguistic features
    private func isSignificantWord(_ word: String, in text: String) -> Bool {
        // Basic length filter
        if word.count < 3 { return false }
        
        // PROFANITY FILTER: Check if word contains offensive content using centralized system
        if Profanity.share.doesContainProfanity(word) { return false }
        
        // Use NL framework to get linguistic information
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        
        guard let wordRange = text.range(of: word, options: [.caseInsensitive]) else { return false }
        
        // Get part of speech
        let lexicalClass = tagger.tag(at: wordRange.lowerBound, unit: .word, scheme: .lexicalClass).0
        let nameType = tagger.tag(at: wordRange.lowerBound, unit: .word, scheme: .nameType).0
        
        // Automatically boost content words (nouns, adjectives, proper nouns)
        let significantPOS: Set<NLTag> = [.noun, .adjective, .verb]
        let significantNames: Set<NLTag> = [.personalName, .placeName, .organizationName]
        
        var significanceScore = 0.0
        
        // POS-based scoring
        if let pos = lexicalClass {
            if significantPOS.contains(pos) {
                significanceScore += 2.0
            } else if pos == .pronoun || pos == .preposition || pos == .conjunction || pos == .determiner {
                significanceScore -= 2.0  // Penalize function words
            }
        }
        
        // Named entity bonus
        if let name = nameType, significantNames.contains(name) {
            significanceScore += 1.5
        }
        
        // Activity keyword bonus (keep some high-value terms)
        if Self.activityKeywords.contains(word) {
            significanceScore += 3.0
        }
        
        // Language frequency analysis using NL framework
        let languageScore = calculateLanguageSignificance(word: word, context: text)
        significanceScore += languageScore
        
        // Dynamic threshold based on word characteristics
        let threshold = getDynamicThreshold(for: word, pos: lexicalClass)
        
        return significanceScore > threshold
    }
    
    /// Calculate word significance based on language patterns and frequency
    private func calculateLanguageSignificance(word: String, context: String) -> Double {
        // Use embedding distance and contextual analysis
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(context)
        
        // Simple heuristics that can be enhanced with more ML
        var score = 0.0
        
        // Check against common everyday words
        if Self.commonWordsToSkip.contains(word) {
            score -= 3.0
        }
        
        // Additional pattern-based filtering for common non-interests
        let nonInterestPatterns = [
            "^(what|when|where|why|who|how|which)$",  // Question words
            "^(mother|father|mom|dad|brother|sister|family|parent|child)$",  // Family terms
            "^(friend|friends|people|person|guy|girl|boy|man|woman)$"  // Generic people terms
        ]
        
        for pattern in nonInterestPatterns {
            if word.range(of: pattern, options: .regularExpression) != nil {
                score -= 2.0
                break
            }
        }
        
        // Boost words with meaningful prefixes/suffixes (activities, interests)
        let meaningfulSuffixes = ["ing", "tion", "ness", "ment", "able", "ful"]
        let meaningfulPrefixes = ["un", "re", "pre", "dis", "over", "under"]
        
        for suffix in meaningfulSuffixes {
            if word.hasSuffix(suffix) && word.count > suffix.count + 2 {
                score += 0.5
                break
            }
        }
        
        for prefix in meaningfulPrefixes {
            if word.hasPrefix(prefix) && word.count > prefix.count + 2 {
                score += 0.3
                break
            }
        }
        
        return score
    }
    
    /// Dynamic threshold based on word characteristics
    private func getDynamicThreshold(for word: String, pos: NLTag?) -> Double {
        var threshold = 1.0  // Base threshold
        
        // Lower threshold for nouns (more likely to be interests)
        if pos == .noun {
            threshold = 0.5
        }
        // Higher threshold for common function words
        else if pos == .pronoun || pos == .preposition || pos == .conjunction {
            threshold = 2.5
        }
        
        // Adjust based on word length (longer words often more specific)
        if word.count > 6 {
            threshold -= 0.3
        } else if word.count < 4 {
            threshold += 0.5
        }
        
        return threshold
    }
    
    // MARK: - Profanity Filtering
    // Now using centralized Profanity.share system (Firebase-based) for consistency across the app
    
    /// Check if entire message contains profanity using the centralized Firebase-based system
    private func containsProfanity(_ text: String) -> Bool {
        // Use the same centralized profanity system used throughout the app
        // This uses Firebase-fetched word lists via ProfanityService
        return Profanity.share.doesContainProfanity(text)
    }

    private func boostedTokenSet(for text: String) -> Set<String> {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        let opts: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther, .joinNames]
        var boosted: Set<String> = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: opts) { tag, range in
            guard let lex = tag else { return true }
            let token = String(text[range]).lowercased()
            if Self.commonWordsToSkip.contains(token) { return true }
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



    // MARK: - Common Words to Skip (Minimal list - ML handles most filtering)
    // Keep only the most essential everyday words that ML might miss
    private static let commonWordsToSkip: Set<String> = [
        "the", "a", "an", "and", "or", "but", "if", "then", "of", "to", "for", "with", "by", "from", "as", "at", "in", "on", "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "can", "this", "that", "these", "those", "i", "you", "he", "she", "we", "they", "me", "him", "her", "us", "them", "my", "your", "his", "her", "our", "their"
    ]
    
    // MARK: - Activity/Interest Keywords (Words that likely indicate hobbies, activities, or interests)
    private static let activityKeywords: Set<String> = [
        // Sports and physical activities
        "football","soccer","basketball","tennis","cricket","baseball","volleyball","golf","swimming","running","cycling","hiking","climbing","skiing","snowboarding","surfing","skateboarding","boxing","wrestling","martial","arts","yoga","pilates","gym","fitness","workout","exercise","dance","dancing","ballet","salsa","tango","cheerleading","gymnastics","track","field","marathon","triathlon",
        // Entertainment and media
        "movie","movies","film","films","cinema","theater","theatre","music","song","songs","singing","concert","concerts","band","bands","guitar","piano","drums","violin","instrument","instruments","recording","studio","album","albums","artist","artists","musician","musicians","singer","singers","composer","composers","dancing","performance","performances","show","shows","television","tv","series","documentary","documentaries","anime","manga","comic","comics","books","book","reading","novel","novels","poetry","writing","author","authors","writer","writers","publishing","journalism","photography","photo","photos","picture","pictures","art","arts","painting","drawing","sculpture","gallery","galleries","museum","museums","exhibition","exhibitions",
        // Gaming and technology
        "gaming","games","game","video","computer","console","playstation","xbox","nintendo","steam","mobile","app","apps","application","applications","software","programming","coding","code","developer","development","technology","tech","internet","web","website","websites","online","digital","virtual","reality","vr","ar","artificial","intelligence","ai","machine","learning","data","science","analytics","cybersecurity","security","hacking","blockchain","cryptocurrency","crypto","bitcoin","ethereum",
        // Hobbies and crafts
        "cooking","baking","recipe","recipes","chef","kitchen","food","cuisine","restaurant","restaurants","wine","coffee","tea","brewing","gardening","plants","flowers","garden","gardens","farming","agriculture","crafting","crafts","knitting","sewing","embroidery","woodworking","pottery","ceramics","jewelry","making","diy","building","construction","repair","fixing","collecting","collection","collections","antiques","coins","stamps","cards","trading","model","models","miniatures",
        // Travel and exploration
        "travel","traveling","travelling","trip","trips","vacation","vacations","holiday","holidays","adventure","adventures","exploring","exploration","backpacking","camping","hiking","trekking","mountaineering","sailing","boating","cruise","cruises","flight","flights","airport","airports","hotel","hotels","resort","resorts","beach","beaches","island","islands","mountain","mountains","forest","forests","desert","deserts","lake","lakes","river","rivers","ocean","oceans","city","cities","country","countries","culture","cultures","language","languages","foreign","international","global","world","geography","history","historical","museum","museums","landmark","landmarks",
        // Science and learning
        "science","physics","chemistry","biology","mathematics","math","calculus","algebra","geometry","statistics","research","experiment","experiments","laboratory","lab","academic","academics","education","learning","studying","study","school","college","university","degree","degrees","course","courses","class","classes","lecture","lectures","seminar","seminars","workshop","workshops","training","certification","skill","skills","knowledge","teaching","tutoring","mentoring",
        // Social and community
        "volunteering","volunteer","charity","donation","donations","nonprofit","community","social","networking","meetup","meetups","event","events","party","parties","celebration","celebrations","festival","festivals","conference","conferences","workshop","workshops","club","clubs","group","groups","organization","organizations","team","teams","leadership","management","business","entrepreneur","startup","startups","investing","investment","finance","economics","politics","government","law","legal","justice","advocacy","activism","environment","environmental","sustainability","conservation",
        // Health and wellness
        "health","healthy","wellness","meditation","mindfulness","therapy","counseling","psychology","mental","emotional","spiritual","religion","religious","faith","belief","beliefs","philosophy","philosophical","ethics","moral","values","personal","growth","development","self","improvement","motivation","inspiration","goal","goals","achievement","success","productivity","lifestyle","balance","stress","relaxation","massage","spa","beauty","skincare","makeup","fashion","style","clothing","design","interior","architecture",
        // Popular culture and fandoms
        "marvel","dc","superhero","superheroes","comic","comics","anime","manga","cosplay","gaming","esports","streaming","twitch","youtube","podcast","podcasts","influencer","influencers","celebrity","celebrities","fan","fandom","fandoms","pop","culture","trends","viral","meme","memes","social","media","instagram","facebook","twitter","tiktok","snapchat","discord","reddit",
        // Conversation topics
        "conversation","conversations","talk","talking","discussion","discussions","debate","debates","opinion","opinions","thoughts","thinking","ideas","creativity","brainstorming","storytelling","jokes","humor","comedy","funny","entertainment","interesting","fascinating","curious","wonder","wondering","philosophy","deep","meaningful","intellectual","smart","intelligent","wisdom","advice","guidance","support","help","sharing","connecting","bonding","relationship","relationships","friendship","dating","romance","love"
    ]
}


