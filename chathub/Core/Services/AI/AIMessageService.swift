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
    private let openRouterChatbot = OpenRouterChatbotService.shared
    private let veniceChatbot = VeniceChatbotService.shared
    private let moodGenerator = MoodGenerator.shared
    // Deprecated: ChatConversationManager will be removed in favor of structured prompts
    // private let conversationManager = ChatConversationManager.shared
    private let structuredPromptBuilder = StructuredPromptBuilder()
    private let curatedExamplesProvider = CuratedExamplesProvider()

    // MARK: - Prompt Scaffold Cache (per conversation)
    private struct PromptScaffoldCacheEntry {
        let openRouterHeader: String   // Static header up to (and including) EXAMPLE CONVERSATION section
        let veniceHeader: String       // Static header up to (and including) EXAMPLE CONVERSATION section
        let toneMessages: String       // Cached tone messages block
        let modelMessages: String      // Cached model messages/examples block
    }
    private var promptScaffoldCache: [String: PromptScaffoldCacheEntry] = [:]

    // Adapter to reuse existing OpenRouter response handling pipeline shape
    class VeniceCallbackProxy: VeniceChatbotService.VeniceCallback {
        weak var aiServiceRef: AIMessageService?
        let prompt: String
        let chatId: String
        let otherProfile: UserCoreDataReplacement
        let lastAiMessage: String?
        let isProfanity: Bool
        let completion: (Bool) -> Void
        let currentTime: Int64
        
        init(aiService: AIMessageService,
             prompt: String,
             chatId: String,
             otherProfile: UserCoreDataReplacement,
             lastAiMessage: String?,
             isProfanity: Bool,
             completion: @escaping (Bool) -> Void,
             currentTime: Int64) {
            self.aiServiceRef = aiService
            self.prompt = prompt
            self.chatId = chatId
            self.otherProfile = otherProfile
            self.lastAiMessage = lastAiMessage
            self.isProfanity = isProfanity
            self.completion = completion
            self.currentTime = currentTime
        }
        
        func onFailure(error: Error) {
            AppLogger.log(tag: "LOG-APP: AIMessageService", message: "Venice onFailure: \(error.localizedDescription)")
            SessionManager.shared.setAiLastFailureTime(currentTime)
            self.completion(false)
        }
        
        func onResponse(responseData: Data) {
            guard let aiService = aiServiceRef else { return self.completion(false) }
            let otherUserName = self.otherProfile.name ?? self.otherProfile.username ?? "Friend"
            let currentUserName = SessionManager.shared.getUserName() ?? ""
            if let processedResponse = VeniceChatbotService.processAIResponse(
                responseData: responseData,
                originalPrompt: prompt,
                otherUserName: otherUserName,
                currentUserName: currentUserName
            ) {
                AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() Venice processedResponse=\(processedResponse)")
                // Hard safety trigger: if model signals prohibited content, clear conversation
                if processedResponse.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "delete conversation" {
                    AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() Venice trigger received: delete conversation")
                    aiService.clearAiMessages(chatId: self.chatId, otherUserId: self.otherProfile.userId ?? "") { _ in
                        self.completion(false)
                    }
                    return
                }
                if let lastMessage = self.lastAiMessage,
                   FalconChatbotService.areSentencesSimilar(lastMessage, processedResponse, thresholdPercent: 95) {
                    AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() Similar message detected (Venice)")
                    Analytics.logEvent("app_events", parameters: [
                        AnalyticsParameterItemName: "ai_chat_similar_reply"
                    ])
                    self.completion(false)
                } else {
                    aiService.saveAiMessage(
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
            } else {
                SessionManager.shared.setAiLastFailureTime(currentTime)
                self.completion(false)
            }
        }
    }
    
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

    /// Prepares and caches static prompt scaffold for a chat so only CURRENT MESSAGES varies per send
    func preparePromptScaffold(
        chatId: String,
        otherProfile: UserCoreDataReplacement,
        myProfile: UserCoreDataReplacement,
        isProfanity: Bool,
        myInterestTags: [String] = [],
        otherInterestTags: [String] = [],
        completion: (() -> Void)? = nil
    ) {
        // If already cached, return immediately
        if promptScaffoldCache[chatId] != nil {
            completion?()
            return
        }

        // Build on background as it may do small string work
        getAiTrainingMessages(chatId: chatId) { [weak self] trainingMessages in
            guard let self = self else { return }

            var myInterests = myInterestTags
            if myInterests.isEmpty { myInterests = SessionManager.shared.interestTags }
            var otherInterests = otherInterestTags
            // If AI character has no interests in Firebase, this will remain empty
            // which is correct - only show interests that are actually stored

            let mood = self.moodGenerator.getMood(isProfanity: isProfanity)
            let curatedExamples = self.curatedExamplesProvider.curatedExamples(myProfile: myProfile, otherProfile: otherProfile)

            // Extract default system prompt parts
            let systemPrompt = OpenRouterChatbotService.shared.defaultSystemPrompt()
            let sysParts = systemPrompt.components(separatedBy: "HARD RULES:")
            let sysIntro = sysParts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var hardRulesSection = ""
            var behaviorSection = ""
            if sysParts.count > 1 {
                let afterHard = sysParts[1]
                let behaviorParts = afterHard.components(separatedBy: "BEHAVIOR:")
                hardRulesSection = behaviorParts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if behaviorParts.count > 1 {
                    behaviorSection = behaviorParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // Names and pronouns
            let currentUserName = self.sessionManager.getUserName() ?? ""
            let myName = myProfile.name ?? myProfile.username ?? currentUserName
            let otherName = otherProfile.name ?? otherProfile.username ?? "Friend"
            let myGenderLower = myProfile.gender?.lowercased()
            let myPronoun1 = (myGenderLower == "female") ? "She" : "He"
            let myPronoun2 = (myGenderLower == "female") ? "Her" : "His"

            // Build OpenRouter header (sections 1-7), excluding CURRENT MESSAGES and YOUR TURN
            var orHeader = ""
            orHeader += "CURRENT SCENARIO\n"
            orHeader += "You are in an adult chat app called ChatHub. "
            if !sysIntro.isEmpty { orHeader += sysIntro + "\n\n" } else { orHeader += "\n\n" }
            orHeader += "CURRENT SITUATION\n"
            orHeader += "You are \(otherName). You are in an adult chat app called ChatHub."
            orHeader += self.generateYourProfileDescription(profile: otherProfile)
            orHeader += " You are chatting with \(myName),"
            orHeader += self.generateProfileDescription(pronoun1: myPronoun1, pronoun2: myPronoun2, profile: myProfile) + "\n\n"
            if !hardRulesSection.isEmpty {
                orHeader += "HARD RULES FOR \(otherName)\n" + hardRulesSection + "\n\n"
            }
            if !behaviorSection.isEmpty {
                orHeader += "\(otherName)'S BEHAVIOR\n" + behaviorSection + "\n\n"
            }
            orHeader += "CURRENT INTERESTS\n"
            let myInterestsLine = (myInterests.isEmpty ? SessionManager.shared.interestTags : myInterests).joined(separator: ", ")
            if !myInterestsLine.isEmpty { orHeader += "\(myName): \(myInterestsLine)\n" }
            let otherInterestsLine = otherInterests.joined(separator: ", ")
            if !otherInterestsLine.isEmpty { orHeader += "\(otherName): \(otherInterestsLine)\n" }
            if let currentInterestSentence = self.sessionManager.getInterestSentence(), !currentInterestSentence.isEmpty {
                orHeader += currentInterestSentence + "\n"
            }
            orHeader += "\n"
            if !trainingMessages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                orHeader += "\(otherName)'S REPLY STYLE\n"
                orHeader += trainingMessages + "\n"
            }
            orHeader += "EXAMPLE CONVERSATION BETWEEN \(myName) AND \(otherName)\n"
            if !curatedExamples.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                orHeader += curatedExamples + "\n"
            }
            orHeader += "\n"

            // Build Venice header with same sections (labels slightly differ already in current implementation)
            var veniceHeader = ""
            veniceHeader += "CURRENT SITUATION\n"
            veniceHeader += "You are " + otherName + ". You are in an adult chat app called ChatHub."
            veniceHeader += self.generateYourProfileDescription(profile: otherProfile)
            veniceHeader += " You are chatting with " + myName + ","
            veniceHeader += self.generateProfileDescription(pronoun1: myPronoun1, pronoun2: myPronoun2, profile: myProfile) + "\n\n"
            if !hardRulesSection.isEmpty {
                veniceHeader += "HARD RULES FOR \(otherName)\n" + hardRulesSection + "\n\n"
            }
            if !behaviorSection.isEmpty {
                veniceHeader += "\(otherName)'S BEHAVIOR\n" + behaviorSection + "\n\n"
            }
            veniceHeader += "CURRENT INTERESTS\n"
            if !myInterestsLine.isEmpty { veniceHeader += myName + ": " + myInterestsLine + "\n" }
            if !otherInterestsLine.isEmpty { veniceHeader += otherName + ": " + otherInterestsLine + "\n" }
            if let currentInterestSentence = self.sessionManager.getInterestSentence(), !currentInterestSentence.isEmpty {
                veniceHeader += currentInterestSentence + "\n"
            }
            veniceHeader += "\n"
            veniceHeader += "EXAMPLE CONVERSATION BETWEEN \(myName) AND \(otherName)\n"
            if !curatedExamples.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                veniceHeader += curatedExamples + "\n"
            }
            if !trainingMessages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                veniceHeader += "\(otherName)'S REPLY STYLE\n"
                veniceHeader += trainingMessages + "\n"
            }
            veniceHeader += "\n"

            self.promptScaffoldCache[chatId] = PromptScaffoldCacheEntry(
                openRouterHeader: orHeader,
                veniceHeader: veniceHeader,
                toneMessages: trainingMessages,
                modelMessages: curatedExamples
            )
            completion?()
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
        
        // If we already have a cached scaffold, use it; otherwise compute once now
        if let cached = self.promptScaffoldCache[chatId] {
            // Prepare input data for structured prompt
            var myInterests = myInterestTags
            if myInterests.isEmpty {
                myInterests = SessionManager.shared.interestTags
            }
            var otherInterests = otherInterestTags
            // If AI character has no interests in Firebase, this will remain empty
            // which is correct - only show interests that are actually stored

            // Mood
            let mood = self.moodGenerator.getMood(isProfanity: isProfanity)

            // Build standardized 9-segment structured prompt (only used for OpenRouter)
            var orContext = cached.openRouterHeader
            if !currentMessages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                orContext += "CURRENT MESSAGES\n" + currentMessages + "\n"
            } else {
                orContext += "CURRENT MESSAGES\n\n"
            }
            let otherName = otherProfile.name ?? otherProfile.username ?? "Friend"
            orContext += "YOUR (\(otherName)) TURN\n"
            orContext += "Now it's your turn to reply. Keep it very short (one brief sentence).\n"

            self.getAiMessage(
                prompt: self.structuredPromptBuilder.buildPrompt(
                    myProfile: myProfile,
                    otherProfile: otherProfile,
                    myInterests: myInterests,
                    otherInterests: otherInterests,
                    curatedExamples: cached.modelMessages,
                    trainingMessages: cached.toneMessages,
                    currentConversation: currentMessages,
                    mood: mood
                ),
                apiUrl: aiApiUrl,
                apiKey: aiApiKey,
                chatId: chatId,
                otherProfile: otherProfile,
                myProfile: myProfile,
                lastAiMessage: lastAiMessage,
                isProfanity: isProfanity,
                completion: completion,
                userMessageForOpenRouter: currentMessages,
                openRouterContext: orContext,
                veniceMyInterests: myInterests,
                veniceOtherInterests: otherInterests,
                toneMessages: cached.toneMessages,
                modelMessages: cached.modelMessages
            )
            return
        }

        // Get AI training messages - Android parity (first-time scaffold build)
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
            var otherInterests = otherInterestTags
            // If AI character has no interests in Firebase, this will remain empty
            // which is correct - only show interests that are actually stored

            // Mood
            let mood = self.moodGenerator.getMood(isProfanity: isProfanity)
            
            // Segment 3: Curated, style-focused examples
            let curatedExamples = self.curatedExamplesProvider.curatedExamples(myProfile: myProfile, otherProfile: otherProfile)

            // Build standardized 9-segment structured prompt
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
            // Build a structured OpenRouter context with standardized sections
            var orContext = ""
            let currentUserName = self.sessionManager.getUserName() ?? ""
            let myName = myProfile.name ?? myProfile.username ?? currentUserName
            let otherName = otherProfile.name ?? otherProfile.username ?? "Friend"

            // Derive pronouns for single-sentence scenario (Falcon style)
            let myGenderLower = myProfile.gender?.lowercased()
            let myPronoun1 = (myGenderLower == "female") ? "She" : "He"
            let myPronoun2 = (myGenderLower == "female") ? "Her" : "His"

            // Extract default system prompt parts to embed in context for consistent headings
            let systemPrompt = OpenRouterChatbotService.shared.defaultSystemPrompt()
            let sysParts = systemPrompt.components(separatedBy: "HARD RULES:")
            let sysIntro = sysParts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var hardRulesSection = ""
            var behaviorSection = ""
            if sysParts.count > 1 {
                let afterHard = sysParts[1]
                let behaviorParts = afterHard.components(separatedBy: "BEHAVIOR:")
                hardRulesSection = behaviorParts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if behaviorParts.count > 1 {
                    behaviorSection = behaviorParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // 1) CURRENT SCENARIO (high-level description)
            orContext += "CURRENT SCENARIO\n"
            orContext += "You are in an adult chat app called ChatHub. "
            if !sysIntro.isEmpty { orContext += sysIntro + "\n\n" } else { orContext += "\n\n" }

            // 2) CURRENT SITUATION (complete profile sentence for both participants)
            orContext += "CURRENT SITUATION\n"
            orContext += "You are \(otherName). You are in an adult chat app called ChatHub."
            orContext += self.generateYourProfileDescription(profile: otherProfile)
            orContext += " You are chatting with \(myName),"
            orContext += self.generateProfileDescription(pronoun1: myPronoun1, pronoun2: myPronoun2, profile: myProfile) + "\n\n"

            // 3) HARD RULES
            if !hardRulesSection.isEmpty {
                orContext += "HARD RULES FOR \(otherName)\n"
                orContext += hardRulesSection + "\n\n"
            }

            // 4) BEHAVIOR
            if !behaviorSection.isEmpty {
                orContext += "\(otherName)'S BEHAVIOR\n"
                orContext += behaviorSection + "\n\n"
            }

            // 5) CURRENT INTERESTS
            orContext += "CURRENT INTERESTS\n"
            let myInterestsLine = (myInterests.isEmpty ? SessionManager.shared.interestTags : myInterests).joined(separator: ", ")
            if !myInterestsLine.isEmpty { orContext += "\(myName): \(myInterestsLine)\n" }
            let otherInterestsLine = otherInterests.joined(separator: ", ")
            if !otherInterestsLine.isEmpty { orContext += "\(otherName): \(otherInterestsLine)\n" }
            if let currentInterestSentence = self.sessionManager.getInterestSentence(), !currentInterestSentence.isEmpty {
                orContext += currentInterestSentence + "\n"
            }
            orContext += "\n"

            // 6) AI CHARACTER'S REPLY STYLE (from Firebase via local store)
            if !trainingMessages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                orContext += "\(otherName)'S REPLY STYLE\n"
                orContext += trainingMessages + "\n"
            }

            // 7) EXAMPLE CONVERSATION (hand-crafted examples)
            orContext += "EXAMPLE CONVERSATION BETWEEN \(myName) AND \(otherName)\n"
            if !curatedExamples.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                orContext += curatedExamples + "\n"
            }
            orContext += "\n"

            // 8) CURRENT MESSAGES (recent conversation excerpts)
            orContext += "CURRENT MESSAGES\n"
            if !currentMessages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                orContext += currentMessages + "\n"
            }
            // 9) YOUR TURN (explicit reply instruction)
            orContext += "\nYOUR (\(otherName)) TURN\n"
            orContext += "Now it's your turn to reply. Keep it very short (one brief sentence).\n"

            // Cache the header for reuse next time
            self.promptScaffoldCache[chatId] = PromptScaffoldCacheEntry(
                openRouterHeader: orContext,
                veniceHeader: "", // We'll create Venice header in getAiMessage when needed for first send below
                toneMessages: trainingMessages,
                modelMessages: curatedExamples
            )

            self.getAiMessage(
                prompt: prompt,
                apiUrl: aiApiUrl,
                apiKey: aiApiKey,
                chatId: chatId,
                otherProfile: otherProfile,
                myProfile: myProfile,
                lastAiMessage: lastAiMessage,
                isProfanity: isProfanity,
                completion: completion,
                userMessageForOpenRouter: currentMessages,
                openRouterContext: orContext,
                veniceMyInterests: myInterests,
                veniceOtherInterests: otherInterests,
                toneMessages: trainingMessages,
                modelMessages: curatedExamples
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
        
        // Combine age and gender for better readability
        if let age = profile.age, !age.isEmpty && age.lowercased() != "null",
           let gender = profile.gender?.lowercased(), !gender.isEmpty && gender != "null" {
            descriptionBuilder += " You are a \(age)-year-old \(gender)"
        } else if let age = profile.age, !age.isEmpty && age.lowercased() != "null" {
            descriptionBuilder += " You are \(age) years old"
        } else if let gender = profile.gender?.lowercased(), !gender.isEmpty && gender != "null" {
            descriptionBuilder += " You are \(gender)"
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
    
    /// Generates detailed profile description for my user - Android generateProfileDescription() equivalent
    private func generateProfileDescription(pronoun1: String, pronoun2: String, profile: UserCoreDataReplacement) -> String {
        var descriptionBuilder = ""
        
        // Combine age and gender for better readability
        if let age = profile.age, !age.isEmpty && age.lowercased() != "null",
           let gender = profile.gender?.lowercased(), !gender.isEmpty && gender != "null" {
            descriptionBuilder += " \(pronoun1) is a \(age)-year-old \(gender)"
        } else if let age = profile.age, !age.isEmpty && age.lowercased() != "null" {
            descriptionBuilder += " \(pronoun1) is \(age) years old"
        } else if let gender = profile.gender?.lowercased(), !gender.isEmpty && gender != "null" {
            descriptionBuilder += " \(pronoun1) is \(gender)"
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
        myProfile: UserCoreDataReplacement,
        lastAiMessage: String?,
        isProfanity: Bool,
        completion: @escaping (Bool) -> Void,
        userMessageForOpenRouter: String = "",
        openRouterContext: String = "",
        veniceMyInterests: [String] = [],
        veniceOtherInterests: [String] = [],
        toneMessages: String = "",
        modelMessages: String = ""
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
                 
                 // Hard safety trigger: if model signals prohibited content, clear conversation
                 if processedResponse.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "delete conversation" {
                     AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() Falcon trigger received: delete conversation")
                     self.aiService.clearAiMessages(chatId: self.chatId, otherUserId: self.otherProfile.userId ?? "") { _ in
                         self.completion(false)
                     }
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

        // OpenRouter callback for OpenRouterChatbotService
        class OpenRouterCallback: OpenRouterChatbotService.OpenRouterCallback {
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
                AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() OpenRouter request failed: \(error.localizedDescription)")
                aiService.sessionManager.setAiLastFailureTime(currentTime)
                Analytics.logEvent("app_events", parameters: [
                    AnalyticsParameterItemName: "ai_chat_failed_call_\(error.localizedDescription)"
                ])
                self.completion(false)
            }
            
            func onResponse(responseData: Data) {
                AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() OpenRouter response received")
                guard let processedResponse = OpenRouterChatbotService.processAIResponse(
                    responseData: responseData,
                    originalPrompt: self.prompt,
                    otherUserName: self.otherProfile.name ?? "",
                    currentUserName: self.aiService.sessionManager.getUserName() ?? ""
                ) else {
                    AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() Failed to process OpenRouter response")
                    self.completion(false)
                    return
                }
                // Hard safety trigger: if model signals prohibited content, clear conversation
                if processedResponse.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "delete conversation" {
                    AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() trigger received: delete conversation")
                    self.aiService.clearAiMessages(chatId: self.chatId, otherUserId: self.otherProfile.userId ?? "") { _ in
                        self.completion(false)
                    }
                    return
                }
                if let lastMessage = self.lastAiMessage,
                   FalconChatbotService.areSentencesSimilar(lastMessage, processedResponse, thresholdPercent: 95) {
                    AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() Similar message detected (OpenRouter)")
                    Analytics.logEvent("app_events", parameters: [
                        AnalyticsParameterItemName: "ai_chat_similar_reply"
                    ])
                    self.completion(false)
                } else {
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

        // Route to provider
        let provider = sessionManager.aiModelProvider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if provider == "openrouter" {
            let callback = OpenRouterCallback(
                aiService: self,
                prompt: prompt,
                chatId: chatId,
                otherProfile: otherProfile,
                lastAiMessage: lastAiMessage,
                isProfanity: isProfanity,
                completion: completion,
                currentTime: currentTime
            )
            // Fetch URL/Key directly from SessionManager (Firebase-backed AppSettings)
            let activeUrl = self.sessionManager.aiChatBotURL ?? ""
            let activeKey = self.sessionManager.aiApiKey ?? ""
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "OPENROUTER_USER_ONLY_TEST") {
                AppLogger.log(tag: "LOG-APP: AIMessageService", message: "Using OpenRouter user-only debug path")
                openRouterChatbot.sendUserOnlyMessage(
                    apiURL: activeUrl,
                    apiKey: activeKey,
                    userPrompt: userMessageForOpenRouter.isEmpty ? prompt : userMessageForOpenRouter,
                    callback: callback
                )
            } else {
                openRouterChatbot.sendMessage(
                    apiURL: activeUrl,
                    apiKey: activeKey,
                    systemPrompt: nil,
                    data: openRouterContext,
                    originalPrompt: userMessageForOpenRouter.isEmpty ? prompt : userMessageForOpenRouter,
                    callback: callback
                )
            }
            #else
            openRouterChatbot.sendMessage(
                apiURL: activeUrl,
                apiKey: activeKey,
                systemPrompt: nil,
                data: openRouterContext,
                originalPrompt: userMessageForOpenRouter.isEmpty ? prompt : userMessageForOpenRouter,
                callback: callback
            )
            #endif
            return
        } else if provider == "venice" {
            let callback = VeniceCallbackProxy(
                aiService: self,
                prompt: prompt,
                chatId: chatId,
                otherProfile: otherProfile,
                lastAiMessage: lastAiMessage,
                isProfanity: isProfanity,
                completion: completion,
                currentTime: currentTime
            )
            // Prefer explicit Venice URL; default to Venice base if unset (do not use aiChatBotURL)
            let activeUrl = SessionManager.shared.veniceApiUrl.isEmpty ? "https://api.venice.ai/api/v1" : SessionManager.shared.veniceApiUrl
            let activeKey = SessionManager.shared.veniceApiKey.isEmpty ? (self.sessionManager.aiApiKey ?? "") : SessionManager.shared.veniceApiKey

            // If scaffold cached, build the final single-prompt using cached header and dynamic CURRENT MESSAGES only
            if let cached = self.promptScaffoldCache[chatId] {
                let otherDisplayName = otherProfile.name ?? otherProfile.username ?? "Friend"
                let myDisplayName = myProfile.name ?? myProfile.username ?? (self.sessionManager.getUserName() ?? "")
                let finalUserMessage = userMessageForOpenRouter.isEmpty ? prompt : userMessageForOpenRouter

                var singlePrompt = cached.veniceHeader
                if singlePrompt.isEmpty {
                    // Build Venice header on first use if not present yet using cached tone/model blocks
                    let systemPrompt = OpenRouterChatbotService.shared.defaultSystemPrompt()
                    let vParts = systemPrompt.components(separatedBy: "HARD RULES:")
                    let vIntro = vParts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let myGenderLower = myProfile.gender?.lowercased()
                    let myPronoun1 = (myGenderLower == "female") ? "She" : "He"
                    let myPronoun2 = (myGenderLower == "female") ? "Her" : "His"
                    var header = ""
                    header += "CURRENT SITUATION\n"
                    header += "You are " + otherDisplayName + ". You are in an adult chat app called ChatHub."
                    header += self.generateYourProfileDescription(profile: otherProfile)
                    header += " You are chatting with " + myDisplayName + ","
                    header += self.generateProfileDescription(pronoun1: myPronoun1, pronoun2: myPronoun2, profile: myProfile) + "\n\n"
                    // We don't reconstruct HARD RULES/BEHAVIOR here; they are already embedded in cached.openRouterHeader for OR path
                    // But to keep Venice header consistent, reuse tone/model from cache as sections
                    // Since we don't have interest lines readily, we will rely on the original cached.openRouterHeader content for interests when initially cached
                    // For Venice, we keep minimal duplication by appending tone/model blocks from cache
                    // Add CURRENT INTERESTS section to keep Venice header parity with other paths
                    header += "CURRENT INTERESTS\n"
                    let veniceMyInterestsLine = (veniceMyInterests.isEmpty ? SessionManager.shared.interestTags : veniceMyInterests).joined(separator: ", ")
                    if !veniceMyInterestsLine.isEmpty { header += myDisplayName + ": " + veniceMyInterestsLine + "\n" }
                    let veniceOtherInterestsLine = veniceOtherInterests.joined(separator: ", ")
                    if !veniceOtherInterestsLine.isEmpty { header += otherDisplayName + ": " + veniceOtherInterestsLine + "\n" }
                    if let currentInterestSentence = self.sessionManager.getInterestSentence(), !currentInterestSentence.isEmpty {
                        header += currentInterestSentence + "\n"
                    }
                    header += "\n"
                    header += "EXAMPLE CONVERSATION BETWEEN \(myDisplayName) AND \(otherDisplayName)\n"
                    if !cached.modelMessages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        header += cached.modelMessages + "\n"
                    }
                    if !cached.toneMessages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        header += "\(otherDisplayName)'S REPLY STYLE\n"
                        header += cached.toneMessages + "\n"
                    }
                    header += "\n"
                    singlePrompt = header
                    // Save back to cache for subsequent reuse
                    self.promptScaffoldCache[chatId] = PromptScaffoldCacheEntry(
                        openRouterHeader: cached.openRouterHeader,
                        veniceHeader: header,
                        toneMessages: cached.toneMessages,
                        modelMessages: cached.modelMessages
                    )
                }
                singlePrompt += "CURRENT MESSAGES\n" + finalUserMessage
                singlePrompt += "\n\nYOUR (\(otherDisplayName)) TURN\n"
                singlePrompt += "Now it's your turn to reply. Keep it very short (one brief sentence)."

                veniceChatbot.sendSinglePrompt(
                    apiURL: activeUrl,
                    apiKey: activeKey,
                    prompt: singlePrompt,
                    callback: callback
                )
                return
            }
            // Build single-prompt content with standardized headings:
            // 1) CURRENT SCENARIO (description)
            // 2) CURRENT SITUATION (profiles)
            // 3) HARD RULES
            // 4) BEHAVIOR
            // 5) CURRENT INTERESTS
            // 6) AI CHARACTER'S REPLY STYLE
            // 7) EXAMPLE CONVERSATION
            // 8) CURRENT MESSAGES
            // 9) YOUR TURN
            var singlePrompt = ""
            // Extract default system prompt parts
            let veniceSystemPrompt = OpenRouterChatbotService.shared.defaultSystemPrompt()
            let vParts = veniceSystemPrompt.components(separatedBy: "HARD RULES:")
            let vIntro = vParts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var vHardRules = ""
            var vBehavior = ""
            if vParts.count > 1 {
                let afterHard = vParts[1]
                let bParts = afterHard.components(separatedBy: "BEHAVIOR:")
                vHardRules = bParts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if bParts.count > 1 {
                    vBehavior = bParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            // 1) CURRENT SITUATION (merged)
            singlePrompt += "CURRENT SITUATION\n"
            let otherDisplayName = otherProfile.name ?? otherProfile.username ?? "Friend"
            singlePrompt += "You are " + otherDisplayName + ". You are in an adult chat app called ChatHub."
            let myDisplayName = myProfile.name ?? myProfile.username ?? (self.sessionManager.getUserName() ?? "")
            let myGenderLower = myProfile.gender?.lowercased()
            let myPronoun1 = (myGenderLower == "female") ? "She" : "He"
            let myPronoun2 = (myGenderLower == "female") ? "Her" : "His"
            singlePrompt += self.generateYourProfileDescription(profile: otherProfile)
            singlePrompt += " You are chatting with " + myDisplayName + ","
            singlePrompt += self.generateProfileDescription(pronoun1: myPronoun1, pronoun2: myPronoun2, profile: myProfile) + "\n\n"
            // 2) HARD RULES
            if !vHardRules.isEmpty {
                singlePrompt += "HARD RULES FOR \(otherDisplayName)\n"
                singlePrompt += vHardRules + "\n\n"
            }
            // 3) BEHAVIOR
            if !vBehavior.isEmpty {
                singlePrompt += "\(otherDisplayName)'S BEHAVIOR\n"
                singlePrompt += vBehavior + "\n\n"
            }
            // 5) CURRENT INTERESTS
            singlePrompt += "CURRENT INTERESTS\n"
            let myInterestsLine = (veniceMyInterests.isEmpty ? SessionManager.shared.interestTags : veniceMyInterests).joined(separator: ", ")
            if !myInterestsLine.isEmpty { singlePrompt += myDisplayName + ": " + myInterestsLine + "\n" }
            let otherInterestsLine = veniceOtherInterests.joined(separator: ", ")
            if !otherInterestsLine.isEmpty { singlePrompt += otherDisplayName + ": " + otherInterestsLine + "\n" }
            if let currentInterestSentence = self.sessionManager.getInterestSentence(), !currentInterestSentence.isEmpty {
                singlePrompt += currentInterestSentence + "\n"
            }
            singlePrompt += "\n"
            // EXAMPLE CONVERSATION (hand-crafted) before reply style
            singlePrompt += "EXAMPLE CONVERSATION BETWEEN \(myDisplayName) AND \(otherDisplayName)\n"
            if !modelMessages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                singlePrompt += modelMessages + "\n"
            }
            // AI CHARACTER'S REPLY STYLE (periodic uploads)
            if !toneMessages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                singlePrompt += "\(otherDisplayName)'S REPLY STYLE\n"
                singlePrompt += toneMessages + "\n"
            }
            singlePrompt += "\n"
            // 8) CURRENT MESSAGES (user input)
            let finalUserMessage = userMessageForOpenRouter.isEmpty ? prompt : userMessageForOpenRouter
            singlePrompt += "CURRENT MESSAGES\n" + finalUserMessage
            // 9) YOUR TURN (explicit reply instruction)
            singlePrompt += "\n\nYOUR (\(otherDisplayName)) TURN\n"
            singlePrompt += "Now it's your turn to reply. Keep it very short (one brief sentence)."
            
            veniceChatbot.sendSinglePrompt(
                apiURL: activeUrl,
                apiKey: activeKey,
                prompt: singlePrompt,
                callback: callback
            )
            return
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
        
        // Fetch URL/Key directly from SessionManager (Firebase-backed AppSettings)
        let activeUrl = self.sessionManager.aiChatBotURL ?? ""
        let activeKey = self.sessionManager.aiApiKey ?? ""
        falconChatbot.sendMessage(apiURL: activeUrl, apiKey: activeKey, prompt: prompt, callback: callback)
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