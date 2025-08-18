//
//  ActivityTracker.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import FirebaseFirestore

/// ActivityTracker - Comprehensive activity tracking for all user interactions
/// Implements detailed activity metrics with initiated/received distinctions
class ActivityTracker {
    
    // MARK: - Singleton
    static let shared = ActivityTracker()
    private init() {}
    
    // MARK: - Activity Types
    enum ActivityType {
        // User Interaction Counts
        case maleAccountInteraction
        case femaleAccountInteraction
        case maleChatInitiated
        case femaleChatInitiated
        case maleChatReceived
        case femaleChatReceived
        
        // Communication Activity
        case voiceCallInitiated
        case voiceCallJoined
        case videoCallInitiated
        case videoCallJoined
        case liveSessionInitiated
        case liveSessionJoined
        
        // Content Activity
        case messageSent
        case photoSent
        case photoReceived
        
        // Optional Features
        case gameStarted
        case gameCompleted
        
        var counterName: String {
            switch self {
            case .maleAccountInteraction: return "male_accounts_count"
            case .femaleAccountInteraction: return "female_accounts_count"
            case .maleChatInitiated: return "male_chats_initiated"
            case .femaleChatInitiated: return "female_chats_initiated"
            case .maleChatReceived: return "male_chats_received"
            case .femaleChatReceived: return "female_chats_received"
            case .voiceCallInitiated: return "voice_calls_initiated"
            case .voiceCallJoined: return "voice_calls_joined"
            case .videoCallInitiated: return "video_calls_initiated"
            case .videoCallJoined: return "video_calls_joined"
            case .liveSessionInitiated: return "live_sessions_initiated"
            case .liveSessionJoined: return "live_sessions_joined"
            case .messageSent: return "messages_sent"
            case .photoSent: return "photos_sent"
            case .photoReceived: return "photos_received"
            case .gameStarted: return "games_started"
            case .gameCompleted: return "games_completed"
            }
        }
    }
    
    // MARK: - Public API
    
    /// Track message sent activity
    func trackMessageSent(to otherUserId: String, otherUserGender: String) {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackMessageSent() to \(otherUserGender) user")
        
        // Update activity counters
        incrementActivity(userId: currentUserId, type: .messageSent)
        
        // Track gender-specific chat activity
        if otherUserGender.lowercased() == "male" {
            incrementActivity(userId: currentUserId, type: .maleChatInitiated)
        } else if otherUserGender.lowercased() == "female" {
            incrementActivity(userId: currentUserId, type: .femaleChatInitiated)
        }
        
        // Track account interaction
        trackAccountInteraction(userId: currentUserId, otherUserGender: otherUserGender)
    }
    
    /// Track message received activity
    func trackMessageReceived(from otherUserId: String, otherUserGender: String) {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackMessageReceived() from \(otherUserGender) user")
        
        // Track gender-specific chat activity
        if otherUserGender.lowercased() == "male" {
            incrementActivity(userId: currentUserId, type: .maleChatReceived)
        } else if otherUserGender.lowercased() == "female" {
            incrementActivity(userId: currentUserId, type: .femaleChatReceived)
        }
        
        // Track account interaction
        trackAccountInteraction(userId: currentUserId, otherUserGender: otherUserGender)
    }
    
    /// Track voice call initiated
    func trackVoiceCallInitiated(to otherUserId: String) {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackVoiceCallInitiated() to user \(otherUserId)")
        incrementActivity(userId: currentUserId, type: .voiceCallInitiated)
    }
    
    /// Track voice call joined
    func trackVoiceCallJoined(from otherUserId: String) {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackVoiceCallJoined() from user \(otherUserId)")
        incrementActivity(userId: currentUserId, type: .voiceCallJoined)
    }
    
    /// Track video call initiated
    func trackVideoCallInitiated(to otherUserId: String) {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackVideoCallInitiated() to user \(otherUserId)")
        incrementActivity(userId: currentUserId, type: .videoCallInitiated)
    }
    
    /// Track video call joined
    func trackVideoCallJoined(from otherUserId: String) {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackVideoCallJoined() from user \(otherUserId)")
        incrementActivity(userId: currentUserId, type: .videoCallJoined)
    }
    
    /// Track live session initiated
    func trackLiveSessionInitiated() {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackLiveSessionInitiated()")
        incrementActivity(userId: currentUserId, type: .liveSessionInitiated)
    }
    
    /// Track live session joined
    func trackLiveSessionJoined(hostUserId: String) {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackLiveSessionJoined() host: \(hostUserId)")
        incrementActivity(userId: currentUserId, type: .liveSessionJoined)
    }
    
    /// Track photo sent
    func trackPhotoSent(to otherUserId: String) {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackPhotoSent() to user \(otherUserId)")
        incrementActivity(userId: currentUserId, type: .photoSent)
    }
    
    /// Track photo received
    func trackPhotoReceived(from otherUserId: String) {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackPhotoReceived() from user \(otherUserId)")
        incrementActivity(userId: currentUserId, type: .photoReceived)
    }
    
    /// Track game activity
    func trackGameStarted() {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackGameStarted()")
        incrementActivity(userId: currentUserId, type: .gameStarted)
    }
    
    /// Track game completion
    func trackGameCompleted() {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "trackGameCompleted()")
        incrementActivity(userId: currentUserId, type: .gameCompleted)
    }
    
    /// Update last seen timestamp
    func updateLastSeen() {
        guard let currentUserId = UserSessionManager.shared.userId else { return }
        
        let lastSeenData = [
            "last_seen_at": Date().timeIntervalSince1970
        ]
        
        let ref = Firestore.firestore()
            .collection("Users")
            .document(currentUserId)
            .collection("Profile")
            .document("activity")
        
        ref.setData(lastSeenData, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "updateLastSeen() error: \(error)")
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func trackAccountInteraction(userId: String, otherUserGender: String) {
        if otherUserGender.lowercased() == "male" {
            incrementActivity(userId: userId, type: .maleAccountInteraction)
        } else if otherUserGender.lowercased() == "female" {
            incrementActivity(userId: userId, type: .femaleAccountInteraction)
        }
    }
    
    private func incrementActivity(userId: String, type: ActivityType, by amount: Int = 1) {
        let ref = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("activity")
        
        let updateData: [String: Any] = [
            type.counterName: FieldValue.increment(Int64(amount)),
            "last_activity_at": Date().timeIntervalSince1970
        ]
        
        ref.setData(updateData, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "incrementActivity() error for \(type.counterName): \(error)")
            } else {
                AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "incrementActivity() success for \(type.counterName)")
            }
        }
    }
    
    // MARK: - Batch Operations
    
    /// Initialize activity document for new user
    func initializeActivityDocument(for userId: String, completion: @escaping (Bool) -> Void) {
        let initialData: [String: Any] = [
            "male_accounts_count": 0,
            "female_accounts_count": 0,
            "male_chats_initiated": 0,
            "female_chats_initiated": 0,
            "male_chats_received": 0,
            "female_chats_received": 0,
            "voice_calls_initiated": 0,
            "voice_calls_joined": 0,
            "video_calls_initiated": 0,
            "video_calls_joined": 0,
            "live_sessions_initiated": 0,
            "live_sessions_joined": 0,
            "messages_sent": 0,
            "photos_sent": 0,
            "photos_received": 0,
            "games_started": 0,
            "games_completed": 0,
            "created_at": Date().timeIntervalSince1970,
            "last_activity_at": Date().timeIntervalSince1970
        ]
        
        let ref = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("activity")
        
        ref.setData(initialData) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "initializeActivityDocument() error: \(error)")
                completion(false)
            } else {
                AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "initializeActivityDocument() success")
                completion(true)
            }
        }
    }
    
    /// Get activity statistics for user
    func getActivityStatistics(for userId: String, completion: @escaping ([String: Any]?) -> Void) {
        let ref = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("activity")
        
        ref.getDocument { document, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ActivityTracker", message: "getActivityStatistics() error: \(error)")
                completion(nil)
            } else {
                completion(document?.data())
            }
        }
    }
    
    /// Get user activity summary for profile display
    func getActivitySummary(for userId: String, completion: @escaping (String?) -> Void) {
        getActivityStatistics(for: userId) { data in
            guard let data = data else {
                completion(nil)
                return
            }
            
            let messagesSent = data["messages_sent"] as? Int ?? 0
            let callsInitiated = (data["voice_calls_initiated"] as? Int ?? 0) + (data["video_calls_initiated"] as? Int ?? 0)
            let photosShared = data["photos_sent"] as? Int ?? 0
            
            var summaryParts: [String] = []
            
            if messagesSent > 0 {
                summaryParts.append("\(messagesSent) messages")
            }
            if callsInitiated > 0 {
                summaryParts.append("\(callsInitiated) calls")
            }
            if photosShared > 0 {
                summaryParts.append("\(photosShared) photos")
            }
            
            if summaryParts.isEmpty {
                completion("New to ChatHub")
            } else {
                completion(summaryParts.joined(separator: " • "))
            }
        }
    }
}
