import Foundation
import UIKit

class PromptCreator {
    
    func createChatPrompt(
        myProfile: UserCoreDataReplacement,
        otherProfile: UserCoreDataReplacement,
        conversationHistory: String,
        myInterests: [String],
        myStatus: String,
        mood: String,
        similarReply: Bool
    ) -> String {
        
        AppLogger.log(tag: "LOG-APP: PromptCreator", message: "createChatPrompt() creating prompt for conversation")
        
        guard let myName = myProfile.username,
              let myGender = myProfile.gender,
              let otherName = otherProfile.username,
              let otherGender = otherProfile.gender else {
            AppLogger.log(tag: "LOG-APP: PromptCreator", message: "createChatPrompt() missing profile data")
            return ""
        }
        
        var promptBuilder = ""
        
        // Determine pronouns based on gender
        let otherPronoun1 = otherGender.lowercased() == "female" ? "She" : "He"
        let otherPronoun2 = otherGender.lowercased() == "female" ? "Her" : "His"
        
        let myPronoun1 = myGender.lowercased() == "female" ? "She" : "He"
        let myPronoun2 = myGender.lowercased() == "female" ? "Her" : "His"
        
        // Build the prompt following Android structure
        promptBuilder += "You are \(otherName). You are in an adult chat app called ChatHub."
        promptBuilder += generateProfileDescription(for: otherProfile)
        promptBuilder += " You are chatting with \(myName),"
        promptBuilder += generateProfileDescription(for: myProfile, pronoun1: myPronoun1, pronoun2: myPronoun2)
        promptBuilder += "\n\n"
        promptBuilder += "Here is how \(myName) and \(otherName)'s conversation has gone so far:\n"
        
        // Add conversation history
        if !conversationHistory.isEmpty {
            promptBuilder += conversationHistory
        }
        
        promptBuilder += getConversationExample(myProfile: myProfile, otherProfile: otherProfile)
        promptBuilder += "\n\n"
        promptBuilder += "Now reply to \(myName)'s message as you are \(otherName), keep your reply short and \(mood):\n"
        
        // Clean up extra spaces
        let generatedPrompt = promptBuilder.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        
        AppLogger.log(tag: "LOG-APP: PromptCreator", message: "createChatPrompt() generated prompt length: \(generatedPrompt.count)")
        
        return generatedPrompt
    }
    
    private func generateProfileDescription(for profile: UserCoreDataReplacement, pronoun1: String = "", pronoun2: String = "") -> String {
        guard let name = profile.username,
              let gender = profile.gender,
              let country = profile.country else {
            return ""
        }
        
        let actualPronoun1 = pronoun1.isEmpty ? (gender.lowercased() == "female" ? "She" : "He") : pronoun1
        let actualPronoun2 = pronoun2.isEmpty ? (gender.lowercased() == "female" ? "Her" : "His") : pronoun2
        
        var description = " \(actualPronoun1) is a \(gender.lowercased()) from \(country)."
        
        // Add age if available
        if let age = profile.age, !age.isEmpty {
            description += " \(actualPronoun1) is \(age) years old."
        }
        
        // Add language if available
        if let language = profile.language, !language.isEmpty {
            description += " \(actualPronoun1) speaks \(language)."
        }
        
        return description
    }
    
    private func getConversationExample(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement) -> String {
        guard let myName = myProfile.username,
              let otherName = otherProfile.username else {
            return ""
        }
        
        // Basic conversation starter example
        let example = """
        \n\(myName): Hi there! How are you doing today?
        \(otherName): Hello! I'm doing great, thanks for asking. How about you?
        \(myName): I'm good too! What do you like to do for fun?
        """
        
        return example
    }
} 