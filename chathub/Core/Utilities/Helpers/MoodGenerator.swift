import Foundation

/// MoodGenerator provides mood context for AI messages - Android getMood() parity
class MoodGenerator {
    
    static let shared = MoodGenerator()
    
    private init() {}
    
    /// Generates a mood string based on profanity context - Android getMood() equivalent
    /// - Parameter isProfanity: Whether the conversation contains profanity
    /// - Returns: A mood string to add personality context to AI prompts
    func getMood(isProfanity: Bool) -> String {
        AppLogger.log(tag: "LOG-APP: MoodGenerator", message: "getMood() isProfanity: \(isProfanity)")
        
        // Android parity: Exact same mood strings
        let normalMoods = ["angry", "professional", "loyal", "happy"]
        let seductiveMoods = ["sexy", "hot", "seductive", "erotic"]
        
        if isProfanity {
            let randomIndex = Int.random(in: 0..<seductiveMoods.count)
            let selectedMood = seductiveMoods[randomIndex]
            AppLogger.log(tag: "LOG-APP: MoodGenerator", message: "getMood() selected seductive mood: \(selectedMood)")
            return selectedMood
        } else {
            let randomIndex = Int.random(in: 0..<normalMoods.count)
            let selectedMood = normalMoods[randomIndex]
            AppLogger.log(tag: "LOG-APP: MoodGenerator", message: "getMood() selected normal mood: \(selectedMood)")
            return selectedMood
        }
    }
} 