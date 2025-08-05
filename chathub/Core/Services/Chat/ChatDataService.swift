//
//  ChatDataService.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

/// ChatDataService - Handles chat data processing and business logic
/// Extracted from ChatsViewModel for better separation of concerns
class ChatDataService {
    static let shared = ChatDataService()
    
    private let chatDB = ChatsDB.shared
    private let backgroundQueue = DispatchQueue(label: "ChatDataService.background", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Data Loading Methods
    
    /// Load all chats with processing logic
    /// Returns tuple of (regular chats, inbox chats)
    func loadAllChats() async -> (regular: [Chat], inbox: [Chat]) {
        return await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: (regular: [], inbox: []))
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "loadAllChats() - Starting data load")
                
                // Load chats from database
                let allChats = self.chatDB.query()
                let inboxChats = self.chatDB.inboxquery()
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "loadAllChats() - Regular chats: \(allChats.count), Inbox chats: \(inboxChats.count)")
                
                // Process and log data samples
                self.logChatSamples(allChats, type: "Regular")
                self.logChatSamples(inboxChats, type: "Inbox")
                
                // Apply any business logic processing
                let processedRegular = self.processRegularChats(allChats)
                let processedInbox = self.processInboxChats(inboxChats)
                
                continuation.resume(returning: (regular: processedRegular, inbox: processedInbox))
            }
        }
    }
    
    /// Refresh chats with full reload
    func refreshAllChats() async -> (regular: [Chat], inbox: [Chat]) {
        AppLogger.log(tag: "LOG-APP: ChatDataService", message: "refreshAllChats() - Starting refresh")
        
        // Check database readiness before querying
        guard DatabaseManager.shared.isDatabaseReady() else {
            AppLogger.log(tag: "LOG-APP: ChatDataService", message: "refreshAllChats() - Database not ready, retrying")
            
            // Wait briefly and retry
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            return await refreshAllChats()
        }
        
        return await loadAllChats()
    }
    
    /// Load chats with pagination support
    func loadChatsPage(page: Int, pageSize: Int) async -> [Chat] {
        return await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "loadChatsPage() - Page: \(page), Size: \(pageSize)")
                
                let allChats = self.chatDB.query()
                let startIndex = page * pageSize
                let pageChats = Array(allChats.dropFirst(startIndex).prefix(pageSize))
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "loadChatsPage() - Returned \(pageChats.count) chats")
                continuation.resume(returning: pageChats)
            }
        }
    }
    
    // MARK: - Data Processing Methods
    
    /// Process regular chats with business logic
    private func processRegularChats(_ chats: [Chat]) -> [Chat] {
        AppLogger.log(tag: "LOG-APP: ChatDataService", message: "processRegularChats() - Processing \(chats.count) regular chats")
        
        // Apply any filtering or sorting logic
        let processedChats = chats.filter { chat in
            // Filter out any invalid chats
            return !chat.ChatId.isEmpty && !chat.Name.isEmpty
        }.sorted { chat1, chat2 in
            // Sort by timestamp, newest first
            return chat1.LastTimeStamp > chat2.LastTimeStamp
        }
        
        AppLogger.log(tag: "LOG-APP: ChatDataService", message: "processRegularChats() - Processed to \(processedChats.count) chats")
        return processedChats
    }
    
    /// Process inbox chats with business logic
    private func processInboxChats(_ chats: [Chat]) -> [Chat] {
        AppLogger.log(tag: "LOG-APP: ChatDataService", message: "processInboxChats() - Processing \(chats.count) inbox chats")
        
        // Apply inbox-specific processing
        let processedChats = chats.filter { chat in
            // Ensure inbox flag is set correctly
            return chat.inbox > 0
        }.sorted { chat1, chat2 in
            // Sort by timestamp, newest first
            return chat1.LastTimeStamp > chat2.LastTimeStamp
        }
        
        AppLogger.log(tag: "LOG-APP: ChatDataService", message: "processInboxChats() - Processed to \(processedChats.count) chats")
        return processedChats
    }
    
    /// Log chat samples for debugging
    private func logChatSamples(_ chats: [Chat], type: String) {
        AppLogger.log(tag: "LOG-APP: ChatDataService", message: "--- \(type) Chats Sample ---")
        for (index, chat) in chats.prefix(3).enumerated() {
            AppLogger.log(tag: "LOG-APP: ChatDataService", message: "\(type) chat \(index + 1): \(chat.Name) (inbox=\(chat.inbox), ChatId=\(chat.ChatId))")
        }
    }
    
    // MARK: - Inbox Data Methods
    
    /// Load inbox data for counter and preview
    func loadInboxData() async -> (count: Int, latestChat: Chat?) {
        return await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: (count: 0, latestChat: nil))
                    return
                }
                
                let inboxChats = self.chatDB.inboxquery()
                let count = inboxChats.count
                let latestChat = inboxChats.first // Assuming already sorted by timestamp
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "loadInboxData() - Count: \(count), Latest: \(latestChat?.Name ?? "none")")
                
                continuation.resume(returning: (count: count, latestChat: latestChat))
            }
        }
    }
    
    // MARK: - Chat Management Methods
    
    /// Update chat read status
    func markChatAsRead(chatId: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "markChatAsRead() - ChatId: \(chatId)")
                
                // Update chat in database
                self.chatDB.update(
                    LastTimeStamp: Date(),
                    NewMessage: 0,
                    ChatId: chatId,
                    Lastsentby: "",
                    Inbox: 0,
                    LastMessageSentByUserId: ""
                )
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "markChatAsRead() - Marked chat as read")
                continuation.resume(returning: true)
            }
        }
    }
    
    /// Delete chat from database
    func deleteChat(chatId: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "deleteChat() - ChatId: \(chatId)")
                
                self.chatDB.delete(ChatId: chatId)
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "deleteChat() - Chat deleted")
                continuation.resume(returning: true)
            }
        }
    }
    
    /// Move chat to inbox
    func moveChatToInbox(chatId: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "moveChatToInbox() - ChatId: \(chatId)")
                
                self.chatDB.update(
                    LastTimeStamp: Date(),
                    NewMessage: 0,
                    ChatId: chatId,
                    Lastsentby: "",
                    Inbox: 1, // Set inbox flag
                    LastMessageSentByUserId: ""
                )
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "moveChatToInbox() - Chat moved to inbox")
                continuation.resume(returning: true)
            }
        }
    }
    
    /// Get chat by ID
    func getChatById(_ chatId: String) async -> Chat? {
        return await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let allChats = self.chatDB.query()
                let chat = allChats.first { $0.ChatId == chatId }
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "getChatById() - Found: \(chat != nil)")
                continuation.resume(returning: chat)
            }
        }
    }
    
    // MARK: - Data Validation Methods
    
    /// Validate chat data integrity
    func validateChatData() async -> (valid: Int, invalid: Int) {
        return await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: (valid: 0, invalid: 0))
                    return
                }
                
                let allChats = self.chatDB.query()
                var validCount = 0
                var invalidCount = 0
                
                for chat in allChats {
                    if self.isValidChat(chat) {
                        validCount += 1
                    } else {
                        invalidCount += 1
                        AppLogger.log(tag: "LOG-APP: ChatDataService", message: "validateChatData() - Invalid chat: \(chat.ChatId)")
                    }
                }
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "validateChatData() - Valid: \(validCount), Invalid: \(invalidCount)")
                continuation.resume(returning: (valid: validCount, invalid: invalidCount))
            }
        }
    }
    
    /// Check if chat is valid
    private func isValidChat(_ chat: Chat) -> Bool {
        return !chat.ChatId.isEmpty &&
               !chat.Name.isEmpty &&
               !chat.UserId.isEmpty &&
               chat.LastTimeStamp.timeIntervalSince1970 > 0
    }
    
    // MARK: - Statistics Methods
    
    /// Get chat statistics
    func getChatStatistics() async -> ChatStatistics {
        return await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: ChatStatistics())
                    return
                }
                
                let allChats = self.chatDB.query()
                let inboxChats = self.chatDB.inboxquery()
                
                let stats = ChatStatistics(
                    totalChats: allChats.count,
                    regularChats: allChats.filter { $0.inbox == 0 }.count,
                    inboxChats: inboxChats.count,
                    unreadChats: allChats.filter { $0.newmessage }.count,
                    recentChats: allChats.filter { 
                        Date().timeIntervalSince1970 - $0.LastTimeStamp.timeIntervalSince1970 < 86400 // Last 24 hours
                    }.count
                )
                
                AppLogger.log(tag: "LOG-APP: ChatDataService", message: "getChatStatistics() - \(stats)")
                continuation.resume(returning: stats)
            }
        }
    }
}

// MARK: - Supporting Types

struct ChatStatistics: CustomStringConvertible {
    let totalChats: Int
    let regularChats: Int
    let inboxChats: Int
    let unreadChats: Int
    let recentChats: Int
    
    init(totalChats: Int = 0, regularChats: Int = 0, inboxChats: Int = 0, unreadChats: Int = 0, recentChats: Int = 0) {
        self.totalChats = totalChats
        self.regularChats = regularChats
        self.inboxChats = inboxChats
        self.unreadChats = unreadChats
        self.recentChats = recentChats
    }
    
    var description: String {
        return "Total: \(totalChats), Regular: \(regularChats), Inbox: \(inboxChats), Unread: \(unreadChats), Recent: \(recentChats)"
    }
} 