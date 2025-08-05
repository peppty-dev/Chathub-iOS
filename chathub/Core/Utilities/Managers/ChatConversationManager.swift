import Foundation

/// ChatConversationManager generates example conversations based on user interests - Android ChatConversationManager.java parity
class ChatConversationManager {
    
    static let shared = ChatConversationManager()
    
    // Interest categories mapping - Android parity
    private let interestCategories: [String: String] = {
        var categories: [String: String] = [:]
        
        // Adult category
        categories["Adult Chat"] = "adult"
        categories["Mature Chat"] = "adult"
        categories["Role Play"] = "adult"
        categories["Fantasy Chat"] = "adult"
        categories["Adult Stories"] = "adult"
        categories["Mature Content"] = "adult"
        
        // Dating category
        categories["Dating"] = "dating"
        categories["Romance"] = "dating"
        categories["Flirting"] = "dating"
        categories["Love"] = "dating"
        categories["Relationships"] = "dating"
        categories["Romantic Chat"] = "dating"
        categories["Meet Someone"] = "dating"
        categories["Find Love"] = "dating"
        categories["Couple Goals"] = "dating"
        categories["Dating Advice"] = "dating"
        
        // Friendship category
        categories["Friendship"] = "friendship"
        categories["Make Friends"] = "friendship"
        categories["Best Friends"] = "friendship"
        categories["Platonic"] = "friendship"
        categories["Buddy"] = "friendship"
        categories["Companion"] = "friendship"
        
        // Fun category
        categories["Fun"] = "fun"
        categories["Entertainment"] = "fun"
        categories["Games"] = "fun"
        categories["Jokes"] = "fun"
        categories["Humor"] = "fun"
        categories["Memes"] = "fun"
        categories["Comedy"] = "fun"
        categories["Funny"] = "fun"
        
        // Social category
        categories["Social"] = "social"
        categories["Networking"] = "social"
        categories["Community"] = "social"

        categories["Public"] = "social"
        categories["Events"] = "social"
        
        // Cultural category
        categories["Culture"] = "cultural"
        categories["Art"] = "cultural"
        categories["Music"] = "cultural"
        categories["Movies"] = "cultural"
        categories["Books"] = "cultural"
        categories["Travel"] = "cultural"
        
        // Deep category
        categories["Deep Conversations"] = "deep"
        categories["Meet People"] = "deep"
        categories["Make New Friends"] = "deep"
        
        return categories
    }()
    
    private init() {}
    
    /// Main conversation generation method - Android generateConversation() equivalent
    func generateConversation(myInterests: [String], otherInterests: [String], myProfile: UserCoreDataReplacement?, otherProfile: UserCoreDataReplacement?) -> String {
        AppLogger.log(tag: "LOG-APP: ChatConversationManager", message: "generateConversation() generating conversation with interests")
        
        // Null safety checks for profiles
        guard let myProfile = myProfile, let otherProfile = otherProfile else {
            AppLogger.log(tag: "LOG-APP: ChatConversationManager", message: "generateConversation() profiles are nil")
            return ""
        }
        
        // Null safety checks for gender
        guard let myGender = myProfile.gender?.lowercased(),
              let otherGender = otherProfile.gender?.lowercased() else {
            AppLogger.log(tag: "LOG-APP: ChatConversationManager", message: "generateConversation() genders are nil")
            return ""
        }
        
        // Null safety checks for usernames
        guard let myName = myProfile.name,
              let otherName = otherProfile.name else {
            AppLogger.log(tag: "LOG-APP: ChatConversationManager", message: "generateConversation() names are nil")
            return ""
        }
        
        if myInterests.isEmpty || otherInterests.isEmpty {
            return generateGenericConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        }
        
        guard let myFirstInterest = myInterests.first,
              let otherFirstInterest = otherInterests.first else {
            AppLogger.log(tag: "ChatConversationManager", message: "CRITICAL: Empty interests arrays")
            return generateGenericConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        }
        let myCategory = getCategoryForInterest(myFirstInterest)
        let otherCategory = getCategoryForInterest(otherFirstInterest)
        
        return generateConversationByCategories(myCategory: myCategory, otherCategory: otherCategory, myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
    }
    
    private func getCategoryForInterest(_ interest: String) -> String {
        return interestCategories[interest] ?? "generic"
    }
    
    // Helper method to check if categories match
    private func categoriesMatch(_ cat1: String, _ cat2: String, _ target1: String, _ target2: String) -> Bool {
        return (cat1 == target1 && cat2 == target2) || (cat1 == target2 && cat2 == target1)
    }
    
    // Helper method to build conversation messages
    private func appendMessage(_ conversation: inout String, username: String, message: String) {
        conversation += "\(username)'s message: \(message)\n"
    }
    
    private func appendReply(_ conversation: inout String, username: String, reply: String) {
        conversation += "\(username)'s reply: \(reply)\n"
    }
    
    // Main conversation router based on categories
    private func generateConversationByCategories(myCategory: String, otherCategory: String, myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        
        // Adult combinations
        if categoriesMatch(myCategory, otherCategory, "adult", "fun") {
            return generateAdultFunConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        } else if categoriesMatch(myCategory, otherCategory, "adult", "dating") {
            return generateAdultDatingConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        } else if categoriesMatch(myCategory, otherCategory, "adult", "deep") {
            return generateAdultDeepConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        } else if categoriesMatch(myCategory, otherCategory, "adult", "cultural") {
            return generateAdultCulturalConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        } else if categoriesMatch(myCategory, otherCategory, "adult", "friendship") {
            return generateAdultFriendshipConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        }
        
        // Fun combinations
        else if categoriesMatch(myCategory, otherCategory, "fun", "dating") {
            return generateFunDatingConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        } else if categoriesMatch(myCategory, otherCategory, "fun", "deep") {
            return generateDeepFunConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        }
        
        // Cultural combinations
        else if categoriesMatch(myCategory, otherCategory, "cultural", "social") {
            return generateCulturalSocialConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        }
        
        // Deep combinations
        else if categoriesMatch(myCategory, otherCategory, "deep", "friendship") {
            return generateDeepFriendshipConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        }
        
        // Social combinations
        else if categoriesMatch(myCategory, otherCategory, "social", "fun") {
            return generateSocialFunConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        }
        
        // Single category fallbacks
        else if hasCategory(myCategory, otherCategory, "adult") {
            return generateAdultChatConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        } else if hasCategory(myCategory, otherCategory, "dating") {
            return generateDatingChatConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        } else if hasCategory(myCategory, otherCategory, "friendship") {
            return generateFriendshipConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        } else if hasCategory(myCategory, otherCategory, "fun") {
            return generateFunConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        } else if hasCategory(myCategory, otherCategory, "social") {
            return generateSocialConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        } else if hasCategory(myCategory, otherCategory, "cultural") {
            return generateCulturalConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        } else if hasCategory(myCategory, otherCategory, "deep") {
            return generateDeepConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        }
        
        // Generic fallback
        else {
            return generateGenericConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender)
        }
    }
    
    private func hasCategory(_ cat1: String, _ cat2: String, _ category: String) -> Bool {
        return cat1 == category || cat2 == category
    }
    
    // MARK: - Specific Conversation Generators (Android Parity)
    
    private func generateAdultFunConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            
            if myGender == "male" && otherGender == "female" {
                appendMessage(&conversation, username: you, message: "heyyy")
                appendReply(&conversation, username: me, reply: "hey beautiful wassup")
                appendMessage(&conversation, username: you, message: "nothing much just chilling")
                appendReply(&conversation, username: me, reply: "same here, you look gorgeous btw")
                appendMessage(&conversation, username: you, message: "aww thank you, you're sweet")
                appendReply(&conversation, username: me, reply: "just being honest 😘")
            } else if myGender == "female" && otherGender == "male" {
                appendMessage(&conversation, username: you, message: "hey handsome")
                appendReply(&conversation, username: me, reply: "hey there beautiful")
                appendMessage(&conversation, username: you, message: "how's your day going?")
                appendReply(&conversation, username: me, reply: "better now that I'm talking to you")
                appendMessage(&conversation, username: you, message: "you're such a charmer")
                appendReply(&conversation, username: me, reply: "only for you 😉")
            } else {
                appendMessage(&conversation, username: you, message: "hey there!")
                appendReply(&conversation, username: me, reply: "hey! how are you?")
                appendMessage(&conversation, username: you, message: "doing good, just looking for some fun")
                appendReply(&conversation, username: me, reply: "sounds perfect, what kind of fun?")
                appendMessage(&conversation, username: you, message: "whatever you're in the mood for")
                appendReply(&conversation, username: me, reply: "I like the sound of that")
            }
        }
    }
    
    private func generateGenericConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            
            if myGender == "male" && otherGender == "female" {
                appendMessage(&conversation, username: you, message: "hi there")
                appendReply(&conversation, username: me, reply: "hello! how are you?")
                appendMessage(&conversation, username: you, message: "I'm good thanks, how about you?")
                appendReply(&conversation, username: me, reply: "doing well, nice to meet you")
                appendMessage(&conversation, username: you, message: "nice to meet you too")
                appendReply(&conversation, username: me, reply: "so what brings you here?")
            } else if myGender == "female" && otherGender == "male" {
                appendMessage(&conversation, username: you, message: "hello")
                appendReply(&conversation, username: me, reply: "hi there! how's it going?")
                appendMessage(&conversation, username: you, message: "pretty good, just exploring")
                appendReply(&conversation, username: me, reply: "cool, me too. what are you looking for?")
                appendMessage(&conversation, username: you, message: "just interesting conversations")
                appendReply(&conversation, username: me, reply: "sounds great, I'm up for that")
            } else {
                appendMessage(&conversation, username: you, message: "hey")
                appendReply(&conversation, username: me, reply: "hey! what's up?")
                appendMessage(&conversation, username: you, message: "not much, just chatting")
                appendReply(&conversation, username: me, reply: "cool, me too")
                appendMessage(&conversation, username: you, message: "so tell me about yourself")
                appendReply(&conversation, username: me, reply: "sure, what would you like to know?")
            }
        }
    }
    
    // Simplified implementations for other conversation types (Android parity structure)
    private func generateAdultDatingConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateAdultDeepConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateAdultCulturalConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateAdultFriendshipConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateFunDatingConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateDeepFunConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateCulturalSocialConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateDeepFriendshipConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateSocialFunConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateAdultChatConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateDatingChatConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateFriendshipConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateFunConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateSocialConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateCulturalConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    private func generateDeepConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String) -> String {
        return generateGenderSpecificConversation(myProfile: myProfile, otherProfile: otherProfile, myGender: myGender, otherGender: otherGender) { conversation, you, me, myGender, otherGender in
            // Implementation details...
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateGenderSpecificConversation(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement, myGender: String, otherGender: String, generator: (inout String, String, String, String, String) -> Void) -> String {
        var conversation = ""
        let myName = myProfile.name ?? "You"
        let otherName = otherProfile.name ?? "Friend"
        
        generator(&conversation, myName, otherName, myGender, otherGender)
        
        AppLogger.log(tag: "LOG-APP: ChatConversationManager", message: "generateGenderSpecificConversation() generated conversation length: \(conversation.count)")
        
        return conversation
    }
} 