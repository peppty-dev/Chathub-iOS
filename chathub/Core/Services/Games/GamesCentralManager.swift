//
//  GamesCentralManager.swift
//  ChatHub
//
//  Created by Assistant on 2024-12-21.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import UIKit

/// GamesCentralManager - Single source of truth for all games data fetching
/// Replaces scattered fetchGamesIfNeeded calls throughout the app
class GamesCentralManager {
    
    // MARK: - Singleton
    static let shared = GamesCentralManager()
    private init() {
        setupAppLifecycleObservers()
    }
    
    // MARK: - Properties
    private let gamesService = GamesService.shared
    private let gamesDB = GamesDB.shared
    private let sessionManager = SessionManager.shared
    
    // MARK: - State Management
    private var gamesLoadState: GamesLoadState = .notLoaded
    private var lastFetchTime: Date?
    private var isFetching = false
    
    // MARK: - Constants
    private let STALE_DATA_THRESHOLD: TimeInterval = 24 * 60 * 60 // 24 hours
    private let MINIMUM_FETCH_INTERVAL: TimeInterval = 5 * 60 // 5 minutes between fetches
    
    // MARK: - Load State Enum
    enum GamesLoadState {
        case notLoaded        // Never fetched
        case loading          // Currently fetching
        case loaded           // Successfully loaded
        case failed           // Failed to load
        case stale            // Loaded but needs refresh
    }
    
    // MARK: - Public Methods
    
    /// Initialize games data - Called ONLY from AppDelegate
    func initializeGames() {
        AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "initializeGames() Starting centralized games initialization")
        
        // Check current state
        let dbCount = gamesDB.gamescount()
        let fetchStatus = sessionManager.gamesFetched
        
        AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "initializeGames() Current state - DB count: \(dbCount), fetched flag: \(fetchStatus)")
        
        // Determine initial state
        if dbCount > 0 && fetchStatus {
            gamesLoadState = .loaded
            lastFetchTime = Date() // Assume recently fetched if in DB
            AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "initializeGames() Games already available (\(dbCount) games), skipping fetch")
            
            // Log sample game data for debugging
            let sampleGames = gamesDB.query().prefix(3)
            let gameNames = sampleGames.map { $0.GameName }
            AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "initializeGames() Sample games in DB: \(gameNames)")
        } else {
            AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "initializeGames() No games available (count: \(dbCount), fetched: \(fetchStatus)), starting fetch")
            performGamesOrchestration()
        }
    }
    
    /// Ensure games are available - Public interface for the entire app
    func ensureGamesAvailable(completion: @escaping (Bool) -> Void = { _ in }) {
        AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "ensureGamesAvailable() Current state: \(gamesLoadState)")
        
        switch gamesLoadState {
        case .loaded:
            // Games already loaded and fresh
            completion(true)
            
        case .loading:
            // Already fetching, wait for completion
            AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "ensureGamesAvailable() Already fetching, queuing completion")
            // TODO: Could implement completion queue for multiple waiting callers
            completion(true) // For now, assume success
            
        case .notLoaded, .failed, .stale:
            // Need to fetch
            AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "ensureGamesAvailable() Starting fresh fetch")
            performGamesOrchestration(completion: completion)
        }
    }
    
    /// Force refresh games data - Used for user-initiated refresh
    func forceRefreshGames(completion: @escaping (Bool) -> Void = { _ in }) {
        AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "forceRefreshGames() Force refreshing games data")
        
        gamesLoadState = .notLoaded
        sessionManager.gamesFetched = false
        lastFetchTime = nil
        
        performGamesOrchestration(completion: completion)
    }
    
    /// Check if games data is available and fresh
    func areGamesAvailable() -> Bool {
        let dbCount = gamesDB.gamescount()
        let isStateLoaded = (gamesLoadState == .loaded)
        
        AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "areGamesAvailable() DB count: \(dbCount), state: \(gamesLoadState)")
        
        return dbCount > 0 && isStateLoaded
    }
    
    // MARK: - Private Methods
    
    /// Core orchestration method - handles the actual fetching logic
    private func performGamesOrchestration(completion: @escaping (Bool) -> Void = { _ in }) {
        // Prevent multiple simultaneous fetches
        guard !isFetching else {
            AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "performGamesOrchestration() Already fetching, ignoring request")
            completion(false)
            return
        }
        
        // Check minimum interval between fetches
        if let lastFetch = lastFetchTime {
            let timeSinceLastFetch = Date().timeIntervalSince(lastFetch)
            if timeSinceLastFetch < MINIMUM_FETCH_INTERVAL {
                AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "performGamesOrchestration() Too soon since last fetch (\(timeSinceLastFetch)s), skipping")
                completion(true)
                return
            }
        }
        
        isFetching = true
        gamesLoadState = .loading
        lastFetchTime = Date()
        
        AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "performGamesOrchestration() Starting games fetch")
        
        gamesService.fetchAndStoreGames { [weak self] success in
            guard let self = self else { return }
            
            self.isFetching = false
            
            if success {
                self.gamesLoadState = .loaded
                self.sessionManager.gamesFetched = true
                AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "performGamesOrchestration() Games fetch successful")
            } else {
                self.gamesLoadState = .failed
                AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "performGamesOrchestration() Games fetch failed")
            }
            
            completion(success)
        }
    }
    
    /// Check if current data is stale and needs refresh
    private func isDataStale() -> Bool {
        guard let lastFetch = lastFetchTime else { return true }
        
        let timeSinceLastFetch = Date().timeIntervalSince(lastFetch)
        let isStale = timeSinceLastFetch > STALE_DATA_THRESHOLD
        
        if isStale {
            AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "isDataStale() Data is stale (\(timeSinceLastFetch/3600) hours old)")
        }
        
        return isStale
    }
    
    /// Setup app lifecycle observers for smart refreshing
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    /// Handle app becoming active - refresh stale data
    @objc private func appDidBecomeActive() {
        AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "appDidBecomeActive() App became active, checking if refresh needed")
        
        if gamesLoadState == .loaded && isDataStale() {
            AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "appDidBecomeActive() Data is stale, marking for refresh")
            gamesLoadState = .stale
        }
    }
    
    /// Handle app termination - cleanup
    @objc private func appWillTerminate() {
        AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "appWillTerminate() Cleaning up GamesCentralManager")
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Debug/Status Methods
extension GamesCentralManager {
    
    /// Get current status for debugging
    func getStatus() -> String {
        let dbCount = gamesDB.gamescount()
        let fetchFlag = sessionManager.gamesFetched
        let lastFetchText = lastFetchTime?.timeIntervalSinceNow ?? 0
        
        return "State: \(gamesLoadState), DB: \(dbCount), Flag: \(fetchFlag), LastFetch: \(lastFetchText)s ago"
    }
    
    /// Reset games state for testing (debug only)
    func resetForTesting() {
        AppLogger.log(tag: "LOG-APP: GamesCentralManager", message: "resetForTesting() Resetting games state")
        
        gamesLoadState = .notLoaded
        lastFetchTime = nil
        isFetching = false
        sessionManager.gamesFetched = false
        gamesDB.deleteAllGamesFromGamesTable()
    }
}