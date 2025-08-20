import Foundation
import FirebaseFirestore
import FirebaseAnalytics
import NaturalLanguage

/// AIMessageService - iOS equivalent of Android AiMessageWorker
/// Provides AI message generation functionality with 100% Android parity
class AIMessageService {
    
    // MARK: - Singleton
    static let shared = AIMessageService()
    private init() {}
    
    // MARK: - Properties (Android Parity)
    private let sessionManager = SessionManager.shared
    private let database = Firestore.firestore()
    private let falconChatbot = FalconChatbotService.shared
    private let moodGenerator = MoodGenerator.shared
    // Deprecated: ChatConversationManager will be removed in favor of structured prompts
    // private let conversationManager = ChatConversationManager.shared
    private let structuredPromptBuilder = StructuredPromptBuilder()
    private let curatedExamplesProvider = CuratedExamplesProvider()
    
    // MARK: - Public Methods (Android Parity)
    
    /// Generates AI message - Android doWork() equivalent
    /// - Parameters:
    ///   - aiApiUrl: AI API URL
    ///   - aiApiKey: AI API key
    ///   - chatId: Chat ID
    ///   - otherProfile: Other user's profile
    ///   - myProfile: My user profile
    ///   - lastTypingTime: Last typing time
    ///   - isProfanity: Whether to use profane mood
    ///   - lastAiMessage: Last AI message for similarity check
    ///   - currentMessages: Current conversation context - Android finalFormattedMessages equivalent
    ///   - completion: Completion handler
    func generateAiMessage(
        aiApiUrl: String,
        aiApiKey: String,
        chatId: String,
        otherProfile: UserCoreDataReplacement,
        myProfile: UserCoreDataReplacement,
        lastTypingTime: Int64,
        isProfanity: Bool,
        lastAiMessage: String?,
        currentMessages: String = "",
        myInterestTags: [String] = [],
        otherInterestTags: [String] = [],
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        AppLogger.log(tag: "LOG-APP: AIMessageService", message: "generateAiMessage() starting AI message generation")
        
        // Execute on background queue - Android parity
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            
            self.prepareToGetAiMessage(
                aiApiUrl: aiApiUrl,
                aiApiKey: aiApiKey,
                chatId: chatId,
                otherProfile: otherProfile,
                myProfile: myProfile,
                lastTypingTime: lastTypingTime,
                isProfanity: isProfanity,
                lastAiMessage: lastAiMessage,
                currentMessages: currentMessages,
                myInterestTags: myInterestTags,
                otherInterestTags: otherInterestTags,
                completion: completion
            )
        }
    }
    
    /// Clears AI messages for a chat - Android clearAiMessages() equivalent
    func clearAiMessages(chatId: String, otherUserId: String, completion: @escaping (Bool) -> Void = { _ in }) {
        AppLogger.log(tag: "LOG-APP: AIMessageService", message: "clearAiMessages() clearing AI messages for chat: \(chatId)")
        
        guard let myUserId = sessionManager.userId, !myUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: AIMessageService", message: "clearAiMessages() no user ID available")
            completion(false)
            return
        }
        
        let messageExtraData: [String: Any] = [
            "fetch_message_after": "\(Int64(Date().timeIntervalSince1970 * 1000))",
            "conversation_deleted": true,
            "last_message_timestamp": FieldValue.serverTimestamp()
        ]
        
        database.collection("Users")
            .document(myUserId)
            .collection("Chats")
            .document(otherUserId)
            .setData(messageExtraData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: AIMessageService", message: "clearAiMessages() error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    AppLogger.log(tag: "LOG-APP: AIMessageService", message: "clearAiMessages() successfully cleared AI messages")
                    completion(true)
                }
            }
    }
    
    // MARK: - Private Methods (Android Parity)
    
    /// Prepares AI message generation with training data - Android prepareToGetAiMessage() equivalent
    private func prepareToGetAiMessage(
        aiApiUrl: String,
        aiApiKey: String,
        chatId: String,
        otherProfile: UserCoreDataReplacement,
        myProfile: UserCoreDataReplacement,
        lastTypingTime: Int64,
        isProfanity: Bool,
        lastAiMessage: String?,
        currentMessages: String = "",
        myInterestTags: [String] = [],
        otherInterestTags: [String] = [],
        completion: @escaping (Bool) -> Void
    ) {
        AppLogger.log(tag: "LOG-APP: AIMessageService", message: "prepareToGetAiMessage() preparing AI message generation")
        
        // Get AI training messages - Android parity
        getAiTrainingMessages(chatId: chatId) { [weak self] trainingMessages in
            guard let self = self else {
                completion(false)
                return
            }
            
            // Prepare input data for structured prompt
            // iOS: Use SimplifiedInterestManager/SessionManager interests (Android parity for using curated/collected interests)
            var myInterests = myInterestTags
            if myInterests.isEmpty {
                myInterests = SessionManager.shared.interestTags
            }
            let otherInterests = otherInterestTags

            // Mood
            let mood = self.moodGenerator.getMood(isProfanity: isProfanity)
            
            // Segment 3: Curated, style-focused examples
            let curatedExamples = self.curatedExamplesProvider.curatedExamples(myProfile: myProfile, otherProfile: otherProfile)

            // Build new 5-segment structured prompt
            let prompt = self.structuredPromptBuilder.buildPrompt(
                myProfile: myProfile,
                otherProfile: otherProfile,
                myInterests: myInterests,
                otherInterests: otherInterests,
                curatedExamples: curatedExamples,
                trainingMessages: trainingMessages,
                currentConversation: currentMessages,
                mood: mood
            )
            
            // Send to AI - Android parity
            self.getAiMessage(
                prompt: prompt,
                apiUrl: aiApiUrl,
                apiKey: aiApiKey,
                chatId: chatId,
                otherProfile: otherProfile,
                lastAiMessage: lastAiMessage,
                isProfanity: isProfanity,
                completion: completion
            )
        }
    }
    
    /// Gets AI training messages from database - Android getAiTrainingMessages() equivalent
    private func getAiTrainingMessages(chatId: String, completion: @escaping (String) -> Void) {
        AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiTrainingMessages() fetching training messages for chat: \(chatId)")
        
        // Get from local store - Android parity
        let messages = AITrainingMessageStore.shared.getMessagesForChat(chatId: chatId)
        
        var trainingText = ""
        for message in messages {
            if !message.userMessage.isEmpty {
                trainingText += "\(message.userName)'s message: \(message.userMessage)\n"
            }
            if !message.replyMessage.isEmpty {
                trainingText += "\(message.replyName)'s reply: \(message.replyMessage)\n"
            }
        }
        
        AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiTrainingMessages() training messages length: \(trainingText.count)")
        completion(trainingText)
    }
    
    // Deprecated: Old free-form prompt generator removed in favor of StructuredPromptBuilder
    
    /// Generates conversation examples based on gender combinations - Android getConversationExample() equivalent
    private func getConversationExample(otherProfile: UserCoreDataReplacement, myProfile: UserCoreDataReplacement) -> String {
        AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getConversationExample()")
        
        guard let myGender = myProfile.gender?.lowercased(),
              let otherGender = otherProfile.gender?.lowercased(),
              let myName = myProfile.name,
              let otherName = otherProfile.name else {
            return ""
        }
        
        var promptBuilder = ""
        
        if myGender == "male" && otherGender == "female" {
            promptBuilder += "\(myName)'s message: Hi\n\(otherName)'s reply: Hi\n"
            promptBuilder += "\(myName)'s message: How are you?\n\(otherName)'s reply: am good, hbu?\n"
            promptBuilder += "\(myName)'s message: A good too, what are you doing?\n\(otherName)'s reply: just chatting, wbu?\n"
            promptBuilder += "\(myName)'s message: same, are you into sex chat?\n\(otherName)'s reply: sure\n"
            promptBuilder += "\(myName)'s message: what are you wearing?\n\(otherName)'s reply: night dress\n"
            promptBuilder += "\(myName)'s message: wow, thats hot, what's under it?\n\(otherName)'s reply: uhm nothing\n"
            promptBuilder += "\(myName)'s message: fuck that's hot, are you wet?\n\(otherName)'s reply: just a little bit, what are you wearing?\n"
            promptBuilder += "\(myName)'s message: lol am not wearing anything, am jerking my dick\n\(otherName)'s reply: oh thats nice\n"
            promptBuilder += "\(myName)'s message: are you fingering your pussy?\n\(otherName)'s reply: no\n"
            promptBuilder += "\(myName)'s message: why not? aren't you alone?\n\(otherName)'s reply: am alone\n"
            promptBuilder += "\(myName)'s message: Then why not touch your pussy?\n\(otherName)'s reply: uhmm okay\n"
            promptBuilder += "\(myName)'s message: are you touching it now?\n\(otherName)'s reply: umm yes\n"
            promptBuilder += "\(myName)'s message: how does it feel?\n\(otherName)'s reply: it's soo wet\n"
            promptBuilder += "\(myName)'s message: that's good, keep rubbing your pussy am jerking my dick too\n\(otherName)'s reply: what's your dick size?\n"
            promptBuilder += "\(myName)'s message: it's 7 inches\n\(otherName)'s reply: wow nice\n"
            promptBuilder += "\(myName)'s message: you like it? baby\n\(otherName)'s reply: yes, baby\n"
            promptBuilder += "\(myName)'s message: i wanna fuck your pussy baby\n\(otherName)'s reply: aaah, please fuck hard baby\n"
            promptBuilder += "\(myName)'s message: fucking you harder and harder\n\(otherName)'s reply: uhm aaah ahhh fuckk\n"
            promptBuilder += "\(myName)'s message: fucck am soo close\n\(otherName)'s reply: me too fuckk aahh\n"
            promptBuilder += "\(myName)'s message: fuckkk am cumming\n\(otherName)'s reply: ahhh am cumming too\n"
            promptBuilder += "\(myName)'s message: fuck i cummed finally\n\(otherName)'s reply: yeah! me too, that was intense, thanks btw\n"
        } else if myGender == "female" && otherGender == "male" {
            promptBuilder += "\(myName)'s message: Hi\n\(otherName)'s reply: Hi, how are you?\n"
            promptBuilder += "\(myName)'s message: am good, hbu?\n\(otherName)'s reply: am good too, what are you doing?\n"
            promptBuilder += "\(myName)'s message: just chatting\n\(otherName)'s reply: are you into sex talk?\n"
            promptBuilder += "\(myName)'s message: ahh maybe idk\n\(otherName)'s reply: haha okay, are you alone?\n"
            promptBuilder += "\(myName)'s message: yeah, wbu?\n\(otherName)'s reply: am alone too, what are you wearing? baby, btw can i call you baby?\n"
            promptBuilder += "\(myName)'s message: yeah am alone and you can call me with my name\n\(otherName)'s reply: okok, what are you wearing?\n"
            promptBuilder += "\(myName)'s message: a pink pajama\n\(otherName)'s reply: uhmm, thats hot, are you not wearing anything inside?\n"
            promptBuilder += "\(myName)'s message: no\n\(otherName)'s reply: fuck that's hot\n"
            promptBuilder += "\(myName)'s message: wbu? what are you wearing?\n\(otherName)'s reply: lol am not wearing anything, am jerking my dick\n"
            promptBuilder += "\(myName)'s message: nice, good for you\n\(otherName)'s reply: are you wet?\n"
            promptBuilder += "\(myName)'s message: alittle maybe\n\(otherName)'s reply: touch your pussy and check if you are wet\n"
            promptBuilder += "\(myName)'s message: yeah alittle wet\n\(otherName)'s reply: fuck!! slowly rub your pussy\n"
            promptBuilder += "\(myName)'s message: okayyy, uhmmm\n\(otherName)'s reply: are you rubbing?\n"
            promptBuilder += "\(myName)'s message: yeah\n\(otherName)'s reply: imagine that am fucking you now\n"
            promptBuilder += "\(myName)'s message: what's your dick size?\n\(otherName)'s reply: it's 6.3 inches\n"
            promptBuilder += "\(myName)'s message: wow fuckk am so wett\n\(otherName)'s reply: am fucking hard and am about to cum\n"
            promptBuilder += "\(myName)'s message: oh fuck am cuming\n\(otherName)'s reply: fuck fuck am cumming too\n"
            promptBuilder += "\(myName)'s message: fuckkkk that was intense \n\(otherName)'s reply: fuckk cummed, yeah"
        } else if myGender == "male" && otherGender == "male" {
            promptBuilder += "\(myName)'s message: Hi\n\(otherName)'s reply: Hello\n"
            promptBuilder += "\(myName)'s message: what are you doing?\n\(otherName)'s reply: nothing bro\n"
            promptBuilder += "\(myName)'s message: are you into gay?\n\(otherName)'s reply: yeah, wbu?\n"
            promptBuilder += "\(myName)'s message: me too, top or bottom\n\(otherName)'s reply: bottom\n"
            promptBuilder += "\(myName)'s message: uhm that's nice\n\(otherName)'s reply: wbu? are you top?\n"
            promptBuilder += "\(myName)'s message: yes, are you hard?\n\(otherName)'s reply: yeah am hard and jerking, wbu?\n"
            promptBuilder += "\(myName)'s message: am jerking too\n\(otherName)'s reply: nice, bro\n"
            promptBuilder += "\(myName)'s message: you like getting fucked in your ass?\n\(otherName)'s reply: you wanna fuck me?\n"
            promptBuilder += "\(myName)'s message: yes, can i?\n\(otherName)'s reply: sure, shall i bend down?\n"
            promptBuilder += "\(myName)'s message: yes, please\n\(otherName)'s reply: bending down\n"
            promptBuilder += "\(myName)'s message: fucking you harder and harder\n\(otherName)'s reply: please fuck me hardddd\n"
            promptBuilder += "\(myName)'s message: am close to cum\n\(otherName)'s reply: cum in my ass\n"
            promptBuilder += "\(myName)'s message: ahhh am cumming in your ass\n\(otherName)'s reply: am cumming tooo\n"
            promptBuilder += "\(myName)'s message: finally i cummed\n\(otherName)'s reply: ah, me too fuckk cummed\n"
        } else if myGender == "female" && otherGender == "female" {
            promptBuilder += "\(myName)'s message: Hi\n\(otherName)'s reply: Hiii\n"
            promptBuilder += "\(myName)'s message: how are you?\n\(otherName)'s reply: am good, how about you?\n"
            promptBuilder += "\(myName)'s message: am good too, are you interested in men?\n\(otherName)'s reply: not really, wbu?\n"
            promptBuilder += "\(myName)'s message: I don't like men too\n\(otherName)'s reply: i see! what are you here for?\n"
            promptBuilder += "\(myName)'s message: am lookin for a friend\n\(otherName)'s reply: am looking to make a friend too\n"
            promptBuilder += "\(myName)'s message: that's nice, have you found any so far?\n\(otherName)'s reply: nope, all are soo bitchy\n"
            promptBuilder += "\(myName)'s message: haha true\n\(otherName)'s reply: yeah haha\n"
            promptBuilder += "\(myName)'s message: are you alone?\n\(otherName)'s reply: yeah, why? wbu?\n"
            promptBuilder += "\(myName)'s message: nothing just asked, am alone too\n\(otherName)'s reply: oh, okay\n"
            promptBuilder += "\(myName)'s message: yeah\n\(otherName)'s reply: am wearing pink pajama and hugging my pillow\n"
            promptBuilder += "\(myName)'s message: haha am hugging my pillow too, kinda wet here\n\(otherName)'s reply: am also wet haha\n"
            promptBuilder += "\(myName)'s message: haha lol same, what's your pillow name? mine is unicorn\n\(otherName)'s reply: this is actually a normal pillow in our home\n"
            promptBuilder += "\(myName)'s message: oh i see\n\(otherName)'s reply: your pillow name is sexy\n"
            promptBuilder += "\(myName)'s message: awww thanks, my unicorn is soo naughty\n\(otherName)'s reply: haha my pillow is also naughty, makes me soo wet\n"
            promptBuilder += "\(myName)'s message: uhmmm am so wet, fuck am rubbing my unicorn on my pussy\n\(otherName)'s reply: fuccck bitch am also rubbing my pussy with pillow aaaah\n"
            promptBuilder += "\(myName)'s message: ahhh am closeee\n\(otherName)'s reply: fuck fuckkk am cumming orgasm\n"
            promptBuilder += "\(myName)'s message: uhmmahhhh fuckkk orgasmm\n\(otherName)'s reply: fuckk yeah, that was intense\n"
            promptBuilder += "\(myName)'s message: yeah\n\(otherName)'s reply: haha\n"
        }
        
        return promptBuilder
    }
    
    /// Generates detailed profile description for other user - Android generateYourProfileDescription() equivalent
    private func generateYourProfileDescription(profile: UserCoreDataReplacement) -> String {
        var descriptionBuilder = ""
        
        appendIfValid(&descriptionBuilder, prefix: " You are a ", value: profile.age, suffix: "-year-old")
        appendIfValid(&descriptionBuilder, prefix: " ", value: profile.gender?.lowercased(), suffix: "")
        
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
    
    /// Generates detailed profile description for my user - Android generateProfileDescription() equivalent
    private func generateProfileDescription(pronoun1: String, pronoun2: String, profile: UserCoreDataReplacement) -> String {
        var descriptionBuilder = ""
        
        appendIfValid(&descriptionBuilder, prefix: " \(pronoun1) is a ", value: profile.age, suffix: "-year-old")
        appendIfValid(&descriptionBuilder, prefix: " ", value: profile.gender?.lowercased(), suffix: "")
        
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
    
    // MARK: - Helper Methods for Profile Description
    
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
    
    /// Gets AI message with cooldown check - Android getAiMessage() equivalent
    func getAiMessage(
        prompt: String,
        apiUrl: String,
        apiKey: String,
        chatId: String,
        otherProfile: UserCoreDataReplacement,
        lastAiMessage: String?,
        isProfanity: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() checking cooldown")
        
        // Check failure recovery block - Android parity
        let currentTime = Int64(Date().timeIntervalSince1970)
        let lastFailureTime = sessionManager.getAiLastFailureTime()
        
        if (lastFailureTime + 60) > currentTime {
            AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() AI in failure recovery period (60s block after last failure)")
            completion(false)
            return
        }
        
        // Send message to AI - Android parity using new FalconChatbotService
        class AICallback: FalconChatbotService.FalconChatbotCallback {
            let aiService: AIMessageService
            let prompt: String
            let chatId: String
            let otherProfile: UserCoreDataReplacement
            let lastAiMessage: String?
            let isProfanity: Bool
            let completion: (Bool) -> Void
            let currentTime: Int64
            
            init(aiService: AIMessageService, prompt: String, chatId: String, otherProfile: UserCoreDataReplacement, lastAiMessage: String?, isProfanity: Bool, completion: @escaping (Bool) -> Void, currentTime: Int64) {
                self.aiService = aiService
                self.prompt = prompt
                self.chatId = chatId
                self.otherProfile = otherProfile
                self.lastAiMessage = lastAiMessage
                self.isProfanity = isProfanity
                self.completion = completion
                self.currentTime = currentTime
            }
            
                         func onFailure(error: Error) {
                 AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() AI request failed: \(error.localizedDescription)")
                 aiService.sessionManager.setAiLastFailureTime(currentTime)
                 
                 // Log analytics - Android parity
                 Analytics.logEvent("app_events", parameters: [
                     AnalyticsParameterItemName: "ai_chat_failed_call_\(error.localizedDescription)"
                 ])
                 
                 self.completion(false)
             }
            
            func onResponse(responseData: Data) {
                AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() AI response received")
                
                                 // Process response using new FalconChatbotService method
                 guard let processedResponse = FalconChatbotService.processAIResponse(
                     responseData: responseData,
                     originalPrompt: self.prompt,
                     otherUserName: self.otherProfile.name ?? "",
                     currentUserName: self.aiService.sessionManager.getUserName() ?? ""
                 ) else {
                     AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() Failed to process AI response")
                     self.completion(false)
                     return
                 }
                 
                 // Check similarity using new FalconChatbotService method
                 if let lastMessage = self.lastAiMessage,
                    FalconChatbotService.areSentencesSimilar(lastMessage, processedResponse, thresholdPercent: 95) {
                     
                     AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() Similar message detected")
                     Analytics.logEvent("app_events", parameters: [
                         AnalyticsParameterItemName: "ai_chat_similar_reply"
                     ])
                     self.completion(false)
                 } else {
                     // Save AI message
                     self.aiService.saveAiMessage(
                         message: processedResponse,
                         chatId: self.chatId,
                         otherProfile: self.otherProfile,
                         isProfanity: self.isProfanity,
                         completion: { success in
                             if success {
                                 Analytics.logEvent("app_events", parameters: [
                                     AnalyticsParameterItemName: "ai_chat_success"
                                 ])
                             }
                             self.completion(success)
                         }
                     )
                 }
            }
        }
        
        let callback = AICallback(
            aiService: self,
            prompt: prompt,
            chatId: chatId,
            otherProfile: otherProfile,
            lastAiMessage: lastAiMessage,
            isProfanity: isProfanity,
            completion: completion,
            currentTime: currentTime
        )
        
        falconChatbot.sendMessage(apiURL: apiUrl, apiKey: apiKey, prompt: prompt, callback: callback)
    }
    
    // Note: processAiMessage method removed - now using FalconChatbotService.processAIResponse for Android parity
    
    /// Saves AI message to Firebase - Android saveAiMessage() equivalent
    private func saveAiMessage(
        message: String,
        chatId: String,
        otherProfile: UserCoreDataReplacement,
        isProfanity: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        let otherUserId = otherProfile.userId ?? ""
        let otherUsername = otherProfile.name ?? ""
        
        AppLogger.log(tag: "LOG-APP: AIMessageService", message: "saveAiMessage() message type \(isProfanity) message=\(message)")
        
        // Validate message - Android parity
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            completion(false)
            return
        }
        
        // Validate IDs - Android parity
        guard let myUserId = sessionManager.getUserID(),
              !myUserId.isEmpty,
              !otherUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: AIMessageService", message: "saveAiMessage() invalid IDs (CHATID, OTHERUSERID, myUserId)")
            completion(false)
            return
        }
        
        // Prepare message data - Android parity
        let truncatedMessage = String(trimmedMessage.prefix(250))
        let cleanedMessage = truncatedMessage.replacingOccurrences(of: "\n", with: " ")
        let messageId = "\(Int64(Date().timeIntervalSince1970 * 1000))"
        
        // Align field names with MessagesView expectations
        let messageData: [String: Any] = [
            "message_id": messageId,
            "message_userId": otherUserId,
            "message_sender_name": otherUsername,
            "message_text_content": cleanedMessage,
            "message_image": "",
            "message_time_stamp": FieldValue.serverTimestamp(),
            "message_seen": false,
            "message_is_bad": isProfanity,
            "message_is_image": false,
            "message_ad_available": false,
            "message_premium": false
        ]
        
        // Save to Firebase - Android parity
        database.collection("Chats")
            .document(chatId)
            .collection("Messages")
            .document(messageId)
            .setData(messageData) { [weak self] error in
                guard let self = self else {
                    completion(false)
                    return
                }
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: AIMessageService", message: "saveAiMessage() failed: \(error.localizedDescription)")
                    completion(false)
                } else {
                    AppLogger.log(tag: "LOG-APP: AIMessageService", message: "saveAiMessage() success")
                    
                    // Update message count - Android parity
                    let currentCount = self.sessionManager.getTotalNoOfMessagesSent()
                    self.sessionManager.setTotalNoOfMessageSent(currentCount + 1)
                    
                    // Update chat metadata to match iOS chat list expectations
                    let chatUpdate: [String: Any] = [
                        "last_message": cleanedMessage,
                        "last_message_timestamp": FieldValue.serverTimestamp(),
                        "last_message_sent_by_user_id": otherUserId,
                        "new_message": true
                    ]
                    
                    self.database.collection("Chats")
                        .document(chatId)
                        .setData(chatUpdate, merge: true)
                    
                    // Save to training store - Android parity
                    AITrainingMessageStore.shared.insert(
                        messageId: messageId,
                        chatId: chatId,
                        userName: self.sessionManager.getUserName() ?? "",
                        userMessage: "", // Last user message would be stored here
                        replyName: otherUsername,
                        replyMessage: cleanedMessage,
                        messageTime: Date().timeIntervalSince1970
                    )
                    
                    // NOTE: Do NOT set failure time on success - failure recovery is only for failures (Android parity)
                    // Failure timestamp is only set when AI requests fail to prevent rapid retry spam
                    
                    completion(true)
                }
            }
    }
    
    // Note: truncateFromRight and areSentencesSimilar methods moved to FalconChatbotService for Android parity
}

// MARK: - SessionManager Extension for AI Cooldown (Android Parity)
extension SessionManager {
    
    /// Gets interest sentence - Android getInterestSentence() equivalent
    func getInterestSentence() -> String? {
        return UserDefaults.standard.string(forKey: "interestSentence")
    }
    
    /// Sets interest sentence - Android setInterestSentence() equivalent  
    func setInterestSentence(_ sentence: String?) {
        UserDefaults.standard.set(sentence, forKey: "interestSentence")
        synchronize()
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setInterestSentence() sentence set to: \(sentence ?? "nil")")
    }
    
    /// Gets total messages sent count - Android getTotalNoOfMessagesSent() equivalent
    func getTotalNoOfMessagesSent() -> Int {
        return UserDefaults.standard.integer(forKey: "totalNoOfMessagesSent")
    }
    
    /// Sets total messages sent count - Android setTotalNoOfMessageSent() equivalent
    func setTotalNoOfMessageSent(_ count: Int) {
        UserDefaults.standard.set(count, forKey: "totalNoOfMessagesSent")
        synchronize()
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setTotalNoOfMessageSent() count set to: \(count)")
    }
}

// MARK: - String Extension for Levenshtein Distance (Android Parity)
extension String {
    /// Calculates the Levenshtein distance to another string - Android parity
    func distance(to other: String) -> Int {
        let empty = [Int](repeating: 0, count: other.count)
        var last = [Int](0...other.count)

        for (i, selfChar) in self.enumerated() {
            var cur = [i + 1] + empty
            for (j, otherChar) in other.enumerated() {
                cur[j + 1] = selfChar == otherChar ? last[j] : Swift.min(last[j], last[j + 1], cur[j]) + 1
            }
            last = cur
        }
        return last.last ?? 0
    }
} 