import UIKit

import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import SQLite3
import BackgroundTasks
import SDWebImage
import StoreKit

var dbURL = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
var dbQuere : OpaquePointer!

// MARK: - Legacy ViewModels (Observable Pattern)
class ChatListViewModel {
	struct UserViewModelWrapper {
		var value: [Chat]? {
			didSet {
				AppLogger.log(tag: "LOG-APP: ChatListViewModel", message: "userViewModel value updated with \(value?.count ?? 0) chats")
				
				// CRITICAL: Post notification for real-time updates (Android LiveData equivalent)
				// This enables ChatsViewModel to react to database changes in real-time
				DispatchQueue.main.async {
					NotificationCenter.default.post(name: .chatTableDataChanged, object: nil)
				}
			}
		}
	}
	
	var userViewModel = UserViewModelWrapper()
}

class InboxTableViewModel {
	struct InboxViewModelWrapper {
		var value: [Chat]? {
			didSet {
				AppLogger.log(tag: "LOG-APP: InboxTableViewModel", message: "InboxViewModel value updated with \(value?.count ?? 0) inbox chats")
				
				// CRITICAL: Post notification for real-time updates (Android LiveData equivalent)
				// This enables ChatsViewModel to react to inbox database changes in real-time
				DispatchQueue.main.async {
					NotificationCenter.default.post(name: .inboxTableDataChanged, object: nil)
				}
			}
		}
	}
	
	var InboxViewModel = InboxViewModelWrapper()
}

var ChatTablemodel = ChatListViewModel()
var InboxTableModel = InboxTableViewModel()

// MARK: - AppDelegate for SwiftUI Hybrid Architecture
//
// This AppDelegate is retained alongside SwiftUI App lifecycle for critical iOS services:
// 1. Firebase configuration - Must be in didFinishLaunchingWithOptions before any Firebase usage
// 2. Background task registration - BGTaskScheduler requires early registration during launch
// 3. Push notifications - FCM MessagingDelegate and APNS registration
// 4. Complex initialization sequences with retry mechanisms
// 5. Database initialization and lifecycle management
//
// This follows Apple's recommended hybrid approach for apps with complex requirements.
// Pure SwiftUI lifecycle migration is not feasible due to timing dependencies.

@objc(AppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {

	let gcmMessageIDKey = "gcm_Message_ID_Key"
	var notificationname = [String]()
	var chatdb : ChatsDB?
	let aiProfileRefreshTaskIdentifier = "com.peppty.ChatApp.aiprofile.refresh"
	// REMOVED: subscriptionSyncTaskIdentifier - now handled by BackgroundTaskManager

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

		// Database optimizations will be handled in lifecycle methods

		// CRITICAL FIX: Configure Firebase FIRST with enhanced error handling
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didFinishLaunchingWithOptions - Configuring Firebase at app launch")
		configureFirebaseWithRetry()
		
		// CRITICAL FIX: Set Firebase Messaging delegate IMMEDIATELY after Firebase configuration
		// This prevents the crash where Firebase tries to call delegate methods before delegate is set
		Messaging.messaging().delegate = self

		// Configure SDWebImage for optimal ChatHub performance
		configureSDWebImage()
		
		// Configure TextEditor transparent background for iOS 14-15 compatibility
		configureTextEditorAppearance()

		SessionManager.shared.userOnline = true

		// Initialize AppLogger after Firebase
		AppLogger.initialize()

		// CRITICAL FIX: Wait for Firebase to be fully configured before starting services
		DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
			// Start Firebase services with continuous retry (Android parity)
			FirebaseServices.sharedInstance.startAllFirebaseServices()
			
			// Initialize app settings worker (Android parity)
			AppSettingsWorker.shared.doWork()
		}

		// CRITICAL FIX: Use centralized DatabaseManager for thread-safe initialization
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didFinishLaunchingWithOptions - Starting centralized database initialization")
		DatabaseManager.shared.initializeDatabase()
		
		// Check if database initialization was successful
		if DatabaseManager.shared.isDatabaseReady() {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didFinishLaunchingWithOptions - Database initialization successful")
		} else {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didFinishLaunchingWithOptions - CRITICAL ERROR: Database initialization failed")
		}

		// Set up notification delegate (without requesting permission)
		// Permission will be requested later when user reaches main view
		AppNotificationPermissionService.shared.setupNotificationDelegate()

		// Initialize AppNotificationService (sets up remote notifications)
		// Note: AppDelegate will remain as the primary MessagingDelegate
		AppNotificationService.shared.setupNotifications()

		// Firebase Messaging delegate already set immediately after configuration (line 87)

		// REMOVED: BackgroundTaskManager - All tasks were redundant with existing real-time listeners and foreground initialization
		// Profanity updates: Called in WelcomeView + LoginView + FirebaseServices
		// Games updates: Called in AppDelegate + GamesTabViewModel  
		// All other tasks: Have real-time Firebase listeners or are unused
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didFinishLaunchingWithOptions - BackgroundTaskManager removed (tasks were redundant)")
		
		// Initialize background timer manager for feature cooldown monitoring
		BackgroundTimerManager.shared.startMonitoring()
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didFinishLaunchingWithOptions - BackgroundTimerManager started for cooldown monitoring")
		
		// CRITICAL FIX: Check for expired cooldowns on app launch (handles app closure scenarios)
		// When app is completely closed and reopened, we need to reset any expired cooldowns
		BackgroundTimerManager.shared.checkAllCooldowns()
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didFinishLaunchingWithOptions - Checked for expired cooldowns on app launch")

		// CRITICAL FIX: Register AI profile refresh background task handler BEFORE scheduling
		registerAIProfileRefreshTask()
		
		// Schedule AI profile refresh background task
		scheduleAIProfileRefresh()

		// Initialize games service with error handling
		initializeGamesService()

		// Initialize subscription system with enhanced error handling
		initializeSubscriptionSystemWithRetry()

		// ANDROID PARITY: Check moderation restrictions on app launch (like Android AppOpenManager)
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didFinishLaunchingWithOptions() - Checking moderation restrictions on launch")
		DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
			ModerationManagerService.shared.checkAndApplyModerationRestrictions()
		}

		#if DEBUG
		// DEBUG: Populate default app settings in Firebase (only in debug builds)
		// COMMENTED OUT: Firebase settings have been populated. Uncomment when needed.
		// DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
		//     AppSettingsDebugPopulator.setupDefaultSettings()
		// }
		#endif

		return true
	}

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }

	// MARK: - Enhanced Firebase Configuration
	
	/// Configure Firebase with retry mechanism and enhanced error handling
	private func configureFirebaseWithRetry(attempt: Int = 1, maxAttempts: Int = 3) {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "configureFirebaseWithRetry() attempt \(attempt)/\(maxAttempts)")
		
		do {
			// Check if Firebase is already configured
			if FirebaseApp.app() == nil {
				AppLogger.log(tag: "LOG-APP: AppDelegate", message: "configureFirebaseWithRetry() configuring main Firebase app")
				FirebaseApp.configure()
				
				// CRITICAL FIX: Verify Firebase configuration
				if let app = FirebaseApp.app() {
					AppLogger.log(tag: "LOG-APP: AppDelegate", message: "configureFirebaseWithRetry() Firebase app configured successfully: \(app.name)")
					
					// CRITICAL FIX: Pre-initialize critical Firebase services
					DispatchQueue.global(qos: .utility).async {
						// Pre-warm Firebase Auth
						let _ = Auth.auth()
						// Pre-warm Firebase Firestore
						let _ = Firestore.firestore()
						AppLogger.log(tag: "LOG-APP: AppDelegate", message: "configureFirebaseWithRetry() Firebase services pre-warmed")
					}
				} else {
					throw NSError(domain: "FirebaseConfig", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase app configuration returned nil"])
				}
			} else {
				AppLogger.log(tag: "LOG-APP: AppDelegate", message: "configureFirebaseWithRetry() Firebase app already configured")
			}
		} catch {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "configureFirebaseWithRetry() attempt \(attempt) failed: \(error.localizedDescription)")
			
			if attempt < maxAttempts {
				// Retry after delay
				DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt)) {
					self.configureFirebaseWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
				}
			} else {
				AppLogger.log(tag: "LOG-APP: AppDelegate", message: "configureFirebaseWithRetry() CRITICAL ERROR: All Firebase configuration attempts failed")
				// Continue with app initialization even if Firebase fails
			}
		}
	}

	// MARK: - Background Task Registration
	
	/// Register AI profile refresh background task handler
	private func registerAIProfileRefreshTask() {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "registerAIProfileRefreshTask() registering handler for identifier: \(aiProfileRefreshTaskIdentifier)")
		
		BGTaskScheduler.shared.register(forTaskWithIdentifier: aiProfileRefreshTaskIdentifier, using: nil) { task in
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "registerAIProfileRefreshTask() background task triggered")
			self.handleAIProfileRefreshTask(task: task as! BGAppRefreshTask)
		}
	}

	// MARK: - Enhanced Service Initialization

	/// Initialize games service with centralized management
	private func initializeGamesService() {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didFinishLaunchingWithOptions() initializing centralized games service")
		
		// CENTRALIZED GAMES FETCHING: Single point of control for all games data
		GamesCentralManager.shared.initializeGames()
	}

	/// Initialize subscription system with retry mechanism
	private func initializeSubscriptionSystemWithRetry(attempt: Int = 1, maxAttempts: Int = 3) {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "initializeSubscriptionSystemWithRetry() attempt \(attempt)/\(maxAttempts)")
		
		do {
			initializeSubscriptionSystem()
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "initializeSubscriptionSystemWithRetry() success on attempt \(attempt)")
		} catch {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "initializeSubscriptionSystemWithRetry() attempt \(attempt) failed: \(error.localizedDescription)")
			
			if attempt < maxAttempts {
				DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt * 2)) {
					self.initializeSubscriptionSystemWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
				}
			} else {
				AppLogger.log(tag: "LOG-APP: AppDelegate", message: "initializeSubscriptionSystemWithRetry() CRITICAL ERROR: All subscription initialization attempts failed")
			}
		}
	}

	func startFirebaseServices(){
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "startFirebaseServices() - Starting Firebase services initialization")

		let userId = SessionManager.shared.userId
		let deviceId = SessionManager.shared.deviceId

		// Firebase is guaranteed to be configured at this point (called after Firebase.configure() in didFinishLaunching)
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "startFirebaseServices() - Firebase app already configured, initializing services")
		
		// Initialize FirebaseServices (will only configure main Firebase app, legacy apps removed)
		let firebaseServices = FirebaseServices.sharedInstance

		if userId != nil , deviceId != nil{
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "startFirebaseServices() - Starting all Firebase services with valid userId and deviceId")
			FirebaseServices.sharedInstance.startAllFirebaseServices()
		}else{
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "startFirebaseServices() - userId or deviceId nil, delegating retry to enhanced FirebaseServices")
			// Delegate continuous retry to enhanced FirebaseServices (Android parity)
			FirebaseServices.sharedInstance.startAllFirebaseServices()
		}
	}

	// MARK: - Subscription System Initialization (Android Parity)
	
	func initializeSubscriptionSystem() {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "initializeSubscriptionSystem() Starting subscription system initialization")
		
		// Initialize SubscriptionsManagerStoreKit2 singleton (StoreKit 2 implementation)
		let subscriptionsManager = SubscriptionsManagerStoreKit2.shared
		
		// Initialize SubscriptionBillingManager for Application context
		SubscriptionBillingManager.shared.initializeForApplication(
			database: Firestore.firestore(),
			sessionManager: SessionManager.shared
		)
		
		// Start SubscriptionListenerManager (Android parity) - This is the key missing piece!
		// This handles continuous retry and proper Firebase listener lifecycle
		SubscriptionListenerManager.shared.startListener()
		
		// Load products from App Store using StoreKit 2
		Task {
			await subscriptionsManager.loadProducts()
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "initializeSubscriptionSystem() StoreKit 2 product loading completed")
			
			// Query existing purchases to check for active subscriptions (Android parity)
			await subscriptionsManager.queryCurrentEntitlements()
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "initializeSubscriptionSystem() Current entitlements query completed")
		}
		
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "initializeSubscriptionSystem() Subscription system initialization completed")
	}

	// REMOVED: setUpNotifications() - notification setup moved to NotificationPermissionService
	// Use NotificationPermissionService.requestPermission() instead

	// REMOVED: showNotificationSettingsAlert() - now handled by NotificationPermissionService

	func scheduleAIProfileRefresh() {
		let request = BGAppRefreshTaskRequest(identifier: aiProfileRefreshTaskIdentifier)
		request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 30) // 30 minutes
		do {
			try BGTaskScheduler.shared.submit(request)
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "scheduleAIProfileRefresh: BGAppRefreshTask scheduled.")
		} catch {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "scheduleAIProfileRefresh: Failed to schedule BGAppRefreshTask: \(error.localizedDescription)")
		}
	}

	func handleAIProfileRefreshTask(task: BGAppRefreshTask) {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "handleAIProfileRefreshTask: Started background fetch for AI/profile updates.")
		scheduleAIProfileRefresh() // Schedule next
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		let operation = AIProfileBackgroundFetchOperation()
		task.expirationHandler = {
			queue.cancelAllOperations()
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "handleAIProfileRefreshTask: Expired.")
		}
		operation.completionBlock = {
			task.setTaskCompleted(success: !operation.isCancelled)
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "handleAIProfileRefreshTask: Completed with success=\(!operation.isCancelled)")
		}
		queue.addOperation(operation)
	}

	// REMOVED: scheduleSubscriptionSync() and handleSubscriptionSyncTask() methods
	// These are now handled by BackgroundTaskManager to prevent duplicate registrations

	func applicationWillTerminate(_ application: UIApplication) {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "applicationWillTerminate() - App terminating")
		
		// ANDROID PARITY: Update Firebase online status when app terminates (like AppOpenManager.setOnlineStatus)
		OnlineStatusService.shared.setUserOffline()
		
		// ANDROID PARITY: Stop all Firebase services when app terminates (like Android onDestroy)
		FirebaseServices.sharedInstance.closeListner()
		
		// Perform final database cleanup
		performFinalDatabaseCleanup()
	}



	//creating mainn database down
	func createChatHubDatabase() -> OpaquePointer? {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "createChatHubDatabase() - Starting database initialization")

		// CRITICAL FIX: Only close if connection is valid
		if dbQuere != nil {
			let closeResult = sqlite3_close(dbQuere)
			if closeResult != SQLITE_OK {
				AppLogger.log(tag: "LOG-APP: AppDelegate", message: "createChatHubDatabase() - Warning: error closing previous database connection")
			} else {
				AppLogger.log(tag: "LOG-APP: AppDelegate", message: "createChatHubDatabase() - Previous database connection closed successfully")
			}
		}
		
		var db : OpaquePointer?
		let url = NSURL(fileURLWithPath: dbURL)
		guard let path = url.appendingPathComponent("ChatHub.sqlite") else {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "createChatHubDatabase() - Failed to create database path")
			return nil
		}
		
		let fileComponent = path.path
		let openResult = sqlite3_open(fileComponent, &db)
		
		if openResult == SQLITE_OK {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "createChatHubDatabase() - Database opened successfully at \(fileComponent)")
			
			// Enable optimizations for better performance and corruption resistance
			sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
			sqlite3_exec(db, "PRAGMA synchronous = NORMAL;", nil, nil, nil)
			sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
			sqlite3_exec(db, "PRAGMA cache_size = 10000;", nil, nil, nil)
			sqlite3_exec(db, "PRAGMA temp_store = MEMORY;", nil, nil, nil)
			
			return db
		} else {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "createChatHubDatabase() - Failed to open database at \(fileComponent): \(String(cString: sqlite3_errmsg(db)))")
			return nil
		}
	}
	//creating main database up

	//notifications down
	//This function is called whenever a new FCM registration token is generated. The fcmToken parameter contains the new token.
	func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
		guard let fcmToken = fcmToken else { 
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didReceiveRegistrationToken() FCM token was nil")
			return 
		}
		
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didReceiveRegistrationToken() FCM token received - deferring update until user grants notification permission")
		
		// CLEANER APPROACH: Only update FCM token after user grants permission
		// This prevents premature token updates before user consent
		
		// Still notify AppNotificationService for token management (without database update)
		AppNotificationService.shared.handleReceivedRegistrationToken(fcmToken)
		
		// Keep legacy notification for backward compatibility
		let dataDict: [String: String] = ["token": fcmToken]
		NotificationCenter.default.post(
			name: Notification.Name("FCMToken"),
			object: nil,
			userInfo: dataDict
		)
		
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didReceiveRegistrationToken() FCM token cached but not saved - waiting for user permission")
	}
	
	//CRITICAL FIX: This function is called when FCM receives a message from Firebase Cloud Functions
	//This is the iOS equivalent to Android FirebaseMessagingService.onMessageReceived()
	//ARCHITECTURAL IMPROVEMENT: Delegate all processing to AppNotificationService for centralized handling
	func messaging(_ messaging: Messaging, didReceive remoteMessage: [AnyHashable: Any]) {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "messaging didReceive() FCM message received - delegating to AppNotificationService")
		
		// CLEAN ARCHITECTURE: Delegate all FCM message processing to AppNotificationService
		// This keeps AppDelegate minimal and centralizes notification logic
		AppNotificationService.shared.handleFCMMessage(remoteMessage)
	}

	//This function is called when the app receives a remote notification. It can handle the notification payload and perform a background fetch if needed.
	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didReceiveRemoteNotification() received remote notification")

		if let messageID = userInfo[gcmMessageIDKey] {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didReceiveRemoteNotification() Message ID: \(messageID)")
		}

		if let userId = SessionManager.shared.userId,
		   let deviceId = SessionManager.shared.deviceId {
			
			if let notificationType = userInfo["notif_type"] as? String,
			   notificationType == "kick",
			   let userMessage = userInfo["notif_body"] as? String,
			   let bannedUserId = userInfo["notif_kicked_id"] as? String {
				
				if(bannedUserId == userId){
					// ... existing notification handling code ...
				}
			}
		}

		return UIBackgroundFetchResult.newData
	}

	//This function is called when the app successfully registers with Apple Push Notification Service (APNs) and receives a device token.
	func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didRegisterForRemoteNotificationsWithDeviceToken() APNS registration successful")
		Messaging.messaging().apnsToken = deviceToken
	}
	
	//This function is called when the app fails to register with Apple Push Notification Service (APNs).
	func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didFailToRegisterForRemoteNotificationsWithError() APNS registration failed: \(error.localizedDescription)")
		
		// iOS CRITICAL FIX: Even if APNS fails, we should still allow FCM to work in limited capacity
		// This ensures account creation can still proceed
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "didFailToRegisterForRemoteNotificationsWithError() FCM will work in limited capacity without APNS")
	}
	//notifications up

	//coredata down
	// MARK: - Core Data Removed
	// CoreData has been migrated to UserDefaults and SQLite for better performance
	// and Android parity. All data is now stored using SessionManager.
	//coredata removed

	// MARK: - SDWebImage Configuration
	private func configureSDWebImage() {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "configureSDWebImage() starting configuration")
		
		// Configure cache limits optimized for chat app with profile images
		SDImageCache.shared.config.maxMemoryCost = 100 * 1024 * 1024  // 100MB memory cache
		SDImageCache.shared.config.maxDiskSize = 200 * 1024 * 1024    // 200MB disk cache
		SDImageCache.shared.config.maxDiskAge = 7 * 24 * 60 * 60      // 7 days cache expiration
		
		// Configure memory cache behavior
		SDImageCache.shared.config.shouldCacheImagesInMemory = true    // Enable memory caching
		SDImageCache.shared.config.diskCacheWritingOptions = [.atomic] // Atomic disk writes
		
		// Configure download behavior
		SDWebImageDownloader.shared.config.downloadTimeout = 30.0     // 30 second timeout
		SDWebImageDownloader.shared.config.maxConcurrentDownloads = 6  // Max 6 concurrent downloads
		
		// Set HTTP headers for better compatibility
		SDWebImageDownloader.shared.setValue("image/webp,image/apng,image/jpeg,image/png,image/*,*/*;q=0.8", 
											forHTTPHeaderField: "Accept")
		SDWebImageDownloader.shared.setValue("ChatHub/1.0", forHTTPHeaderField: "User-Agent")
		
		// Configure for better chat app performance
		SDWebImageManager.shared.optionsProcessor = SDWebImageOptionsProcessor { (url, options, context) in
			// Add retry logic for failed image loads
			var newOptions = options
			newOptions.insert(.retryFailed)
			newOptions.insert(.continueInBackground)
			return SDWebImageOptionsResult(options: newOptions, context: context)
		}
		
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "configureSDWebImage() configuration completed successfully")
	}
	
	// MARK: - TextEditor Appearance Configuration
	private func configureTextEditorAppearance() {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "configureTextEditorAppearance() starting configuration for iOS 14-15 compatibility")
		
		// Configure UITextView appearance for transparent background (iOS 14-15 compatibility)
		// This ensures TextEditor has transparent background across all iOS versions
		UITextView.appearance().backgroundColor = UIColor.clear
		
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "configureTextEditorAppearance() configuration completed successfully")
	}

	// MARK: - Database Lifecycle Management
	
	func applicationDidEnterBackground(_ application: UIApplication) {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "applicationDidEnterBackground() - App entering background")
		
		// Schedule database maintenance when app goes to background
		scheduleBackgroundDatabaseMaintenance()
		
		// Cleanup database connections to free resources
		cleanupDatabaseResources()
	}
	
	func applicationWillEnterForeground(_ application: UIApplication) {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "applicationWillEnterForeground() - App entering foreground")
		
		// Ensure database is ready when app comes back
		ensureDatabaseReady()
		
		// ANDROID PARITY: Check and apply moderation restrictions like Android AppOpenManager
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "applicationWillEnterForeground() - Checking moderation restrictions")
		ModerationManagerService.shared.checkAndApplyModerationRestrictions()
	}
	

	
	// MARK: - Database Maintenance Scheduling
	
	private func scheduleBackgroundDatabaseMaintenance() {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "scheduleBackgroundDatabaseMaintenance() - Scheduling background tasks")
		
		// Schedule WAL checkpoint in background
		DispatchQueue.global(qos: .background).async {
			DatabaseManager.shared.scheduleBackgroundCheckpoint()
		}
		
		// Schedule maintenance if device has been idle
		let lastMaintenanceTime = UserDefaults.standard.double(forKey: "lastDatabaseMaintenanceTime")
		let currentTime = Date().timeIntervalSince1970
		let maintenanceInterval: TimeInterval = 24 * 60 * 60 // 24 hours
		
		if currentTime - lastMaintenanceTime > maintenanceInterval {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "scheduleBackgroundDatabaseMaintenance() - Scheduling database maintenance")
			
			DispatchQueue.global(qos: .background).async {
				DatabaseManager.shared.performMaintenanceWhenIdle()
				UserDefaults.standard.set(currentTime, forKey: "lastDatabaseMaintenanceTime")
				UserDefaults.standard.synchronize()
			}
		} else {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "scheduleBackgroundDatabaseMaintenance() - Skipping maintenance, too recent")
		}
		
		// Schedule chat table maintenance
		DispatchQueue.global(qos: .background).async {
			if let chatDB = DatabaseManager.shared.getChatDB() {
				chatDB.performMaintenance()
			}
		}
	}
	
	private func cleanupDatabaseResources() {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "cleanupDatabaseResources() - Cleaning up database resources")
		
		DispatchQueue.global(qos: .background).async {
			// Clean up prepared statement cache to free memory
			DatabaseManager.shared.cleanupPreparedStatements()
			
			// Clean up connection pool
			DatabaseManager.shared.cleanupConnectionPool()
		}
	}
	
	private func ensureDatabaseReady() {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "ensureDatabaseReady() - Ensuring database is ready")
		
		if !DatabaseManager.shared.isDatabaseReady() {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "ensureDatabaseReady() - Database not ready, reinitializing")
			DatabaseManager.shared.initializeDatabase()
		} else {
			AppLogger.log(tag: "LOG-APP: AppDelegate", message: "ensureDatabaseReady() - Database is ready")
		}
	}
	
	private func performFinalDatabaseCleanup() {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "performFinalDatabaseCleanup() - Performing final cleanup")
		
		// Perform final checkpoint to ensure data is saved
		DatabaseManager.shared.scheduleBackgroundCheckpoint()
		
		// Clean up all resources
		DatabaseManager.shared.cleanupPreparedStatements()
		DatabaseManager.shared.cleanupConnectionPool()
		
		// Log performance statistics
		logDatabasePerformanceStats()
	}
	
	private func logDatabasePerformanceStats() {
		AppLogger.log(tag: "LOG-APP: AppDelegate", message: "logDatabasePerformanceStats() - Logging final performance statistics")
		
		// Log some common query performance stats
		let commonQueries = [
			"SELECT * FROM ChatTable ORDER BY LastTimeStamp DESC",
			"SELECT * FROM OnlineUsers",
			"INSERT OR REPLACE INTO ChatTable"
		]
		
		for query in commonQueries {
			if let stats = DatabaseManager.shared.getQueryPerformanceStats(query: query) {
				AppLogger.log(tag: "LOG-APP: AppDelegate", message: "logDatabasePerformanceStats() - Query '\(query.prefix(50))...': avg=\(String(format: "%.4f", stats.average))s, max=\(String(format: "%.4f", stats.max))s, count=\(stats.count)")
			}
		}
	}

}

// REMOVED: UNUserNotificationCenterDelegate extension - now handled by NotificationPermissionService
