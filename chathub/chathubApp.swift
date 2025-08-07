//
//  chathubApp.swift
//  chathub
//
//  Created by Akhilesh Nandagiri on 28/07/25.
//

import SwiftUI

@main
struct chathubApp: App {
    // MARK: - Hybrid SwiftUI Lifecycle Architecture
    //
    // This app uses a hybrid approach combining SwiftUI App lifecycle with UIKit AppDelegate:
    // - SwiftUI App: Handles main app structure, state management, and view lifecycle
    // - UIKit AppDelegate: Required for critical iOS services that cannot be migrated:
    //   • Firebase configuration (must be in didFinishLaunchingWithOptions)
    //   • Push notification delegation (FCM MessagingDelegate)
    //   • Complex service initialization with retry mechanisms
    //   • Background timer management for feature cooldowns
    //
    // This follows Apple's recommended migration pattern for apps with complex requirements.
    // See: https://developer.apple.com/documentation/SwiftUI/Migrating-to-the-SwiftUI-life-cycle
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Inject all specialized session managers instead of monolithic SessionManager
    @StateObject private var userSessionManager = UserSessionManager.shared
    @StateObject private var appSettingsSessionManager = AppSettingsSessionManager.shared
    @StateObject private var moderationSettingsSessionManager = ModerationSettingsSessionManager.shared
    @StateObject private var messagingSettingsSessionManager = MessagingSettingsSessionManager.shared
    @StateObject private var subscriptionSessionManager = SubscriptionSessionManager.shared

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(userSessionManager)
                .environmentObject(appSettingsSessionManager)
                .environmentObject(moderationSettingsSessionManager)
                .environmentObject(messagingSettingsSessionManager)
                .environmentObject(subscriptionSessionManager)

        }
    }
}
