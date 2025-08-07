//
//  ConversationLimitManager.swift
//  ChatHub
//
//  Created by AI Assistant on 1/20/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - ConversationLimitCallback Protocol
protocol ConversationLimitCallback {
    func onCanProceed()
    func onShowDialog()
    func onError(_ error: Error)
}

// MARK: - ConversationLimitManager
class ConversationLimitManager: ObservableObject {
    static let shared = ConversationLimitManager()
    
    // Use SessionManager for conversation limits (unified approach)
    private let userSessionManager = UserSessionManager.shared
    private let sessionManager = SessionManager.shared
    private let subscriptionSessionManager = SubscriptionSessionManager.shared
    private var currentDialog: ConversationLimitDialogView? = nil
    private var countdownTimer: Timer? = nil
    private var backgroundTimer: Timer? = nil
    private var isDialogOpen = false
    
    private init() {}
    
    // MARK: - Main Check Method (Android Parity)
    func checkConversationLimitAndProceed(callback: ConversationLimitCallback) {
        AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "checkConversationLimitAndProceed() Starting conversation limit check")
            // Log subscription status for debugging
            let hasLiteAccess = subscriptionSessionManager.hasLiteTierOrHigher()
            let hasPlusAccess = subscriptionSessionManager.hasPlusTierOrHigher()
            let hasProAccess = subscriptionSessionManager.hasProTier()
            let isNewUser = ConversationLimitManagerNew.shared.isNewUser()
            let isActive = subscriptionSessionManager.isSubscriptionActive()
            let tier = subscriptionSessionManager.getSubscriptionTier()
            
            AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "checkConversationLimitAndProceed() Subscription Status - LiteOrHigher: \(hasLiteAccess), PlusOrHigher: \(hasPlusAccess), ProOnly: \(hasProAccess), NewUser: \(isNewUser), Active: \(isActive), Tier: \(tier)")
            
            // Check subscription status first - bypass for Plus+ subscribers and new users
            if hasPlusAccess || isNewUser {
                AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "checkConversationLimitAndProceed() User has Plus+ access or is new user - bypassing conversation limit")
                callback.onCanProceed()
                return
            }
            
            // Check if we're within the conversation limit
            let conversationsStarted = sessionManager.conversationsStartedCount
            let conversationLimit = sessionManager.freeConversationsLimit
            let limitReached = conversationsStarted >= conversationLimit
            
            AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "checkConversationLimitAndProceed() Conversation Count Check - Current: \(conversationsStarted), Limit: \(conversationLimit), Limit Reached: \(limitReached)")
            AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "checkConversationLimitAndProceed() Cooldown Duration: \(sessionManager.freeConversationsCooldownSeconds) seconds")
            
            if !limitReached {
                AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "checkConversationLimitAndProceed() Under conversation limit - proceeding")
                callback.onCanProceed()
                return
            }
            
            // Limit is reached, check cooldown status
            let cooldownStartTimeMillis = sessionManager.conversationLimitCooldownStartTime
            let currentTimeSeconds = Int64(Date().timeIntervalSince1970)
            let cooldownDurationSeconds = sessionManager.freeConversationsCooldownSeconds
            let cooldownStartTimeSeconds = cooldownStartTimeMillis / 1000
            
            AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "checkConversationLimitAndProceed() Cooldown State - Start Time (s): \(cooldownStartTimeSeconds), Current Time (s): \(currentTimeSeconds), Duration (s): \(cooldownDurationSeconds), Has Active Cooldown: \(cooldownStartTimeMillis > 0)")
            
            if cooldownStartTimeMillis > 0 {
                // Check if cooldown is still active (calculations in seconds)
                let elapsedTimeSeconds = currentTimeSeconds - cooldownStartTimeSeconds
                let remainingTimeSeconds = Int64(cooldownDurationSeconds) - elapsedTimeSeconds
                
                AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "checkConversationLimitAndProceed() Active Cooldown Check - Elapsed Time (s): \(elapsedTimeSeconds), Remaining Time (s): \(remainingTimeSeconds), Still Active: \(remainingTimeSeconds > 0)")
                
                if remainingTimeSeconds > 0 {
                    // Cooldown still active, show dialog
                    AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "checkConversationLimitAndProceed() Cooldown active - showing dialog")
                    callback.onShowDialog()
                } else {
                    AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "checkConversationLimitAndProceed() Cooldown finished but wasn't reset? Resetting now.")
                    resetConversationsStartedCount()
                    sessionManager.conversationLimitCooldownStartTime = 0
                    callback.onCanProceed()
                }
            } else {
                // Limit reached, but no active cooldown. Start a new one.
                AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "checkConversationLimitAndProceed() Limit reached, no active cooldown - starting new cooldown")
                startNewCooldown()
                callback.onShowDialog()
            }
    }
    
    // MARK: - Show Dialog Method
    func showConversationLimitDialog() {
        AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "showConversationLimitDialog() Showing dialog")
        
        guard !isDialogOpen else {
            AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "showConversationLimitDialog() Dialog already open")
            return
        }
        
        // Get cooldown state in seconds
        let cooldownStartTimeMillis = sessionManager.conversationLimitCooldownStartTime
        let currentTimeSeconds = Int64(Date().timeIntervalSince1970)
        let cooldownDurationSeconds = sessionManager.freeConversationsCooldownSeconds
        let remainingTimeSeconds: Int64
        let cooldownStartTimeSeconds = cooldownStartTimeMillis / 1000
        
        if cooldownStartTimeMillis > 0 {
            // Use existing cooldown (calculate remaining in seconds)
            remainingTimeSeconds = max(0, Int64(cooldownDurationSeconds) - (currentTimeSeconds - cooldownStartTimeSeconds))
            AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "showConversationLimitDialog() Using existing cooldown: \(remainingTimeSeconds) seconds remaining")
        } else {
            // Start new cooldown (start time stored in millis)
            startNewCooldown()
            remainingTimeSeconds = Int64(cooldownDurationSeconds)
            AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "showConversationLimitDialog() Started new cooldown: \(cooldownDurationSeconds) seconds duration")
        }
        
        // Only show dialog if there's remaining time
        guard remainingTimeSeconds > 0 else {
            AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "showConversationLimitDialog() Cooldown already finished. Not showing dialog.")
            return
        }
        
        isDialogOpen = true
        setupTimers(remainingTimeSeconds: remainingTimeSeconds, totalDurationSeconds: Int64(cooldownDurationSeconds))
    }
    
    // MARK: - Timer Management (Android Parity)
    private func setupTimers(remainingTimeSeconds: Int64, totalDurationSeconds: Int64) {
        AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "setupTimers() Setting up timers - Remaining Time (s): \(remainingTimeSeconds), Total Duration (s): \(totalDurationSeconds)")
        
        // Cleanup any existing timers
        cleanup()
        
        // Setup countdown timer for UI updates (every second)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentTime = Int64(Date().timeIntervalSince1970)
            let cooldownStartTime = self.sessionManager.conversationLimitCooldownStartTime / 1000
            let elapsedTime = currentTime - cooldownStartTime
            let remaining = max(0, totalDurationSeconds - elapsedTime)
            
            // Fix: Use tolerance of 1 second to handle timing precision issues (consistent with other cooldown systems)
            if remaining <= 1 {
                self.completeTimer()
            }
        }
        
        // Background timer to ensure we complete even if UI timer fails (every 1 second for maximum responsiveness)
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentTime = Int64(Date().timeIntervalSince1970)
            let cooldownStartTime = self.sessionManager.conversationLimitCooldownStartTime / 1000
            let elapsedTime = currentTime - cooldownStartTime
            let remaining = max(0, totalDurationSeconds - elapsedTime)
            
            // Fix: Use tolerance of 1 second to handle timing precision issues (consistent with other cooldown systems)
            if remaining <= 1 {
                self.completeTimer()
            }
        }
        
        AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "setupTimers() Timers started")
    }
    
    private func completeTimer() {
        AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "completeTimer() Timer completed")
        
        // Reset conversation count directly
        resetConversationsStartedCount()
        
        // Clear the cooldown start time
        sessionManager.conversationLimitCooldownStartTime = 0
        
        // Cleanup and close dialog
        cleanup()
        isDialogOpen = false
    }
    
    private func startNewCooldown() {
        // Store current time in milliseconds as SessionManager expects it
        let currentTimeMillis = Int64(Date().timeIntervalSince1970 * 1000)
        sessionManager.conversationLimitCooldownStartTime = currentTimeMillis
        
        AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "startNewCooldown() Started new cooldown - Start time (ms): \(currentTimeMillis), Duration (s): \(sessionManager.freeConversationsCooldownSeconds)")
    }
    
    private func cleanup() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        
        AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "cleanup() Cleaned up timers")
    }
    
    // MARK: - Conversation Count Management (Android Parity)
    func resetConversationsStartedCount() {
        sessionManager.conversationsStartedCount = 0
        AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "resetConversationsStartedCount() Reset conversation count to 0")
    }
    
    func incrementConversationsStarted() {
        let currentCount = sessionManager.conversationsStartedCount
        sessionManager.conversationsStartedCount = currentCount + 1
        AppLogger.log(tag: "LOG-APP: ConversationLimitManager", message: "incrementConversationsStarted() Incremented conversation count to: \(currentCount + 1)")
    }
    
    // MARK: - Cleanup
    func onDestroy() {
        cleanup()
        isDialogOpen = false
    }
}

// MARK: - ConversationLimitDialogView (SwiftUI)
struct ConversationLimitDialogView: View {
    @StateObject private var conversationLimitManager = ConversationLimitManager.shared
    @State private var remainingTime: Int64 = 0
    @State private var progress: Double = 0.0
    @State private var timer: Timer? = nil
    
    let totalDuration: Int64
    let onDismiss: () -> Void
    
    init(totalDuration: Int64, onDismiss: @escaping () -> Void) {
        self.totalDuration = totalDuration
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Conversation Limit Reached")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color("dark"))
            
            // Info Text
                                            Text("You've reached the limit of \(SessionManager.shared.freeConversationsLimit) new conversations. Subscribe to ChatHub Plus for unlimited access or wait for the cooldown to expire.")
                .font(.system(size: 16))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Timer Display
            Text("Time remaining: \(formatTime(remainingTime))")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color("dark"))
            
            // Progress Bar
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: Color("plusGradientStart")))
                .frame(height: 8)
                .padding(.horizontal)
            
            // Subscribe Button
            Button(action: {
                // Navigate to subscription
                onDismiss()
            }) {
                Text("SUBSCRIBE TO CHATHUB PLUS")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color("plusGradientStart"), Color("plusGradientEnd")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .padding(24)
        .background(Color("Background Color"))
        .cornerRadius(16)
        .shadow(radius: 10)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        // Calculate initial remaining time
        let currentTime = Int64(Date().timeIntervalSince1970)
                    let cooldownStartTime = SessionManager.shared.conversationLimitCooldownStartTime / 1000
        let elapsedTime = currentTime - cooldownStartTime
        remainingTime = max(0, totalDuration - elapsedTime)
        progress = Double(remainingTime) / Double(totalDuration)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let currentTime = Int64(Date().timeIntervalSince1970)
            let cooldownStartTime = SessionManager.shared.conversationLimitCooldownStartTime / 1000
            let elapsedTime = currentTime - cooldownStartTime
            remainingTime = max(0, totalDuration - elapsedTime)
            progress = Double(remainingTime) / Double(totalDuration)
            
            if remainingTime <= 0 {
                timer?.invalidate()
                onDismiss()
            }
        }
    }
    
    private func formatTime(_ seconds: Int64) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
} 