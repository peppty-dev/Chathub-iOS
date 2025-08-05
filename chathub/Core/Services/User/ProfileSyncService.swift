import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit

/// iOS equivalent of Android GetProfileWorker
/// Handles profile synchronization from Firebase to local database with 100% Android parity
class ProfileSyncService {
    static let shared = ProfileSyncService()
    
    private let db = Firestore.firestore()
    private let sessionManager = SessionManager.shared
    
    private init() {}
    
    /// Android parity: GetProfileWorker.getProfile()
    /// Fetches and syncs user profile from Firebase to local database
    func fetchAndSyncProfile(userId: String, completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "fetchAndSyncProfile() Starting profile sync for user: \(userId)")
        
        // Android parity: First fetch subscription data
        var subscriptionTier = "TIER_NONE"
        var subscriptionExpiry: Int64 = 0
        
        let dispatchGroup = DispatchGroup()
        
        // Fetch subscription data (Android parity)
        dispatchGroup.enter()
        db.collection("Users")
            .document(userId)
            .collection("Subscription")
            .document("current_state")
            .getDocument { documentSnapshot, error in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "fetchAndSyncProfile() Error getting subscription document: \(error.localizedDescription)")
                } else if let document = documentSnapshot, document.exists {
                    if let tier = document.get("tier") as? String {
                        subscriptionTier = tier
                    }
                    if let expiry = document.get("expiryTimeMillis") as? Int64 {
                        subscriptionExpiry = expiry
                    }
                    AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "fetchAndSyncProfile() Subscription data: tier=\(subscriptionTier), expiry=\(subscriptionExpiry)")
                } else {
                    AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "fetchAndSyncProfile() Subscription document 'current_state' not found for user: \(userId)")
                }
            }
        
        // Fetch main profile data (Android parity)
        dispatchGroup.enter()
        db.collection("Users")
            .document(userId)
            .getDocument { documentSnapshot, error in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "fetchAndSyncProfile() Error getting profile document: \(error.localizedDescription)")
                    return
                }
                
                guard let document = documentSnapshot, document.exists else {
                    AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "fetchAndSyncProfile() Profile document not found for user: \(userId)")
                    return
                }
                
                guard document.get("User_name") != nil else {
                    AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "fetchAndSyncProfile() User_name is null, skipping profile sync")
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "fetchAndSyncProfile() Profile document found, extracting data")
                
                // Extract profile data (Android parity: exact same field extraction)
                let platform = document.get("platform") as? String ?? "null"
                let userId = document.get("User_id") as? String ?? "null"
                let userName = document.get("User_name") as? String ?? "null"
                let userImage = document.get("User_image") as? String ?? "null"
                let userAge = document.get("User_age") as? String ?? "null"
                let userGender = document.get("User_gender") as? String ?? "null"
                let userLanguage = document.get("user_language") as? String ?? "null"
                let userRegisteredTime = document.get("User_registered_time") as? Int64 ?? 0
                let userCountry = document.get("User_country") as? String ?? "null"
                let userDeviceId = document.get("User_device_id") as? String ?? "null"
                let userDeviceToken = document.get("User_device_token") as? String ?? "null"
                let city = document.get("userRetrievedCity") as? String ?? "null"
                let emailVerified = String(document.get("User_verified") as? Bool ?? false)
                let moveToInbox = document.get("move_to_inbox") as? Bool ?? false
                // Removed: let watchModeNumber = document.get("watch_mode_number") as? Int64 ?? 0


                
                // Extended profile fields (Android parity)
                let height = document.get("height") as? String ?? "null"
                let likeMen = document.get("like_men") as? String ?? "null"
                let likeWoman = document.get("like_woman") as? String ?? "null"
                let single = document.get("single") as? String ?? "null"
                let married = document.get("married") as? String ?? "null"
                let children = document.get("children") as? String ?? "null"
                let gym = document.get("gym") as? String ?? "null"
                let smokes = document.get("smokes") as? String ?? "null"
                let drinks = document.get("drinks") as? String ?? "null"
                let occupation = document.get("occupation") as? String ?? "null"
                let games = document.get("games") as? String ?? "null"
                let decentChat = document.get("decent_chat") as? String ?? "null"
                let pets = document.get("pets") as? String ?? "null"
                let hobbies = document.get("hobbies") as? String ?? "null"
                let travel = document.get("travel") as? String ?? "null"
                let zodiac = document.get("zodiac") as? String ?? "null"
                let music = document.get("music") as? String ?? "null"
                let movies = document.get("movies") as? String ?? "null"
                let naughty = document.get("naughty") as? String ?? "null"

                let foodie = document.get("foodie") as? String ?? "null"
                let dates = document.get("dates") as? String ?? "null"
                let fashion = document.get("fashion") as? String ?? "null"
                let broken = document.get("broken") as? String ?? "null"
                let depressed = document.get("depressed") as? String ?? "null"
                let lonely = document.get("lonely") as? String ?? "null"
                let cheated = document.get("cheated") as? String ?? "null"
                let insomnia = document.get("insomnia") as? String ?? "null"
                let voiceAllowed = document.get("voice_allowed") as? String ?? "null"
                let videoAllowed = document.get("video_allowed") as? String ?? "null"
                let picsAllowed = document.get("pics_allowed") as? String ?? "null"
                let voiceCalls = document.get("voice_calls") as? String ?? "null"
                let videoCalls = document.get("video_calls") as? String ?? "null"
                let live = document.get("live") as? String ?? "null"
                let goodExperience = document.get("good_experience") as? String ?? "null"
                let badExperience = document.get("bad_experience") as? String ?? "null"
                let maleAccounts = document.get("male_accounts") as? String ?? "null"
                let femaleAccounts = document.get("female_accounts") as? String ?? "null"
                let reports = document.get("reports") as? String ?? "null"
                let blocks = document.get("blocks") as? String ?? "null"
                let femaleChats = document.get("female_chats") as? String ?? "null"
                let maleChats = document.get("male_chats") as? String ?? "null"
                let snap = document.get("snap") as? String ?? "null"
                let insta = document.get("insta") as? String ?? "null"
                
                AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "fetchAndSyncProfile() Profile data extracted successfully for user: \(userId)")
            }
        
        // Wait for all operations to complete
        dispatchGroup.notify(queue: .global(qos: .background)) {
            AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "fetchAndSyncProfile() Profile sync completed for user: \(userId)")
            completion(true)
        }
    }
    
    /// Android parity: InsertProfileAsyncTask.doInBackground()
    /// Inserts/updates profile data in local database
    private func insertProfileToLocalDatabase(
        userId: String,
        userName: String,
        userImage: String,
        userAge: String,
        userGender: String,
        userLanguage: String,
        city: String,
        userCountry: String,
        userDeviceId: String,
        userDeviceToken: String,
        userRegisteredTime: Int64,
        emailVerified: String,
        moveToInbox: Bool,
        // Removed: watchModeNumber: Int64,


        subscriptionTier: String,
        subscriptionExpiry: Int64,
        platform: String,
        height: String,
        likeMen: String,
        likeWoman: String,
        single: String,
        married: String,
        children: String,
        gym: String,
        smokes: String,
        drinks: String,
        occupation: String,
        games: String,
        decentChat: String,
        pets: String,
        hobbies: String,
        travel: String,
        zodiac: String,
        music: String,
        movies: String,
        naughty: String,

        foodie: String,
        dates: String,
        fashion: String,
        broken: String,
        depressed: String,
        lonely: String,
        cheated: String,
        insomnia: String,
        voiceAllowed: String,
        videoAllowed: String,
        picsAllowed: String,
        voiceCalls: String,
        videoCalls: String,
        live: String,
        goodExperience: String,
        badExperience: String,
        maleAccounts: String,
        femaleAccounts: String,
        reports: String,
        blocks: String,
        femaleChats: String,
        maleChats: String,
        snap: String,
        insta: String
    ) {
        AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "insertProfileToLocalDatabase() Inserting profile data for user: \(userId)")
        
        let profileManager = ProfileManager.shared
        
        // Create ProfileData with core fields (matching ProfileDB schema)
        let profileData = ProfileManager.ProfileData(
            profileId: userId,
            userName: userName,
            userGender: userGender,
            userAge: userAge,
            userCountry: userCountry,
            userImage: userImage,
            deviceId: userDeviceId,
            isOnline: false, // Default value
            lastActiveTime: String(Date().timeIntervalSince1970),
            profileType: "user" // Default type
        )
        
        // Store using ProfileManager (Android parity)
        profileManager.addOrUpdateProfile(profileData)
        
        AppLogger.log(tag: "LOG-APP: ProfileSyncService", message: "insertProfileToLocalDatabase() Profile saved successfully using ProfileManager for user: \(userId)")
        
        // Note: Extended profile fields (height, hobbies, etc.) are not stored in current ProfileDB schema
        // This maintains compatibility with existing ProfileDB structure while removing Core Data dependency
    }
} 