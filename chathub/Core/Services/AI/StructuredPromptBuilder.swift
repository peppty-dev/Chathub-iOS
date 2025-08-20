import Foundation

/// StructuredPromptBuilder builds the prompt in the same shape as Android's PromptCreatorClass
/// Note: iOS uses ONLY curated examples (no training messages, no current conversation block)
class StructuredPromptBuilder {
    
    func buildPrompt(
        myProfile: UserCoreDataReplacement,
        otherProfile: UserCoreDataReplacement,
        myInterests: [String],
        otherInterests: [String],
        curatedExamples: String,
        trainingMessages: String,
        currentConversation: String,
        mood: String
    ) -> String {
        let myName = myProfile.name ?? myProfile.username ?? "You"
        let otherName = otherProfile.name ?? otherProfile.username ?? "Friend"
        
        // Determine pronouns like Android
        let yourGender = otherProfile.gender?.lowercased()
        let myGender = myProfile.gender?.lowercased()
        let yourPronoun1 = yourGender == "female" ? "She" : "He"
        let yourPronoun2 = yourGender == "female" ? "Her" : "His"
        let myPronoun1 = myGender == "female" ? "She" : "He"
        let myPronoun2 = myGender == "female" ? "Her" : "His"

        var promptBuilder = ""
        promptBuilder += "You are \(otherName). You are in an adult chat app called ChatHub."
        promptBuilder += generateYourProfileDescription(profile: otherProfile)
        promptBuilder += " You are chatting with \(myName),"
        promptBuilder += generateProfileDescription(pronoun1: myPronoun1, pronoun2: myPronoun2, profile: myProfile)

        // Light-touch inclusion of interests to nudge AI style without changing Android format
        let myInterestsLine = myInterests.isEmpty ? nil : myInterests.joined(separator: ", ")
        let otherInterestsLine = otherInterests.isEmpty ? nil : otherInterests.joined(separator: ", ")
        if myInterestsLine != nil || otherInterestsLine != nil {
            promptBuilder += " "
            if let otherLine = otherInterestsLine, !otherLine.isEmpty {
                promptBuilder += "\(otherName)'s interests: \(otherLine)."
            }
            if let myLine = myInterestsLine, !myLine.isEmpty {
                promptBuilder += " \(myName)'s interests: \(myLine)."
            }
        }
        promptBuilder += "\n\n"
        promptBuilder += "Here is how \(myName) and \(otherName)'s conversation has gone so far:\n"

        // iOS: include ONLY curated examples
        if !curatedExamples.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptBuilder += curatedExamples
        }

        promptBuilder += "\n\n"
        promptBuilder += "Now reply to \(myName)'s message as you are \(otherName), keep your reply short and \(mood):\n"
        promptBuilder += "\(otherName)'s reply:"

        let generatedPrompt = normalizeMultipleSpaces(promptBuilder)
        return generatedPrompt
    }

    // MARK: - Android-equivalent profile description helpers
    private func generateYourProfileDescription(profile: UserCoreDataReplacement) -> String {
        var descriptionBuilder = ""
        // Build demographic phrase without leaving a standalone gender token
        var hasAge = false
        if let age = profile.age, !age.isEmpty && age.lowercased() != "null" {
            descriptionBuilder += " You are a \(age)-year-old"
            hasAge = true
        }
        if let gender = profile.gender?.lowercased(), !gender.isEmpty && gender != "null" {
            if hasAge {
                descriptionBuilder += " \(gender)"
            } else {
                descriptionBuilder += " You are a \(gender)"
            }
        }

        if isValid(profile.city) {
            appendIfValid(&descriptionBuilder, prefix: " from ", value: profile.city, suffix: ".")
        } else {
            appendIfValid(&descriptionBuilder, prefix: " from ", value: profile.country, suffix: ".")
        }

        appendIfValid(&descriptionBuilder, prefix: " You speak ", value: profile.language, suffix: ".")
        appendIfValid(&descriptionBuilder, prefix: " Your height is ", value: profile.height, suffix: " cm.")
        appendIfValid(&descriptionBuilder, prefix: " Your hobbies are ", value: profile.hobbies?.lowercased(), suffix: ".")
        appendIfValid(&descriptionBuilder, prefix: " Your zodiac sign is ", value: profile.zodiac, suffix: " .")
        appendIfValid(&descriptionBuilder, prefix: " Your snapchat handle is ", value: profile.snapchat, suffix: ".")
        appendIfValid(&descriptionBuilder, prefix: " Your instagram handle is ", value: profile.instagram, suffix: ".")

        appendBooleanField(&descriptionBuilder, value: profile.smokes, prefix: " You ", description: " smoke.")
        appendBooleanField(&descriptionBuilder, value: profile.drinks, prefix: " You ", description: " drink alcohol.")
        appendBooleanField(&descriptionBuilder, value: profile.gym, prefix: " You ", description: " go to gym.")
        appendBooleanField(&descriptionBuilder, value: profile.single, prefix: " You ", description: " are single.")
        appendBooleanField(&descriptionBuilder, value: profile.married, prefix: " You ", description: " are married.")
        appendBooleanField(&descriptionBuilder, value: profile.children, prefix: " You ", description: " have children.")
        appendBooleanField(&descriptionBuilder, value: profile.music, prefix: " You ", description: " enjoy listening to music.")
        appendBooleanField(&descriptionBuilder, value: profile.movies, prefix: " You ", description: " enjoy watching movies.")
        appendBooleanField(&descriptionBuilder, value: profile.travel, prefix: " You ", description: " loves traveling.")
        appendBooleanField(&descriptionBuilder, value: profile.games, prefix: " You ", description: " enjoy playing games.")
        appendBooleanField(&descriptionBuilder, value: profile.voiceAllowed, prefix: " You ", description: " allow Voice communication.")
        appendBooleanField(&descriptionBuilder, value: profile.videoAllowed, prefix: " You ", description: " allow Video communication.")

        appendYourInterest(&descriptionBuilder, profile: profile)
        return descriptionBuilder
    }

    private func generateProfileDescription(pronoun1: String, pronoun2: String, profile: UserCoreDataReplacement) -> String {
        var descriptionBuilder = ""
        // Build demographic phrase without leaving a standalone gender token
        var hasAge = false
        if let age = profile.age, !age.isEmpty && age.lowercased() != "null" {
            descriptionBuilder += " \(pronoun1) is a \(age)-year-old"
            hasAge = true
        }
        if let gender = profile.gender?.lowercased(), !gender.isEmpty && gender != "null" {
            if hasAge {
                descriptionBuilder += " \(gender)"
            } else {
                descriptionBuilder += " \(pronoun1) is a \(gender)"
            }
        }

        if isValid(profile.city) {
            appendIfValid(&descriptionBuilder, prefix: " from ", value: profile.city, suffix: ".")
        } else {
            appendIfValid(&descriptionBuilder, prefix: " from ", value: profile.country, suffix: ".")
        }

        appendIfValid(&descriptionBuilder, prefix: " \(pronoun1) speaks ", value: profile.language, suffix: ".")
        appendIfValid(&descriptionBuilder, prefix: " \(pronoun1) has a height of ", value: profile.height, suffix: " cm.")
        appendIfValid(&descriptionBuilder, prefix: " \(pronoun1) has hobbies that include ", value: profile.hobbies?.lowercased(), suffix: ".")
        appendIfValid(&descriptionBuilder, prefix: " \(pronoun2) zodiac sign is ", value: profile.zodiac, suffix: " .")
        appendIfValid(&descriptionBuilder, prefix: " \(pronoun2) snapchat handle is ", value: profile.snapchat, suffix: ".")
        appendIfValid(&descriptionBuilder, prefix: " \(pronoun2) instagram handle is ", value: profile.instagram, suffix: ".")

        appendBooleanField(&descriptionBuilder, value: profile.smokes, prefix: " \(pronoun1)", description: " smokes.")
        appendBooleanField(&descriptionBuilder, value: profile.drinks, prefix: " \(pronoun1)", description: " drinks alcohol.")
        appendBooleanField(&descriptionBuilder, value: profile.gym, prefix: " \(pronoun1)", description: " goes to the gym.")
        appendBooleanField(&descriptionBuilder, value: profile.single, prefix: " \(pronoun1)", description: " is single.")
        appendBooleanField(&descriptionBuilder, value: profile.married, prefix: " \(pronoun1)", description: " is married.")
        appendBooleanField(&descriptionBuilder, value: profile.children, prefix: " \(pronoun1)", description: " has children.")
        appendBooleanField(&descriptionBuilder, value: profile.music, prefix: " \(pronoun1)", description: " enjoys listening to music.")
        appendBooleanField(&descriptionBuilder, value: profile.movies, prefix: " \(pronoun1)", description: " enjoys watching movies.")
        appendBooleanField(&descriptionBuilder, value: profile.travel, prefix: " \(pronoun1)", description: " loves traveling.")
        appendBooleanField(&descriptionBuilder, value: profile.games, prefix: " \(pronoun1)", description: " enjoys playing games.")
        appendBooleanField(&descriptionBuilder, value: profile.voiceAllowed, prefix: " \(pronoun1)", description: " allows Voice communication.")
        appendBooleanField(&descriptionBuilder, value: profile.videoAllowed, prefix: " \(pronoun1)", description: " allows Video communication.")

        appendInterest(&descriptionBuilder, profile: profile, pronoun: pronoun1)
        return descriptionBuilder
    }

    // MARK: - Small utilities mirroring Android helpers
    private func appendIfValid(_ builder: inout String, prefix: String, value: String?, suffix: String) {
        if let value = value, !value.isEmpty && value.lowercased() != "null" {
            builder += prefix + value + suffix
        }
    }
    
    private func isValid(_ value: String?) -> Bool {
        return value != nil && !value!.isEmpty && value!.lowercased() != "null"
    }
    
    private func appendBooleanField(_ builder: inout String, value: String?, prefix: String, description: String) {
        if value?.lowercased() == "yes" {
            builder += prefix + description
        }
    }
    
    private func appendYourInterest(_ builder: inout String, profile: UserCoreDataReplacement) {
        let likesMen = profile.likesMen?.lowercased() == "yes"
        let likesWomen = profile.likesWomen?.lowercased() == "yes"
        if likesMen || likesWomen {
            builder += " You are interested in "
            if likesMen { builder += "men" }
            if likesMen && likesWomen { builder += " and " }
            if likesWomen { builder += "women" }
            builder += "."
        }
    }
    
    private func appendInterest(_ builder: inout String, profile: UserCoreDataReplacement, pronoun: String) {
        let likesMen = profile.likesMen?.lowercased() == "yes"
        let likesWomen = profile.likesWomen?.lowercased() == "yes"
        if likesMen || likesWomen {
            builder += " \(pronoun) is interested in "
            if likesMen { builder += "men" }
            if likesMen && likesWomen { builder += " and " }
            if likesWomen { builder += "women" }
            builder += "."
        }
    }

    private func normalizeMultipleSpaces(_ text: String) -> String {
        // Collapse multiple spaces into one, Android-style
        return text.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
    }
}


