//
//  ChatFlowManager.swift
//  ChatHub
//
//  Created by AI Assistant on 1/20/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAnalytics

// MARK: - ChatFlowCallback Protocol (New System)
protocol ChatFlowCallback {
    func onChatCreated(chatId: String, otherUserId: String)
    func onError(_ error: Error)
}

// MARK: - Legacy ChatFlowCallback Protocol (For Backward Compatibility)
protocol LegacyChatFlowCallback {
    func onChatCreated(chatId: String, otherUserId: String)
    func onShowMonetizationDialog(coins: Int, freeMessage: Bool)
    func onError(_ error: Error)
}

// MARK: - ChatFlowManager
class ChatFlowManager {
    static let shared = ChatFlowManager()
    
    private let sessionManager = SessionManager.shared
    private let moderationSettingsManager = ModerationSettingsSessionManager.shared
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Inbox Routing Decision Flow (Lite Check + Compatibility Algorithm)
    func executeInboxRoutingDecision(
        otherUserId: String,
        otherUserName: String,
        otherUserGender: String,
        otherUserCountry: String,
        otherUserImage: String,
        otherUserDevId: String,
        otherUserAge: String = "",
        otherUserLanguage: String = "",
        callback: ChatFlowCallback
    ) {
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "executeInboxRoutingDecision() STARTING ROUTING DECISION FLOW")
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "executeInboxRoutingDecision() d_other_user_id = \(otherUserId) d_other_user_name \(otherUserName) d_other_user_gender \(otherUserGender) d_other_user_country \(otherUserCountry) d_other_user_image \(otherUserImage) d_other_user_dev_id \(otherUserDevId)")
        
        // STEP 1: Gender compatibility analysis
        var alGenderMatch = true
        var myGender = true
        var otherUserGenderBool = true
        
        if let userGender = sessionManager.userGender, userGender != "null" {
            if userGender.lowercased() == "female" {
                myGender = false
            }
        }
        
        if otherUserGender != "null" {
            if otherUserGender.lowercased() == "female" {
                otherUserGenderBool = false
            }
        }
        
        if myGender && !otherUserGenderBool {
            alGenderMatch = false
        }
        
        // STEP 2: Country matching logic (matching Android)
        var alCountryMatch: Bool
        let myCountry: String
        if let retrievedCountry = sessionManager.userRetrievedCountry, retrievedCountry != "null" {
            if let userCountry = sessionManager.userCountry, userCountry.lowercased() == retrievedCountry.lowercased() {
                myCountry = userCountry
            } else {
                myCountry = retrievedCountry
            }
        } else {
            myCountry = sessionManager.userCountry ?? ""
        }
        alCountryMatch = myCountry.lowercased() == otherUserCountry.lowercased()
        
        // STEP 3: Age matching logic (NEW)
        var alAgeMatch = true
        if let myAge = sessionManager.userAge, let myAgeInt = Int(myAge),
           let otherAgeInt = Int(otherUserAge) {
            // Define age compatibility range (±5 years for example)
            let ageCompatibilityRange = 5
            let ageDifference = abs(myAgeInt - otherAgeInt)
            if ageDifference > ageCompatibilityRange {
                alAgeMatch = false
            }
        }
        
        // STEP 4: Language matching logic (NEW)
        var alLanguageMatch = true
        if let myLanguage = sessionManager.userLanguage, !myLanguage.isEmpty,
           !otherUserLanguage.isEmpty, myLanguage != "null", otherUserLanguage != "null" {
            alLanguageMatch = myLanguage.lowercased() == otherUserLanguage.lowercased()
        }
        
        // STEP 5: LITE SUBSCRIPTION CHECK (Priority Check)
        // If user has Lite subscription or higher, skip algorithm entirely
        let subscriptionSessionManager = SubscriptionSessionManager.shared
        let hasLiteOrHigher = subscriptionSessionManager.hasLiteTierOrHigher()
        
        if hasLiteOrHigher {
            AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "executeInboxRoutingDecision() User has Lite+ subscription - bypassing algorithm")
            
            // Log routing decision for Lite+ users
            ConversationFlowLogger.shared.logRoutingDecision(
                flowId: "FLOW_ACTIVE",
                decision: RoutingDecision(toInbox: false, isPaid: true),
                userType: subscriptionSessionManager.hasProTier() ? .pro : 
                          subscriptionSessionManager.hasPlusTierOrHigher() ? .plus : .lite,
                bypassReason: "Lite+ subscription bypass"
            )
            
            // Lite+ users always go to direct chat (same as Premium users)
            createChatWithRouting(
                otherUserId: otherUserId,
                otherUserName: otherUserName,
                otherUserGender: otherUserGender,
                otherUserImage: otherUserImage,
                otherUserDevId: otherUserDevId,
                inBox: false,  // Always direct chat for Lite+ users
                paid: true,    // Lite+ users are paid subscribers
                callback: callback
            )
            return
        }
        
        // STEP 6: RUN COMPATIBILITY ALGORITHM (Free Users Only)
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "executeInboxRoutingDecision() Running compatibility algorithm for FREE user")
        
        // Create compatibility factors for structured logging
        let userAge = Int(sessionManager.userAge ?? "0") ?? 0
        let otherAge = Int(otherUserAge) ?? 0
        let compatibilityFactors = CompatibilityFactors(
            userCountry: myCountry,
            otherCountry: otherUserCountry,
            countryMatch: alCountryMatch,
            userGender: myGender ? "Male" : "Female",
            otherGender: otherUserGenderBool ? "Male" : "Female",
            genderMatch: alGenderMatch,
            userAge: userAge,
            otherAge: otherAge,
            ageMatch: alAgeMatch,
            userLanguage: sessionManager.userLanguage ?? "Unknown",
            otherLanguage: otherUserLanguage,
            languageMatch: alLanguageMatch
        )
        
        let algorithmResult = calculateCompatibilityScore(
            myGender: myGender,
            otherUserGenderBool: otherUserGenderBool,
            alGenderMatch: alGenderMatch,
            alCountryMatch: alCountryMatch,
            alAgeMatch: alAgeMatch,
            alLanguageMatch: alLanguageMatch
        )
        
        // Log algorithm execution with detailed factors
        let compatibilityResult = CompatibilityResult(
            mismatchCount: algorithmResult.mismatchCount,
            details: algorithmResult.details
        )
        
        ConversationFlowLogger.shared.logAlgorithmExecution(
            flowId: "FLOW_ACTIVE", // Will be enhanced to pass actual flowId
            factors: compatibilityFactors,
            result: compatibilityResult
        )
        
        // STEP 7: APPLY ROUTING DECISION
        let shouldGoToInbox = algorithmResult.mismatchCount >= 3
        
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "executeInboxRoutingDecision() ROUTING DECISION: inBox=\(shouldGoToInbox) (Mismatches: \(algorithmResult.mismatchCount), Threshold: 3)")
        
        // Log routing decision
        ConversationFlowLogger.shared.logRoutingDecision(
            flowId: "FLOW_ACTIVE",
            decision: RoutingDecision(toInbox: shouldGoToInbox, isPaid: false),
            userType: .free,
            bypassReason: nil
        )
        
        // Proceed to chat creation with algorithm-based routing decision
        createChatWithRouting(
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserGender: otherUserGender,
            otherUserImage: otherUserImage,
            otherUserDevId: otherUserDevId,
            inBox: shouldGoToInbox,  // Algorithm decision based on compatibility
            paid: false,  // Free users are always non-paid
            callback: callback
        )
    }
    
    // MARK: - Compatibility Algorithm (Pure Calculation)
    private func calculateCompatibilityScore(
        myGender: Bool,
        otherUserGenderBool: Bool,
        alGenderMatch: Bool,
        alCountryMatch: Bool,
        alAgeMatch: Bool,
        alLanguageMatch: Bool
    ) -> (mismatchCount: Int, details: [String: Bool]) {
        
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "calculateCompatibilityScore() STARTING COMPATIBILITY ALGORITHM")
        
        var mismatchCount = 0
        var details: [String: Bool] = [:]
        
        // Factor 1: Country Compatibility
        if !alCountryMatch {
            AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "calculateCompatibilityScore() ❌ Country mismatch")
            mismatchCount += 1
            details["country"] = false
        } else {
            AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "calculateCompatibilityScore() ✅ Country match")
            details["country"] = true
        }
        
        // Factor 2: Gender Compatibility
        if !alGenderMatch {
            AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "calculateCompatibilityScore() ❌ Gender mismatch (Male→Female)")
            mismatchCount += 1
            details["gender"] = false
        } else {
            AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "calculateCompatibilityScore() ✅ Gender match")
            details["gender"] = true
        }
        
        // Factor 3: Age Compatibility
        if !alAgeMatch {
            AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "calculateCompatibilityScore() ❌ Age mismatch (>5 years difference)")
            mismatchCount += 1
            details["age"] = false
        } else {
            AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "calculateCompatibilityScore() ✅ Age match (≤5 years difference)")
            details["age"] = true
        }
        
        // Factor 4: Language Compatibility
        if !alLanguageMatch {
            AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "calculateCompatibilityScore() ❌ Language mismatch")
            mismatchCount += 1
            details["language"] = false
        } else {
            AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "calculateCompatibilityScore() ✅ Language match")
            details["language"] = true
        }
        
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "calculateCompatibilityScore() ALGORITHM COMPLETE: \(mismatchCount)/4 mismatches")
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "calculateCompatibilityScore() Compatibility: \(4-mismatchCount)/4 factors matched")
        
        return (mismatchCount: mismatchCount, details: details)
    }
    
    // MARK: - Enhanced Chat Creation with Routing (New System)
    func createChatWithRouting(
        otherUserId: String,
        otherUserName: String,
        otherUserGender: String,
        otherUserImage: String,
        otherUserDevId: String,
        inBox: Bool,
        paid: Bool,
        callback: ChatFlowCallback
    ) {
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "createChatWithRouting() Starting chat creation with routing: inBox=\(inBox), paid=\(paid)")
        
        checkOldOrNewChat(
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserGender: otherUserGender,
            otherUserImage: otherUserImage,
            otherUserDevId: otherUserDevId,
            inBox: inBox,
            paid: paid,
            callback: callback
        )
    }
    
    // MARK: - Direct Chat Creation (Premium/New Users - NO Algorithm)
    func createDirectChat(
        otherUserId: String,
        otherUserName: String,
        otherUserGender: String,
        otherUserImage: String,
        otherUserDevId: String,
        isPremiumUser: Bool,
        callback: ChatFlowCallback
    ) {
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "createDirectChat() Direct chat creation - bypassing algorithm (Premium: \(isPremiumUser))")
        
        // Direct chat creation without algorithm - always goes to direct chat list
        checkOldOrNewChat(
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserGender: otherUserGender,
            otherUserImage: otherUserImage,
            otherUserDevId: otherUserDevId,
            inBox: false,  // Always direct chat for premium/new users
            paid: isPremiumUser,
            callback: callback
        )
    }
    
    // MARK: - Legacy Chat Creation (Backward Compatibility)
    func createChat(
        otherUserId: String,
        otherUserName: String,
        otherUserGender: String,
        otherUserImage: String,
        otherUserDevId: String,
        callback: ChatFlowCallback
    ) {
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "createChat() Starting legacy chat creation process")
        
        // For backward compatibility, use default routing
        checkOldOrNewChat(
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserGender: otherUserGender,
            otherUserImage: otherUserImage,
            otherUserDevId: otherUserDevId,
            inBox: false,
            paid: false,
            callback: callback
        )
    }
    
    // MARK: - Chat Creation Logic (Android Parity)
    func checkOldOrNewChat(
        otherUserId: String,
        otherUserName: String,
        otherUserGender: String,
        otherUserImage: String,
        otherUserDevId: String,
        inBox: Bool,
        paid: Bool,
        callback: ChatFlowCallback
    ) {
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "checkOldOrNewChat() clicked user id \(otherUserId) my user id \(sessionManager.userId ?? "")")
        
        guard let currentUserId = sessionManager.userId, !currentUserId.isEmpty else {
            callback.onError(NSError(domain: "ChatFlowManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid current user ID"]))
            return
        }
        
        // Check if chat already exists
        db.collection("Users").document(currentUserId).collection("Chats").document(otherUserId).getDocument { [weak self] document, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "checkOldOrNewChat() get failed with \(error.localizedDescription)")
                callback.onError(error)
                return
            }
            
            if let document = document, document.exists {
                // Chat exists, use existing chat ID
                if let chatId = document.data()?["Chat_id"] as? String {
                    AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "checkOldOrNewChat() DocumentSnapshot data: \(document.data() ?? [:])")
                    self?.saveAIMessagesToLocalDb(chatId: chatId)
                    self?.setChatId(
                        otherUserId: otherUserId,
                        otherUserName: otherUserName,
                        otherUserImage: otherUserImage,
                        otherUserGender: otherUserGender,
                        otherUserDevId: otherUserDevId,
                        inBox: inBox,
                        paid: paid,
                        chatId: chatId,
                        callback: callback
                    )
                }
            } else {
                // Create new chat
                let unixTime = Int64(Date().timeIntervalSince1970)
                let chatId = "\(unixTime)\(currentUserId)"
                AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "checkOldOrNewChat() No such document, creating new chat")
                self?.saveAIMessagesToLocalDb(chatId: chatId)
                self?.setChatId(
                    otherUserId: otherUserId,
                    otherUserName: otherUserName,
                    otherUserImage: otherUserImage,
                    otherUserGender: otherUserGender,
                    otherUserDevId: otherUserDevId,
                    inBox: inBox,
                    paid: paid,
                    chatId: chatId,
                    callback: callback
                )
            }
        }
    }
    
    // MARK: - Set Chat ID (Android Parity)
    private func setChatId(
        otherUserId: String,
        otherUserName: String,
        otherUserImage: String,
        otherUserGender: String,
        otherUserDevId: String,
        inBox: Bool,
        paid: Bool,
        chatId: String,
        callback: ChatFlowCallback
    ) {
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "setChatId()")
        
        guard let currentUserId = sessionManager.userId else {
            callback.onError(NSError(domain: "ChatFlowManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid current user ID"]))
            return
        }
        
        let batch = db.batch()
        
        // CRITICAL FIX: Setting my data (initiator) - inbox should ALWAYS be false for the person starting the conversation
        let peopleData: [String: Any] = [
            "User_name": otherUserName,
            "User_image": otherUserImage,
            "User_gender": otherUserGender,
            "User_device_id": otherUserDevId,
            "Chat_id": chatId,
            "inbox": false, // ANDROID PARITY: Always false for initiator (line 1942 in Android)
            "paid": paid,
            "new_message": true,
            "conversation_deleted": false,
            "last_message_timestamp": FieldValue.serverTimestamp()
        ]
        
        let myCommunicationRef = db.collection("Users").document(currentUserId).collection("Chats").document(otherUserId)
        batch.setData(peopleData, forDocument: myCommunicationRef, merge: true)
        
        // Check if this should be an AI chat
        let aiChatIds = sessionManager.aiChatIds
        if aiChatIds.contains(chatId.trimmingCharacters(in: .whitespaces)) {
            // AI chat handling
            Analytics.logEvent("app_events", parameters: [
                AnalyticsParameterItemName: "ai_chat_opened_from_profile"
            ])
            sessionManager.lastMessageReceivedTime = Date().timeIntervalSince1970
        } else if shouldAiTakeOver() {
            // Start new AI chat
            var currentAiChatIds = sessionManager.aiChatIds
            currentAiChatIds.append(chatId)
            sessionManager.aiChatIds = currentAiChatIds
            sessionManager.lastMessageReceivedTime = Date().timeIntervalSince1970
            
            Analytics.logEvent("app_events", parameters: [
                AnalyticsParameterItemName: "ai_chat_started"
            ])
        } else {
            // CRITICAL FIX: Setting other user's data (recipient) - inbox should use the inBox parameter (line 1965 in Android)
            let otherUserData: [String: Any] = [
                "User_gender": sessionManager.userGender ?? "",
                "User_name": sessionManager.userName ?? "",
                "User_image": sessionManager.userProfilePhoto ?? "",
                "User_device_id": sessionManager.deviceId ?? "",
                "Chat_id": chatId,
                "inbox": inBox, // ANDROID PARITY: Use inBox parameter for recipient
                "paid": paid,
                "new_message": true,
                "conversation_deleted": false,
                "last_message_timestamp": FieldValue.serverTimestamp()
            ]
            
            let otherCommunicationRef = db.collection("Users").document(otherUserId).collection("Chats").document(currentUserId)
            batch.setData(otherUserData, forDocument: otherCommunicationRef, merge: true)
        }
        
        batch.commit { [weak self] error in
            if let error = error {
                callback.onError(error)
                return
            }
            
            // Update statistics (matching Android)
            var putNotification: [String: Any] = [:]
            if otherUserGender.lowercased() == "male" {
                putNotification["male_chats"] = FieldValue.increment(Int64(1))
            } else {
                putNotification["female_chats"] = FieldValue.increment(Int64(1))
            }
            
            if let deviceId = self?.sessionManager.deviceId {
                self?.db.collection("UserDevData").document(deviceId).setData(putNotification, merge: true)
            }
            
            // Note: Conversation count is already incremented by ConversationLimitManagerNew.performConversationStart()
            AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "setChatId() Chat created - conversation count: \(self?.sessionManager.conversationsStartedCount ?? 0)")
            
            AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "setChatId() Chat created successfully - initiator inbox=false, recipient inbox=\(inBox)")
            
            callback.onChatCreated(chatId: chatId, otherUserId: otherUserId)
        }
    }
    
    // MARK: - AI Logic (Android Parity)
    private func shouldAiTakeOver() -> Bool {
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "shouldAiTakeOver()")
        
        let timeElapsedSinceLastMessageReceived = Date().timeIntervalSince1970 - sessionManager.lastMessageReceivedTime
        let maxIdleSeconds = Double(sessionManager.maxIdleSecondsForAiChatEnabling)
        
        // Check gender-specific AI chat settings (matching Android)
        var aiChatEnabled = false
        if let userGender = sessionManager.keyUserGender, userGender.lowercased() == "male" {
            aiChatEnabled = sessionManager.aiChatEnabled
        } else {
            aiChatEnabled = sessionManager.aiChatEnabledWoman
        }
        
        // AI takeover conditions (matching Android logic)
        let shouldTakeOver = aiChatEnabled && 
                           timeElapsedSinceLastMessageReceived > maxIdleSeconds &&
                           maxIdleSeconds > 0
        
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "shouldAiTakeOver() aiChatEnabled: \(aiChatEnabled), timeElapsed: \(timeElapsedSinceLastMessageReceived), maxIdle: \(maxIdleSeconds), shouldTakeOver: \(shouldTakeOver)")
        
        return shouldTakeOver
    }
    
    // MARK: - AI Messages (Android Parity)
    private func saveAIMessagesToLocalDb(chatId: String) {
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "saveAIMessagesToLocalDb() chatId: \(chatId)")
        
        // Fetch and save AI messages from Firebase (matching Android fetchAndSaveAIMessages)
        fetchAndSaveAIMessages(chatId: chatId)
    }
    
    // MARK: - Fetch AI Messages from Firebase (Android Parity)
    private func fetchAndSaveAIMessages(chatId: String) {
        AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "fetchAndSaveAIMessages() chatId: \(chatId)")
        
        db.collection("AIMessages").document("messages").getDocument { [weak self] document, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "fetchAndSaveAIMessages() Error fetching AI messages: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists,
               let data = document.data(),
               let formattedMessages = data["formatted_messages"] as? String {
                
                AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "fetchAndSaveAIMessages() Successfully fetched AI messages")
                
                // Save to local database (matching Android)
                AITrainingMessageStore.shared.insert(
                    messageId: UUID().uuidString,
                    chatId: chatId,
                    userName: self?.sessionManager.userName ?? "",
                    userMessage: "Profile view initiated",
                    replyName: "AI Assistant",
                    replyMessage: formattedMessages,
                    messageTime: Date().timeIntervalSince1970
                )
            } else {
                AppLogger.log(tag: "LOG-APP: ChatFlowManager", message: "fetchAndSaveAIMessages() No AI messages found or document doesn't exist")
            }
        }
    }
    
} 