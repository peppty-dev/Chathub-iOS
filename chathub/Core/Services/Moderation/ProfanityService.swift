import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// ProfanityService - iOS equivalent of Android ProfanityWorker
/// Responsible for fetching and managing profanity word lists from Firebase
/// Does NOT handle filtering - that's handled by separate ProfanityClass equivalent
class ProfanityService {
    
    // MARK: - Singleton
    static let shared = ProfanityService()
    private init() {
        // Use specialized session managers instead of monolithic SessionManager
        userSessionManager = UserSessionManager.shared
        moderationSettingsSessionManager = ModerationSettingsSessionManager.shared
        getCredentials()
    }
    
    // MARK: - Properties (Android Parity) - Use specialized managers
    private let userSessionManager: UserSessionManager
    private let moderationSettingsSessionManager: ModerationSettingsSessionManager
    
    private var firebaseAppProfanity: FirebaseApp?
    private var firebaseFirestoreProfanity: Firestore?
    private var firebaseAuth: Auth?
    private var firebaseUser: User?
    
    private var profanityProjectId: String = ""
    private var profanityApplicationId: String = ""
    private var profanityApiKey: String = ""
    private var profanityStorageBucket: String = ""
    
    // MARK: - Public Methods (Android Parity)
    
    /// Starts profanity worker - Android doWork() equivalent
    func startProfanityWork() {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "startProfanityWork() starting profanity worker")
        
        initializeProfanityFirebase()
    }
    
    /// Checks for profanity update - equivalent to FirebaseServices.checkProfanityUpdate()
    func checkProfanityUpdate() {
        // Replace Welcome CoreData entity with UserDefaults
        let lastProfanityCheck = UserDefaults.standard.object(forKey: "last_profanity_check") as? Date ?? Date.distantPast
        let oneHourLater = Calendar.current.date(byAdding: .hour, value: 1, to: lastProfanityCheck) ?? Date()
        
        if Date() > oneHourLater {
            badwords()
        }
    }
    
    /// Handles profanity word fetching - equivalent to FirebaseServices.badwords()
    func badwords() {
        // CRITICAL FIX: Ensure Firebase is initialized before proceeding
        if firebaseAppProfanity == nil {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "badwords() Firebase app not initialized, initializing now")
            initializeProfanityFirebase()
            return
        }
        
        guard let app = firebaseAppProfanity else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "badwords() Firebase app still not initialized after initialization attempt")
            return
        }
        
        // ENHANCEMENT: Validate Firebase app still exists before accessing Auth
        guard validateFirebaseAppExists() else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "badwords() Firebase app validation failed, reinitializing")
            initializeProfanityFirebase()
            return
        }
        
        let fireuser = Auth.auth(app: app).currentUser
        
        if fireuser == nil {
            Auth.auth(app: app).signInAnonymously { authResult, error in
                if error == nil {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "badwords() Anonymous sign-in successful, checking profanity version")
                    self.checkProfanityVersion()
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "badwords() Anonymous sign-in failed: \(error?.localizedDescription ?? "unknown")")
                }
            }
        } else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "badwords() User already authenticated, checking profanity version")
            checkProfanityVersion()
        }
    }
    
    /// Checks profanity version and updates if needed - equivalent to FirebaseServices.checkProfanityVersion()
    func checkProfanityVersion() {
        // ENHANCEMENT: Validate Firebase app exists before proceeding
        guard validateFirebaseAppExists() else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkProfanityVersion() Firebase app validation failed, attempting reinitialization")
            initializeProfanityFirebase()
            return
        }
        
        guard let firestore = firebaseFirestoreProfanity else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkProfanityVersion() Firestore not initialized")
            return
        }
        
        firestore.collection("Versions")
            .document("Words_version")
            .getDocument { [self] (document, error) in
                if let document = document, document.exists {
                    guard let dataDescription = document.data() else { return }
                    let version = dataDescription["Words_version"] as? Int16 ?? 0
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkProfanityVersion: Words_version from Firestore: \(version)")

                    let defaults = UserDefaults.standard
                    let lastFetchedAppNamesVersion = defaults.integer(forKey: "profanityAppNamesVersion")

                    // Replace WordsVersion CoreData entity with UserDefaults
                    let storedVersion = defaults.integer(forKey: "profanity_words_version")
                    
                    if storedVersion == 0 {
                        // No stored version, fetch everything
                        defaults.set(Int(version), forKey: "profanity_words_version")
                        self.getProfanityWords()
                        self.getProfanityAppNames(newGeneralWordsVersion: version)
                    } else {
                        let ver = Int16(storedVersion)
                        if version > ver {
                            self.getProfanityWords()
                            self.getProfanityAppNames(newGeneralWordsVersion: version)
                            defaults.set(Int(version), forKey: "profanity_words_version")
                        } else if moderationSettingsSessionManager.profanityAppNameWords == nil {
                            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkProfanityVersion: General profanity words up-to-date (version \(ver)), but App Names list missing. Fetching App Names.")
                            self.getProfanityAppNames(newGeneralWordsVersion: ver)
                        } else if version > lastFetchedAppNamesVersion {
                            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkProfanityVersion: App Names list (version \(lastFetchedAppNamesVersion)) is older than current Words_version (\(version)). Fetching App Names.")
                            self.getProfanityAppNames(newGeneralWordsVersion: version)
                        } else {
                            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkProfanityVersion: All profanity lists are up-to-date (version \(version)).")
                        }
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkProfanityVersion: Words_version document not found.")
                    // Attempt to fetch if no local lists exist at all
                    if moderationSettingsSessionManager.profanityAppNameWords == nil {
                        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkProfanityVersion: No local App Names list. Attempting fetch with version 0.")
                        self.getProfanityAppNames(newGeneralWordsVersion: 0)
                    }
                    // Check if we have any stored profanity words
                    let storedVersion = UserDefaults.standard.integer(forKey: "profanity_words_version")
                    if storedVersion == 0 {
                        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkProfanityVersion: No local general words. Attempting fetch.")
                        self.getProfanityWords()
                    }
                }
            }
    }
    
    /// Gets profanity app names - equivalent to FirebaseServices.getProfanityAppNames()
    func getProfanityAppNames(newGeneralWordsVersion: Int16) {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityAppNames: Attempting to fetch Words/WordsAppNames. Using general words version: \(newGeneralWordsVersion)")
        
        // ENHANCEMENT: Validate Firebase app exists before proceeding
        guard validateFirebaseAppExists() else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityAppNames: Firebase app validation failed")
            return
        }
        
        guard let firestore = firebaseFirestoreProfanity else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityAppNames: Firestore not initialized")
            return
        }
        
        firestore.collection("Words")
            .document("AppNames")
            .getDocument { [self] (document, error) in
                if error != nil {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityAppNames: Error fetching AppNames: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                if let document = document, document.exists {
                    guard let dataDescription = document.data() else {
                        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityAppNames: AppNames document data is nil.")
                        return
                    }
                    let appNamesList = dataDescription["list"] as? [String] ?? []
                    
                    // Store as JSON format to match what ProfanityClass expects
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: appNamesList, options: [])
                        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                        moderationSettingsSessionManager.profanityAppNameWords = jsonString
                        moderationSettingsSessionManager.profanityAppNameWordsVersion = Int64(newGeneralWordsVersion)
                        userSessionManager.synchronize()
                        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityAppNames: Successfully fetched and stored \(appNamesList.count) app names. Associated with Words_version: \(newGeneralWordsVersion)")
                        
                        // Notify ProfanityClass to refresh its word sets - Android parity
                        DispatchQueue.main.async {
                            ProfanityClass.share.refreshProfanityWords()
                        }
                    } catch {
                        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityAppNames: JSON serialization error: \(error.localizedDescription)")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityAppNames: AppNames document does not exist.")
                    moderationSettingsSessionManager.profanityAppNameWords = nil
                    moderationSettingsSessionManager.profanityAppNameWordsVersion = 0
                    userSessionManager.synchronize()
                }
            }
    }
    
    /// Gets profanity words - equivalent to FirebaseServices.getProfanityWords()
    func getProfanityWords() {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityWords() - Fetching profanity words from Firebase")
        
        // ENHANCEMENT: Validate Firebase app exists before proceeding
        guard validateFirebaseAppExists() else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityWords() Firebase app validation failed")
            return
        }
        
        guard let firestore = firebaseFirestoreProfanity else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityWords() - Firestore not initialized")
            return
        }
        
        firestore.collection("Words")
            .document("Words")
            .getDocument { [self] (document, error) in
                if error != nil {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityWords() - Error fetching words: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                if let document = document, document.exists {
                    guard let dataDescription = document.data() else {
                        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityWords() - Document data is nil")
                        return
                    }
                    
                    let badword = dataDescription["list"] as? [String] ?? []
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityWords() - Fetched \(badword.count) profanity words")
                    
                    // Store in SessionManager like the existing implementation
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: badword, options: [])
                        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                        moderationSettingsSessionManager.profanityWords = jsonString
                        
                        // Update last profanity check time
                        UserDefaults.standard.set(Date(), forKey: "last_profanity_check")
                        
                        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityWords() - Successfully saved \(badword.count) words to SessionManager")
                        
                        // Notify ProfanityClass to refresh its word sets - Android parity
                        DispatchQueue.main.async {
                            ProfanityClass.share.refreshProfanityWords()
                        }
                    } catch {
                        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityWords() - JSON serialization error: \(error.localizedDescription)")
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityWords() - Words document does not exist")
                }
            }
    }
    
    /// Gets the profanity Firebase app instance for other classes that need it
    func getProfanityFirebaseApp() -> FirebaseApp? {
        // ENHANCEMENT: Validate Firebase app exists before returning it
        guard validateFirebaseAppExists() else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getProfanityFirebaseApp() Firebase app validation failed")
            return nil
        }
        
        return firebaseAppProfanity
    }
    
    // MARK: - Private Methods (Android Parity)
    
    /// Validates that the profanity Firebase app still exists and reinitializes if needed
    private func validateFirebaseAppExists() -> Bool {
        // Check if our local reference exists
        guard firebaseAppProfanity != nil else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "validateFirebaseAppExists() Local Firebase app reference is nil")
            return false
        }
        
        // Check if the Firebase app still exists in Firebase's registry
        guard FirebaseApp.app(name: "profanity") != nil else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "validateFirebaseAppExists() Firebase app 'profanity' no longer exists in registry")
            // Reset all references
            firebaseAppProfanity = nil
            firebaseAuth = nil
            firebaseUser = nil
            firebaseFirestoreProfanity = nil
            moderationSettingsSessionManager.profanityFirebaseInitialized = false
            return false
        }
        
        return true
    }
    
    /// Gets credentials from assets - Android getCredentials() equivalent
    private func getCredentials() {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getCredentials() loading credentials from SecureKeyValuePlist.plist")
        
        guard let path = Bundle.main.path(forResource: "SecureKeyValuePlist", ofType: "plist") else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getCredentials() ❌ Unable to find SecureKeyValuePlist.plist file in bundle")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getCredentials() ✅ Found plist file at path: \(path)")
        
        guard let xml = FileManager.default.contents(atPath: path) else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getCredentials() ❌ Unable to read contents of SecureKeyValuePlist.plist file")
            return
        }
        
        guard let plist = try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getCredentials() ❌ Unable to parse SecureKeyValuePlist.plist file")
            return
        }
        
        // Load profanity Firebase app credentials from plist (same keys as FirebaseServices)
        profanityApplicationId = plist["profanityGoogleAppID"] as? String ?? ""
        profanityProjectId = plist["profanityProjectID"] as? String ?? ""
        profanityApiKey = plist["profanityApiKey"] as? String ?? ""
        profanityStorageBucket = plist["profanityStorageBucket"] as? String ?? ""
        
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getCredentials() ✅ Loaded credentials - AppID: '\(profanityApplicationId)', ProjectID: '\(profanityProjectId)', ApiKey: '\(profanityApiKey.isEmpty ? "empty" : "loaded")', StorageBucket: '\(profanityStorageBucket)'")
        
        if profanityApplicationId.isEmpty || profanityProjectId.isEmpty || profanityApiKey.isEmpty {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getCredentials() ⚠️ Warning: Some credentials are empty")
        } else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getCredentials() ✅ All required credentials loaded successfully")
        }
    }
    
    /// Initializes profanity Firebase - Android initializeProfanityFirebase() equivalent
    private func initializeProfanityFirebase() {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "initializeProfanityFirebase() initializing Firebase")
        
        // CRITICAL FIX: Check if credentials are loaded first
        if profanityApplicationId.isEmpty || profanityProjectId.isEmpty || profanityApiKey.isEmpty {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "initializeProfanityFirebase() ❌ Missing credentials - cannot initialize Firebase")
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "initializeProfanityFirebase() AppID: '\(profanityApplicationId)', ProjectID: '\(profanityProjectId)', ApiKey: '\(profanityApiKey.isEmpty ? "empty" : "loaded")'")
            return
        }
        
        // CRITICAL FIX: Use VAdEnhancer pattern - check if app exists before creating
        if FirebaseApp.app(name: "profanity") == nil {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "initializeProfanityFirebase() Creating new Firebase app")
            
            // Create Firebase options
            let options = FirebaseOptions(
                googleAppID: profanityApplicationId,
                gcmSenderID: ""
            )
            options.projectID = profanityProjectId
            options.apiKey = profanityApiKey
            options.storageBucket = profanityStorageBucket
            
            // Configure Firebase app
            FirebaseApp.configure(name: "profanity", options: options)
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "initializeProfanityFirebase() ✅ Firebase app configured successfully")
        } else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "initializeProfanityFirebase() ✅ Firebase app already exists")
        }
        
        // Get the Firebase app instance
        firebaseAppProfanity = FirebaseApp.app(name: "profanity")
        
        if let app = firebaseAppProfanity {
            firebaseFirestoreProfanity = Firestore.firestore(app: app)
            moderationSettingsSessionManager.profanityFirebaseInitialized = true
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "initializeProfanityFirebase() ✅ Firebase services initialized successfully")
            login()
        } else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "initializeProfanityFirebase() ❌ Failed to get Firebase app instance")
        }
    }
    
    /// Firebase login - Android login() equivalent
    private func login() {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "login() starting Firebase auth")
        
        guard let app = firebaseAppProfanity else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "login() Firebase app not initialized")
            return
        }
        
        // ENHANCEMENT: Validate Firebase app still exists before accessing Auth
        guard validateFirebaseAppExists() else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "login() Firebase app validation failed, cannot proceed with auth")
            return
        }
        
        firebaseAuth = Auth.auth(app: app)
        firebaseUser = firebaseAuth?.currentUser
        
        if firebaseUser == nil {
            firebaseAuth?.signInAnonymously { [weak self] (authResult, error) in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "signInAnonymously:failure \(error.localizedDescription)")
                    
                    DispatchQueue.main.async {
                        // Show error message if needed
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "signInAnonymously:success")
                    
                    self?.firebaseUser = self?.firebaseAuth?.currentUser
                    self?.checkWordsVersion()
                }
            }
        } else {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "firebase current userid = \(firebaseUser?.uid ?? "")")
            checkWordsVersion()
        }
    }
    
    /// Checks words version - Android checkWordsVersion() equivalent
    private func checkWordsVersion() {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkWordsVersion() \(moderationSettingsSessionManager.profanityWords ?? "nil")")
        
        firebaseFirestoreProfanity?.collection("Versions")
            .document("Words_version")
            .getDocument { [weak self] (document, error) in
                if let document = document, document.exists {
                    // ANDROID PARITY: Check for "Words_version" field like Android
                    if document.data()?.keys.contains("Words_version") == true {
                        if let wordsVersion = document.data()?["Words_version"] as? Int64 {
                            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkWordsVersion \(wordsVersion)")
                            
                            if self?.moderationSettingsSessionManager.profanityWordsVersion ?? 0 < wordsVersion || self?.moderationSettingsSessionManager.profanityWords == nil {
                                self?.getWords()
                                self?.moderationSettingsSessionManager.profanityWordsVersion = wordsVersion
                            }
                        }
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "checkWordsVersion error: \(error?.localizedDescription ?? "unknown")")
                }
            }
    }
    
    /// Gets words from Firebase - Android getWords() equivalent
    private func getWords() {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getWords() fetching profanity words")
        
        // ANDROID PARITY: Get regular profanity words with comprehensive error handling
        firebaseFirestoreProfanity?.collection("Words")
            .document("Words")
            .getDocument { [weak self] (document, error) in
                if error == nil {
                    if let document = document, document.exists {
                        if document.data()?.keys.contains("list") == true {
                            if let wordsList = document.data()?["list"] as? [String] {
                                AppLogger.log(tag: "LOG-APP: ProfanityService", message: "profanity \(wordsList)")
                                
                                // ANDROID PARITY: Store JSON directly like Android
                                do {
                                    let jsonData = try JSONSerialization.data(withJSONObject: wordsList, options: [])
                                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                                    self?.moderationSettingsSessionManager.profanityWords = jsonString
                                    
                                    // Process and clean the words (Android parity)
                                    self?.processProfanityWords(wordsList)
                                    
                                    // Notify ProfanityClass to refresh its word sets - Android parity
                                    DispatchQueue.main.async {
                                        ProfanityClass.share.refreshProfanityWords()
                                    }
                                } catch {
                                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getWords() JSON error: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "profanity failed")
                }
            }
        
        // ANDROID PARITY: Get app name profanity words with comprehensive error handling
        firebaseFirestoreProfanity?.collection("Words")
            .document("AppNames")
            .getDocument { [weak self] (document, error) in
                if error == nil {
                    if let document = document, document.exists {
                        if document.data()?.keys.contains("list") == true {
                            if let wordsList = document.data()?["list"] as? [String] {
                                AppLogger.log(tag: "LOG-APP: ProfanityService", message: "profanity AppNames \(wordsList)")
                                
                                // ANDROID PARITY: Store JSON directly like Android
                                do {
                                    let jsonData = try JSONSerialization.data(withJSONObject: wordsList, options: [])
                                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                                    self?.moderationSettingsSessionManager.profanityAppNameWords = jsonString
                                    
                                    // Process and clean the app name words (Android parity)
                                    self?.processProfanityAppNameWords(wordsList)
                                    
                                    // Notify ProfanityClass to refresh its word sets - Android parity
                                    DispatchQueue.main.async {
                                        ProfanityClass.share.refreshProfanityWords()
                                    }
                                } catch {
                                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "getWords() AppNames JSON error: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfanityService", message: "profanity AppNames failed")
                }
            }
    }
    
    /// Processes profanity words - Android equivalent logic
    private func processProfanityWords(_ wordsList: [String]) {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "profanity \(wordsList.count)")
        
        // Remove duplicates using Set
        let uniqueWords = Array(Set(wordsList))
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "profanity \(uniqueWords.count)")
        
        // Sort by length (longest first) - Android parity
        let sortedWords = uniqueWords.sorted { $0.count > $1.count }
        
        // Store processed words
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sortedWords, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            moderationSettingsSessionManager.profanityWords = jsonString
            
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "profanity \(moderationSettingsSessionManager.profanityWords ?? "")")
            
            // Notify ProfanityClass to refresh its word sets - Android parity
            DispatchQueue.main.async {
                ProfanityClass.share.refreshProfanityWords()
            }
        } catch {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "processProfanityWords() JSON error: \(error.localizedDescription)")
        }
    }
    
    /// Processes app name profanity words - Android equivalent logic
    private func processProfanityAppNameWords(_ wordsList: [String]) {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "profanity AppNames \(wordsList.count)")
        
        // Remove duplicates using Set
        let uniqueWords = Array(Set(wordsList))
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "profanity AppNames \(uniqueWords.count)")
        
        // Sort by length (longest first) - Android parity
        let sortedWords = uniqueWords.sorted { $0.count > $1.count }
        
        // Store processed words
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sortedWords, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            moderationSettingsSessionManager.profanityAppNameWords = jsonString
            
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "profanity AppNames \(moderationSettingsSessionManager.profanityAppNameWords ?? "")")
            
            // Notify ProfanityClass to refresh its word sets - Android parity
            DispatchQueue.main.async {
                ProfanityClass.share.refreshProfanityWords()
            }
        } catch {
            AppLogger.log(tag: "LOG-APP: ProfanityService", message: "processProfanityAppNameWords() JSON error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup Methods
    
    /// Cleans up Firebase app and resets state - called during account removal
    /// This prevents the duplicate Firebase app configuration issue
    func cleanupFirebaseApp() {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "cleanupFirebaseApp() starting cleanup")
        
        // Sign out from Firebase auth if needed
        if let auth = firebaseAuth {
            do {
                try auth.signOut()
                AppLogger.log(tag: "LOG-APP: ProfanityService", message: "cleanupFirebaseApp() Firebase auth signed out")
            } catch {
                AppLogger.log(tag: "LOG-APP: ProfanityService", message: "cleanupFirebaseApp() Firebase auth sign out error: \(error.localizedDescription)")
            }
        }
        
        // Reset Firebase references
        firebaseAuth = nil
        firebaseUser = nil
        firebaseFirestoreProfanity = nil
        firebaseAppProfanity = nil
        
        // Reset session flag (this will be cleared by SessionManager anyway, but be explicit)
        moderationSettingsSessionManager.profanityFirebaseInitialized = false
        
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "cleanupFirebaseApp() cleanup completed")
    }
    
    /// Stops profanity service - called during account removal or app shutdown
    func stopProfanityService() {
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "stopProfanityService() stopping service")
        cleanupFirebaseApp()
        AppLogger.log(tag: "LOG-APP: ProfanityService", message: "stopProfanityService() service stopped")
    }
} 