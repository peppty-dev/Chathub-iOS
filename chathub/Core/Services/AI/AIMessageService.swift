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
    private let conversationManager = ChatConversationManager.shared
    
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
        completion: @escaping (Bool) -> Void
    ) {
        AppLogger.log(tag: "LOG-APP: AIMessageService", message: "prepareToGetAiMessage() preparing AI message generation")
        
        // Get AI training messages - Android parity
        getAiTrainingMessages(chatId: chatId) { [weak self] trainingMessages in
            guard let self = self else {
                completion(false)
                return
            }
            
            // Generate conversation context - Android parity
            let myInterests = myProfile.interests?.components(separatedBy: ",") ?? []
            let otherInterests = otherProfile.interests?.components(separatedBy: ",") ?? []
            
            let conversationContext = self.conversationManager.generateConversation(
                myInterests: myInterests,
                otherInterests: otherInterests,
                myProfile: myProfile,
                otherProfile: otherProfile
            )
            
            // Get mood for personality - Android parity
            let mood = self.moodGenerator.getMood(isProfanity: isProfanity)
            
            // Build prompt - Android parity
            let prompt = self.buildPrompt(
                trainingMessages: trainingMessages,
                conversationContext: conversationContext,
                mood: mood,
                myProfile: myProfile,
                otherProfile: otherProfile,
                isProfanity: isProfanity
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
    
    /// Builds AI prompt with context - Android buildPrompt() equivalent
    private func buildPrompt(
        trainingMessages: String,
        conversationContext: String,
        mood: String,
        myProfile: UserCoreDataReplacement,
        otherProfile: UserCoreDataReplacement,
        isProfanity: Bool
    ) -> String {
        AppLogger.log(tag: "LOG-APP: AIMessageService", message: "buildPrompt() building AI prompt")
        
        let myName = myProfile.name ?? "User"
        let otherName = otherProfile.name ?? "Friend"
        let myGender = myProfile.gender ?? "Unknown"
        let otherGender = otherProfile.gender ?? "Unknown"
        let myCountry = myProfile.country ?? "Unknown"
        let otherCountry = otherProfile.country ?? "Unknown"
        
        var prompt = ""
        
        // Add conversation context if available - Android parity
        if !conversationContext.isEmpty {
            prompt += "Here are some example conversations:\n\(conversationContext)\n\n"
        }
        
        // Add training messages if available - Android parity
        if !trainingMessages.isEmpty {
            prompt += "Previous conversation:\n\(trainingMessages)\n\n"
        }
        
        // Add personality instruction - Android parity
        prompt += "You are \(otherName), a \(otherGender) from \(otherCountry). "
        prompt += "You are chatting with \(myName), a \(myGender) from \(myCountry). "
        prompt += "Your mood is \(mood). "
        
        if isProfanity {
            prompt += "You can be flirty, seductive, and use adult language. "
        } else {
            prompt += "Keep the conversation friendly and appropriate. "
        }
        
        prompt += "Reply as \(otherName) in a natural, conversational way. "
        prompt += "Keep your response under 100 characters. "
        prompt += "Do not repeat previous messages. "
        prompt += "\(otherName)'s reply:"
        
        AppLogger.log(tag: "LOG-APP: AIMessageService", message: "buildPrompt() prompt length: \(prompt.count)")
        return prompt
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
        
        // Check cooldown - Android parity
        let currentTime = Int64(Date().timeIntervalSince1970)
        let cooldownTime = sessionManager.getAiCoolOffTime()
        
        if (cooldownTime + 60) > currentTime {
            AppLogger.log(tag: "LOG-APP: AIMessageService", message: "getAiMessage() AI in cooldown period")
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
                 aiService.sessionManager.setAiCoolOffTime(currentTime)
                 
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
        let mood = moodGenerator.getMood(isProfanity: isProfanity)
        
        let messageData: [String: Any] = [
            "message_id": messageId,
            "message_user_id": otherUserId,
            "message_user_name": otherUsername,
            "message_content_text": cleanedMessage,
            "message_content_image_url": "",
            "message_time": FieldValue.serverTimestamp(),
            "message_seen": false,
            "message_is_bad": isProfanity,
            "message_is_image": false,
            "mood": mood
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
                    
                    // Update chat metadata - Android parity
                    let chatUpdate: [String: Any] = [
                        "time": FieldValue.serverTimestamp(),
                        "is_chat_new_message": true,
                        "user_last_msg_user_id": otherUserId
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
                    
                    completion(true)
                }
            }
    }
    
    // Note: truncateFromRight and areSentencesSimilar methods moved to FalconChatbotService for Android parity
}

// MARK: - SessionManager Extension for AI Cooldown (Android Parity)
extension SessionManager {
    
    /// Gets AI cooldown time - Android getAiCoolOffTime() equivalent
    func getAiCoolOffTime() -> Int64 {
        return Int64(UserDefaults.standard.integer(forKey: "aiCoolOffTime"))
    }
    
    /// Sets AI cooldown time - Android setAiCoolOffTime() equivalent
    func setAiCoolOffTime(_ time: Int64) {
        UserDefaults.standard.set(Int(time), forKey: "aiCoolOffTime")
        synchronize()
        AppLogger.log(tag: "LOG-APP: SessionManager", message: "setAiCoolOffTime() cooldown set to: \(time)")
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