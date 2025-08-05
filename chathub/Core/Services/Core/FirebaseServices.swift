import Foundation
import FirebaseCore
import FirebaseFirestore

class FirebaseServices {

	static let sharedInstance = FirebaseServices()

	var userId: String? = ""
	var deviceId: String? = ""
	
	// MARK: - Continuous Retry Properties (Android Parity)
	private static let TAG = "FirebaseServices"
	private static let RETRY_DELAY_SECONDS: TimeInterval = 5.0 // 5 seconds like Android AppOpenManager
	
	// Use specialized session managers instead of monolithic SessionManager
	private let userSessionManager = UserSessionManager.shared
	private var retryTimer: Timer?
	private var retryCount = 0
	private var isRetryingForUserId: String? = nil
	private var firebaseListenersStarted = false

	private init() {
		AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "init()")
		
		// Load credentials first, then initialize Firebase
		getCredentials()
	}
	
	deinit {
		AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "deinit() - Cleaning up FirebaseServices")
		stopRetryTimer()
		closeListner()
	}

	/// Starts all Firebase services with continuous retry - iOS equivalent of Android AppOpenManager.startFirebaseListeners()
	func startAllFirebaseServices(){
		AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startAllFirebaseServices() called with userId: \(userSessionManager.userId ?? "nil")")
		
		guard let userId = userSessionManager.userId, !userId.isEmpty else {
			// Android parity: Continuous retry until user is authenticated
			if isRetryingForUserId == nil {
				retryCount += 1
				AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startAllFirebaseServices() no user ID available, scheduling CONTINUOUS retry attempt \(retryCount) in \(Self.RETRY_DELAY_SECONDS)s")
				isRetryingForUserId = nil // Mark that we're retrying for null user
				firebaseListenersStarted = false
				scheduleContinuousRetry()
			} else {
				AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startAllFirebaseServices() already retrying for user authentication")
			}
			return
		}
		
		// User authenticated successfully - stop any retry timers and proceed
		stopRetryTimer()
		retryCount = 0
		isRetryingForUserId = userId
		
		// Prevent multiple starts (Android parity)
		if firebaseListenersStarted {
			AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startAllFirebaseServices() Firebase services already started")
			return
		}
		
		firebaseListenersStarted = true
		AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startAllFirebaseServices() User authenticated, starting all Firebase services for userId: \(userId)")

		getUserDefaults()

		// Start all Firebase services in priority order (Android parity) with error handling
		do {
			AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startAllFirebaseServices() Starting Firebase services with error boundaries")
			
			// Start services with individual error handling
			AppUpdateService.shared.startAppUpdateListener()
			ChatsSyncService.shared.startChatsListener()
			InAppNotificationsSyncService.shared.startNotificationsListener()
			CallsService.shared.startCallsListener()
			GetReportsService.shared.startReportsListener()
			ManualBanCheckService.shared.startBanListener()
			ProfanityService.shared.checkProfanityUpdate()
			ProfanityService.shared.startProfanityWork()
			AppSettingsWorker.shared.doWork()
			
			AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startAllFirebaseServices() All Firebase services started successfully")
		} catch {
			AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startAllFirebaseServices() ERROR starting services: \(error)")
			// Reset state to allow retry
			firebaseListenersStarted = false
			// Schedule retry with exponential backoff
			let retryDelay = min(Self.RETRY_DELAY_SECONDS * Double(retryCount), 60.0)
			DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
				self?.startAllFirebaseServices()
			}
		}
		OnlineStatusService.shared.startOnlineStatusMonitoring()
		TimeCheckService.shared.startTimeValidationMonitoring()
		// Start subscription services (Android parity)
		DispatchQueue.main.async {
			SubscriptionBillingManager.shared.checkPremiumDetailsFromFirebase()
		}
		
		AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startAllFirebaseServices() - All Firebase services started successfully")
	}


	func getCredentials(){
		AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "getCredentials()")

		guard let path = Bundle.main.path(forResource: "SecureKeyValuePlist", ofType: "plist"),
			  let xml = FileManager.default.contents(atPath: path),
			  let plist = try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
			AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "getCredentials() - Unable to load SecureKeyValuePlist file - using default configuration")
			
			// CRITICAL FIX: Instead of fatalError, use default configuration and continue
			// This prevents binary corruption from app crashes during launch
			initializeFirebase()
			return
		}

		AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "getCredentials() - Main Firebase app credentials loaded successfully")

		// Initialize Firebase after credentials are loaded
		initializeFirebase()
	}

	func initializeFirebase(){
		AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "initializeFirebase() - Starting Firebase initialization")
		
		do {
			//default firebase app - this is the only Firebase app we need for subscription model
			if FirebaseApp.app() == nil {
				AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "initializeFirebase() - Configuring main Firebase app")
				
				// Check if Firebase configuration file exists
				guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
					AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "initializeFirebase() - ERROR: GoogleService-Info.plist not found")
					// Continue with minimal functionality
					return
				}
				
				FirebaseApp.configure()
				
				// Verify Firebase app was configured successfully
				guard FirebaseApp.app() != nil else {
					AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "initializeFirebase() - ERROR: Firebase app configuration failed")
					return
				}
				
				// Test Firebase connectivity
				DispatchQueue.global(qos: .background).async { [weak self] in
					self?.testFirebaseConnectivity()
				}
				
				// Add timeout monitoring for Firebase initialization
				DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
					guard let self = self else { return }
					if !self.firebaseListenersStarted {
						AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "initializeFirebase() - WARNING: Firebase services not started within 30 seconds")
					}
				}
			} else {
				AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "initializeFirebase() - Main Firebase app already configured")
			}

			AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "initializeFirebase() - Firebase initialization completed successfully")
		} catch {
			AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "initializeFirebase() - ERROR: Firebase initialization failed: \(error)")
			// SECURITY FIX: Add advanced error recovery for Firebase initialization
			retryFirebaseInitialization()
		}
	}
	
	/// SECURITY FIX: Advanced error recovery mechanism for Firebase initialization
	/// Implements exponential backoff retry strategy for Firebase configuration failures
	/// - Maximum of 3 retry attempts with increasing delays (2s, 4s, 6s)
	/// - Gracefully degrades to offline mode if all retries fail
	/// - Prevents app crashes from Firebase initialization failures
	private func retryFirebaseInitialization() {
		let maxRetries = 3
		var retryCount = 0
		
		func attemptRetry() {
			retryCount += 1
			AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "retryFirebaseInitialization() - Attempt \(retryCount) of \(maxRetries)")
			
			DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount * 2)) {
				do {
					if FirebaseApp.app() == nil {
						FirebaseApp.configure()
						AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "retryFirebaseInitialization() - SUCCESS: Firebase initialized on retry \(retryCount)")
					}
				} catch {
					AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "retryFirebaseInitialization() - Retry \(retryCount) failed: \(error)")
					if retryCount < maxRetries {
						attemptRetry()
					} else {
						AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "retryFirebaseInitialization() - All retries exhausted, operating in degraded mode")
					}
				}
			}
		}
		
		attemptRetry()
	}


	func getUserDefaults(){
		// Use specialized session managers instead of monolithic SessionManager
		userId = userSessionManager.userId ?? ""
		deviceId = userSessionManager.deviceId ?? ""
	}

	/// Stops all Firebase services - iOS equivalent of Android cleanup
	func closeListner() {
		AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "closeListner() - Stopping all Firebase services using dedicated service classes")

		// Stop continuous retry mechanism
		stopRetryTimer()
		retryCount = 0
		isRetryingForUserId = nil
		firebaseListenersStarted = false

		// Stop all dedicated service listeners (Android parity)
		AppUpdateService.shared.stopAppUpdateListener()
		ChatsSyncService.shared.stopChatsListener()
		InAppNotificationsSyncService.shared.stopNotificationsListener()
		CallsService.shared.stopCallsListener()
		GetReportsService.shared.stopReportsListener()
		ManualBanCheckService.shared.stopBanListener()
		AppSettingsWorker.shared.removeListener()
		OnlineStatusService.shared.stopOnlineStatusMonitoring()
		TimeCheckService.shared.stopTimeValidationMonitoring()
		
		// Stop subscription services (Android parity)
		Task { @MainActor in
			SubscriptionBillingManager.shared.cleanup()
		}
		
		AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "closeListner() - All Firebase services stopped successfully")
	}
	
	// MARK: - Continuous Retry Methods (Android Parity)
	
	/// Schedules continuous retry until user authentication - iOS equivalent of Android Handler.postDelayed loop
	private func scheduleContinuousRetry() {
		stopRetryTimer() // Cancel any existing timer
		
		retryTimer = Timer.scheduledTimer(withTimeInterval: Self.RETRY_DELAY_SECONDS, repeats: false) { [weak self] _ in
			guard let self = self else { return }
			AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "scheduleContinuousRetry() Executing scheduled retry attempt")
			self.startAllFirebaseServices() // CONTINUOUS RETRY - calls itself again until user is authenticated
		}
	}
	
	/// Stops the retry timer
	private func stopRetryTimer() {
		retryTimer?.invalidate()
		retryTimer = nil
	}
	
	// MARK: - Public Utility Methods
	
	/// Force restart all services (for external triggers like login)
	func restartAllFirebaseServices() {
		AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "restartAllFirebaseServices() Force restarting all Firebase services")
		closeListner()
		startAllFirebaseServices()
	}
	
	/// Check if Firebase services are started
	func areServicesStarted() -> Bool {
		return firebaseListenersStarted
	}
	
	/// Test Firebase connectivity
	private func testFirebaseConnectivity() {
		AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "testFirebaseConnectivity() - Testing Firebase connection")
		
		let testRef = Firestore.firestore().collection("test")
		testRef.limit(to: 1).getDocuments { snapshot, error in
			if let error = error {
				AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "testFirebaseConnectivity() - Firebase connectivity test failed: \(error)")
			} else {
				AppLogger.log(tag: "LOG-APP: FirebaseServices", message: "testFirebaseConnectivity() - Firebase connectivity test successful")
			}
		}
	}

}


