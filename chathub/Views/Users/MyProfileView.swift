import SwiftUI
import FirebaseFirestore
import SDWebImageSwiftUI

struct MyProfileView: View {
    @State private var userDetails: [String] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    // Note: Removed showCheckoutProfile - no longer needed after ProfileDetailsView removal
    @State private var showPhotoViewer: Bool = false
    @State private var cachedProfileModel: ProfileModel? = nil
    
    // User session data
    @State private var userId: String = ""
    @State private var userName: String = ""
    @State private var deviceId: String = ""
    @State private var age: String = ""
    @State private var gender: String = ""
    @State private var language: String = ""
    @State private var country: String = ""
    @State private var profileImage: String = ""
    
    // Local Database - Use centralized DatabaseManager (Android Parity)
    private var profileDB: ProfileDB? { DatabaseManager.shared.getProfileDB() }
    
    // Subscription status - Use specialized manager
    private var isProSubscriber: Bool {
        SubscriptionSessionManager.shared.isSubscriptionActive()
    }
    
    @ViewBuilder
    private func profileContentView() -> some View {
        VStack(spacing: 20) {
            // Profile Image Section
            VStack(spacing: 16) {
                Button(action: {
                    if !profileImage.isEmpty && profileImage != "null" {
                        showPhotoViewer = true
                    }
                }) {
                    WebImage(url: URL(string: profileImage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color("shade3"), Color("shade4")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Image(gender == "Male" ? "male" : "female")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .opacity(0.8)
                        }
                    }
                    .onSuccess { image, data, cacheType in
                        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "profileImage loaded successfully from \(cacheType == .memory ? "memory" : cacheType == .disk ? "disk" : "network")")
                    }
                    .onFailure { error in
                        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "profileImage loading failed: \(error.localizedDescription)")
                    }
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.8),
                                        Color("shade3").opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                Color.white.opacity(0.3),
                                lineWidth: 1
                            )
                            .padding(1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // User Name
                Text(Profanity.share.removeProfanityNumbersAllowed(userName))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color("dark"))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            // User Details Collection View
            if !userDetails.isEmpty {
                VStack(spacing: 16) {
                    if #available(iOS 16.0, *) {
                        FlowLayout(spacing: 12) {
                            ForEach(userDetails, id: \.self) { detail in
                                EnhancedUserDetailChip(detail: detail)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(stride(from: 0, to: userDetails.count, by: 2)), id: \.self) { index in
                                HStack(spacing: 12) {
                                    EnhancedUserDetailChip(detail: userDetails[index])
                                    if index + 1 < userDetails.count {
                                        EnhancedUserDetailChip(detail: userDetails[index + 1])
                                    } else {
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            
            // Profile details are now part of main view - no separate details needed
            
            Spacer(minLength: 50)
        }
        .padding(.vertical)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && userName.isEmpty && profileImage.isEmpty {
                // Only show loading when there's no existing profile data from database - prevents flicker
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    profileContentView()
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        // Note: Removed ProfileDetailsView sheet - no longer needed after feature removal
        .background(
            VStack {
                NavigationLink(
                    destination: PhotoViewerView(
                        imageUrl: profileImage,
                        imageUserId: userId,
                        imageType: gender.lowercased() == "male" ? "profilemale" : "profilefemale"
                    ),
                    isActive: $showPhotoViewer
                ) {
                    EmptyView()
                }
                .hidden()
            }
        )
        .task {
            // Ensure database is initialized before loading profile data
            if !DatabaseManager.shared.isDatabaseReady() {
                AppLogger.log(tag: "LOG-APP: MyProfileView", message: "task() database not ready, initializing...")
                DatabaseManager.shared.initializeDatabase()
            }
            
            // Only get userId from session, then load everything from local database
            loadUserIdFromSession()
            await loadUserProfile()
        }
    }
    
    private func loadUserIdFromSession() {
        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "loadUserIdFromSession() getting userId from session")
        
        // Use specialized UserSessionManager instead of monolithic SessionManager
        let userSessionManager = UserSessionManager.shared
        userId = userSessionManager.userId ?? ""
        
        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "loadUserIdFromSession() got userId: \(userId)")
    }
    
    @MainActor
    private func loadUserProfile() async {
        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "loadUserProfile() starting profile load for current user: \(userId)")
        
        guard !userId.isEmpty else {
            errorMessage = "User session not found"
            return
        }
        
        // Use ProfileDB caching mechanism exactly like ProfileView (Android Parity)
        // Always show cached data first (if available) and refresh from Firebase every time
        await loadUserProfileFromDB()
    }
    
    // MARK: - Local Database Profile Loading (Android Parity)
    
    private func loadUserProfileFromDB() async {
        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "loadUserProfileFromDB() checking local database for current user: \(userId)")
        
        // Wait for database to be ready (with timeout)
        var attempts = 0
        let maxAttempts = 10 // 1 second total wait time
        while !DatabaseManager.shared.isDatabaseReady() && attempts < maxAttempts {
            AppLogger.log(tag: "LOG-APP: MyProfileView", message: "loadUserProfileFromDB() database not ready, waiting... attempt \(attempts + 1)/\(maxAttempts)")
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            attempts += 1
        }
        
        // Check local database first
        guard let profileDB = profileDB else {
            AppLogger.log(tag: "LOG-APP: MyProfileView", message: "loadUserProfileFromDB() ProfileDB not available after waiting, fetching from Firebase")
            // Only show loading when we need to fetch from Firebase
            await MainActor.run {
                self.isLoading = true
            }
            await fetchProfileFromFirebaseAndSave()
            return
        }
        
        if let localProfile = profileDB.query(UserId: userId) {
            AppLogger.log(tag: "LOG-APP: MyProfileView", message: "loadUserProfileFromDB() found current user profile in local database")
            
            // Check if data is expired (1 hour = 3600 seconds, matching Android)
            let currentTime = Int(Date().timeIntervalSince1970)
            let profileAge = currentTime - localProfile.Time
            
            // Show local data immediately (fresh or expired), then refresh from Firebase
            AppLogger.log(tag: "LOG-APP: MyProfileView", message: "loadUserProfileFromDB() showing local data, age: \(profileAge) seconds, then refreshing from Firebase")
            await MainActor.run {
                self.updateUIFromProfile(localProfile)
                self.isLoading = false
            }
            await fetchProfileFromFirebaseAndSave()
        } else {
            // No local data, show loading and fetch from Firebase
            AppLogger.log(tag: "LOG-APP: MyProfileView", message: "loadUserProfileFromDB() no local data found for current user, showing loading and fetching from Firebase")
            await MainActor.run {
                self.isLoading = true
            }
            await fetchProfileFromFirebaseAndSave()
        }
    }
    
    private func fetchProfileFromFirebaseAndSave() async {
        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "fetchProfileFromFirebaseAndSave() fetching current user profile from Firebase: \(userId)")
        
        do {
            let document = try await Firestore.firestore().collection("Users").document(userId).getDocument()
            
            if document.exists, let data = document.data() {
                AppLogger.log(tag: "LOG-APP: MyProfileView", message: "fetchProfileFromFirebaseAndSave() successfully fetched current user data from Firebase")
                
                // Save to local database using ProfileDB (Android Parity)
                await saveProfileToLocalDatabase(data)
                
                // Update UI from LOCAL DATABASE to ensure full consistency with ProfileView
                if let profileDB = profileDB, let localProfile = profileDB.query(UserId: userId) {
                    await MainActor.run {
                        self.updateUIFromProfile(localProfile)
                        self.isLoading = false
                        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "fetchProfileFromFirebaseAndSave() UI updated from local DB with fresh data")
                    }
                } else {
                    // Fallback: update minimal fields from Firebase data
                    await MainActor.run {
                        self.updateUIFromFirebaseData(data)
                        self.isLoading = false
                        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "fetchProfileFromFirebaseAndSave() Fallback UI update from Firebase data (ProfileDB not available)")
                    }
                }
                
            } else {
                await MainActor.run {
                    self.errorMessage = "User profile not found"
                    self.isLoading = false
                }
                AppLogger.log(tag: "LOG-APP: MyProfileView", message: "fetchProfileFromFirebaseAndSave() current user profile not found in Firebase")
            }
        } catch {
            AppLogger.log(tag: "LOG-APP: MyProfileView", message: "fetchProfileFromFirebaseAndSave() error: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func saveProfileToLocalDatabase(_ data: [String: Any]) async {
        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "saveProfileToLocalDatabase() saving current user profile to local database for user: \(userId)")
        
        guard let profileDB = profileDB else {
            AppLogger.log(tag: "LOG-APP: MyProfileView", message: "saveProfileToLocalDatabase() ❌ ProfileDB not initialized, cannot save current user profile")
            return
        }
        
        // Extract fields from Firebase data with defaults using exact Android field names
        let userIdString = NSString(string: userId)
        let age = NSString(string: data["User_age"] as? String ?? "")
        let country = NSString(string: data["User_country"] as? String ?? "")
        let language = NSString(string: data["user_language"] as? String ?? "")
        let gender = NSString(string: data["User_gender"] as? String ?? "")
        let name = NSString(string: data["User_name"] as? String ?? "")
        let image = NSString(string: data["User_image"] as? String ?? "")
        let city = NSString(string: data["city"] as? String ?? "")
        let height = NSString(string: data["height"] as? String ?? "")
        let occupation = NSString(string: data["occupation"] as? String ?? "")
        let hobbies = NSString(string: data["hobbies"] as? String ?? "")
        let zodiac = NSString(string: data["zodiac"] as? String ?? "")
        let snap = NSString(string: data["snap"] as? String ?? "")
        let instagram = NSString(string: data["insta"] as? String ?? "")
        let emailVerified = NSString(string: data["email_verified"] as? String ?? "")
        let createdTime = NSString(string: data["User_registered_time"] as? String ?? "")
        let platform = NSString(string: data["platform"] as? String ?? "")
        let subscriptionTier = NSString(string: data["subscriptionTier"] as? String ?? "none")
        
        // Preference fields - using exact Android field names
        let likeMen = NSString(string: data["like_men"] as? String ?? "")
        let likeWomen = NSString(string: data["like_woman"] as? String ?? "")
        let single = NSString(string: data["single"] as? String ?? "")
        let married = NSString(string: data["married"] as? String ?? "")
        let children = NSString(string: data["children"] as? String ?? "")
        let gym = NSString(string: data["gym"] as? String ?? "")
        let smokes = NSString(string: data["smokes"] as? String ?? "")
        let drinks = NSString(string: data["drinks"] as? String ?? "")
        let games = NSString(string: data["games"] as? String ?? "")
        let decentChat = NSString(string: data["decent_chat"] as? String ?? "")
        let pets = NSString(string: data["pets"] as? String ?? "")
        let travel = NSString(string: data["travel"] as? String ?? "")
        let music = NSString(string: data["music"] as? String ?? "")
        let movies = NSString(string: data["movies"] as? String ?? "")
        let naughty = NSString(string: data["naughty"] as? String ?? "")
        let foodie = NSString(string: data["foodie"] as? String ?? "")
        let dates = NSString(string: data["dates"] as? String ?? "")
        let fashion = NSString(string: data["fashion"] as? String ?? "")
        let broken = NSString(string: data["broken"] as? String ?? "")
        let depressed = NSString(string: data["depressed"] as? String ?? "")
        let lonely = NSString(string: data["lonely"] as? String ?? "")
        let cheated = NSString(string: data["cheated"] as? String ?? "")
        let insomnia = NSString(string: data["insomnia"] as? String ?? "")
        let voiceAllowed = NSString(string: data["voice_allowed"] as? String ?? "")
        let videoAllowed = NSString(string: data["video_allowed"] as? String ?? "")
        let picsAllowed = NSString(string: data["pics_allowed"] as? String ?? "")
        
        // Statistics - using exact Android field names (defaults to empty for current user)
        let voiceCalls = NSString(string: "")
        let videoCalls = NSString(string: "")
        let goodExperience = NSString(string: "")
        let badExperience = NSString(string: "")
        let maleAccounts = NSString(string: "")
        let femaleAccounts = NSString(string: "")
        let maleChats = NSString(string: "")
        let femaleChats = NSString(string: "")
        let reports = NSString(string: "")
        let blocks = NSString(string: "")
        
        let currentTime = Date()
        
        // Use continuation to wait for database operations to complete
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                AppLogger.log(tag: "LOG-APP: MyProfileView", message: "saveProfileToLocalDatabase() 🗑️ Deleting existing profile for user: \(userId)")
                
                // Delete existing profile first (synchronous)
                profileDB.delete(UserId: userId)
                
                AppLogger.log(tag: "LOG-APP: MyProfileView", message: "saveProfileToLocalDatabase() 💾 Inserting new profile for user: \(userId)")
                
                // Insert new profile data (synchronous)
                profileDB.insert(
                    UserId: userIdString,
                    Age: age,
                    Country: country,
                    Language: language,
                    Gender: gender,
                    men: likeMen,
                    women: likeWomen,
                    single: single,
                    married: married,
                    children: children,
                    gym: gym,
                    smoke: smokes,
                    drink: drinks,
                    games: games,
                    decenttalk: decentChat,
                    pets: pets,
                    travel: travel,
                    music: music,
                    movies: movies,
                    naughty: naughty,
                    Foodie: foodie,
                    dates: dates,
                    fashion: fashion,
                    broken: broken,
                    depressed: depressed,
                    lonely: lonely,
                    cheated: cheated,
                    insomnia: insomnia,
                    voice: voiceAllowed,
                    video: videoAllowed,
                    pics: picsAllowed,
                    goodexperience: goodExperience,
                    badexperience: badExperience,
                    male_accounts: maleAccounts,
                    female_accounts: femaleAccounts,
                    male_chats: maleChats,
                    female_chats: femaleChats,
                    reports: reports,
                    blocks: blocks,
                    voicecalls: voiceCalls,
                    videocalls: videoCalls,
                    Time: currentTime,
                    Image: image,
                    Named: name,
                    Height: height,
                    Occupation: occupation,
                    Instagram: instagram,
                    Snapchat: snap,
                    Zodic: zodiac,
                    Hobbies: hobbies,
                    EmailVerified: emailVerified,
                    CreatedTime: createdTime,
                    Platform: platform,
                    Premium: subscriptionTier,
                    city: city
                )
                
                AppLogger.log(tag: "LOG-APP: MyProfileView", message: "saveProfileToLocalDatabase() ✅ Database operations completed for user: \(userId)")
                
                // Verify the profile was saved correctly
                if let savedProfile = profileDB.query(UserId: userId) {
                    AppLogger.log(tag: "LOG-APP: MyProfileView", message: "saveProfileToLocalDatabase() ✅ Verification successful - profile saved and retrieved: \(savedProfile.Name)")
                } else {
                    AppLogger.log(tag: "LOG-APP: MyProfileView", message: "saveProfileToLocalDatabase() ❌ Verification failed - profile not found after saving")
                }
                
                continuation.resume()
            }
        }
    }
    
    private func updateUIFromProfile(_ profile: ProfileModel) {
        // Update UI state variables from ProfileModel (cached data)
        userName = profile.Name
        age = profile.Age
        gender = profile.Gender
        country = profile.Country
        language = profile.Language
        profileImage = profile.Image
        cachedProfileModel = profile
        
        // Update session manager with cached data
        let userSessionManager = UserSessionManager.shared
        userSessionManager.userName = profile.Name
        userSessionManager.userAge = profile.Age
        userSessionManager.userGender = profile.Gender
        userSessionManager.userCountry = profile.Country
        userSessionManager.userLanguage = profile.Language
        userSessionManager.userProfilePhoto = profile.Image
        userSessionManager.synchronize()
        
        buildAllDetailsFromProfileModel(profile)
        
        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "updateUIFromProfile() updated UI from cached profile data for: \(userName)")
    }

    private func buildAllDetailsFromProfileModel(_ profile: ProfileModel) {
        var details: [String] = []
        // Email verified
        if profile.EmailVerified.lowercased() == "true" { details.append("Email Verified") }
        // Created time
        if !profile.CreatedTime.isEmpty && profile.CreatedTime != "null" {
            if let time = Double(profile.CreatedTime) {
                let date = time > 1000000000 ? Date(timeIntervalSince1970: time) : Date(timeIntervalSince1970: time * 86400)
                let formatter = DateFormatter()
                formatter.dateFormat = "dd MMM yyyy"
                let dateString = formatter.string(from: date)
                let days = Int(Date().timeIntervalSince(date) / 86400)
                details.append("Created: \(dateString)")
                details.append("\(days) days old")
            }
        }
        // Platform
        if !profile.Platform.isEmpty && profile.Platform != "null" {
            details.append(profile.Platform.lowercased() == "ios" ? "iPhone" : "Android")
        }
        // Age
        if !profile.Age.isEmpty && profile.Age != "null" && profile.Age != "99" { details.append("\(profile.Age) Years old") }
        // Gender, Language, City, Country
        if !profile.Gender.isEmpty && profile.Gender != "null" { details.append(profile.Gender) }
        if !profile.Language.isEmpty && profile.Language != "null" { details.append(profile.Language) }
        if !profile.city.isEmpty && profile.city != "null" { details.append("Around \(profile.city)") }
        if !profile.Country.isEmpty && profile.Country != "null" { details.append(profile.Country) }
        // Height, Occupation, Hobbies, Zodiac
        if !profile.Height.isEmpty && profile.Height != "null" { details.append(Profanity.share.removeProfanityNumbersAllowed(profile.Height)) }
        if !profile.Occupation.isEmpty && profile.Occupation != "null" { details.append(Profanity.share.removeProfanity(profile.Occupation)) }
        if !profile.Hobbies.isEmpty && profile.Hobbies != "null" { details.append(Profanity.share.removeProfanity(profile.Hobbies)) }
        if !profile.Zodic.isEmpty && profile.Zodic != "null" { details.append(Profanity.share.removeProfanity(profile.Zodic)) }
        // Relationship prefs
        if profile.men.lowercased() == "yes" { details.append("I like men") }
        if profile.women.lowercased() == "yes" { details.append("I like woman") }
        if profile.single.lowercased() == "yes" { details.append("Single") }
        if profile.married.lowercased() == "yes" { details.append("Married") }
        if profile.children.lowercased() == "yes" { details.append("Have Kids") }
        // Lifestyle
        if profile.gym.lowercased() == "yes" { details.append("Gym") }
        if profile.smoke.lowercased() == "yes" { details.append("Smokes") }
        if profile.drink.lowercased() == "yes" { details.append("Drinks") }
        if profile.games.lowercased() == "yes" { details.append("I play games") }
        if profile.decenttalk.lowercased() == "yes" { details.append("Strictly decent chats please") }
        // Interests
        if profile.pets.lowercased() == "yes" { details.append("I love pets") }
        if profile.travel.lowercased() == "yes" { details.append("I travel") }
        if profile.music.lowercased() == "yes" { details.append("I love music") }
        if profile.movies.lowercased() == "yes" { details.append("I love movies") }
        if profile.naughty.lowercased() == "yes" { details.append("I am naughty") }
        if profile.Foodie.lowercased() == "yes" { details.append("Foodie") }
        if profile.dates.lowercased() == "yes" { details.append("I go on dates") }
        if profile.fashion.lowercased() == "yes" { details.append("I love fashion") }
        // Emotional
        if profile.broken.lowercased() == "yes" { details.append("Broken") }
        if profile.depressed.lowercased() == "yes" { details.append("Depressed") }
        if profile.lonely.lowercased() == "yes" { details.append("Lonely") }
        if profile.cheated.lowercased() == "yes" { details.append("I got cheated") }
        if profile.insomnia.lowercased() == "yes" { details.append("I can't sleep") }
        // Permissions
        if profile.voice.lowercased() == "yes" { details.append("Voice calls allowed") }
        if profile.video.lowercased() == "yes" { details.append("Video calls allowed") }
        if profile.pics.lowercased() == "yes" { details.append("Pictures allowed") }
        // Stats
        if !profile.voicecalls.isEmpty && profile.voicecalls != "0" { details.append("\(profile.voicecalls) voice calls") }
        if !profile.videocalls.isEmpty && profile.videocalls != "0" { details.append("\(profile.videocalls) video calls") }
        if !profile.goodexperience.isEmpty && profile.goodexperience != "0" { details.append("\(profile.goodexperience) thumbs up") }
        if !profile.badexperience.isEmpty && profile.badexperience != "0" { details.append("\(profile.badexperience) thumbs down") }
        if !profile.male_accounts.isEmpty && profile.male_accounts != "0" { details.append("\(profile.male_accounts) male accounts") }
        if !profile.female_accounts.isEmpty && profile.female_accounts != "0" { details.append("\(profile.female_accounts) female accounts") }
        if !profile.male_chats.isEmpty && profile.male_chats != "0" { details.append("\(profile.male_chats) male chats") }
        if !profile.female_chats.isEmpty && profile.female_chats != "0" { details.append("\(profile.female_chats) female chats") }
        if !profile.reports.isEmpty && profile.reports != "0" { details.append("\(profile.reports) reports") }
        if !profile.blocks.isEmpty && profile.blocks != "0" { details.append("\(profile.blocks) blocks") }
        // Socials
        if !profile.Snapchat.isEmpty && profile.Snapchat != "null" { details.append("Snap: \(Profanity.share.removeProfanityNumbersAllowed(profile.Snapchat))") }
        if !profile.Instagram.isEmpty && profile.Instagram != "null" { details.append("Insta: \(Profanity.share.removeProfanityNumbersAllowed(profile.Instagram))") }
        
        self.userDetails = details
    }
    
    private func updateUIFromFirebaseData(_ data: [String: Any]) {
        // Update UI state variables from Firebase data (fresh data)
                if let name = data["User_name"] as? String, !name.isEmpty {
                    userName = name
                }
                if let image = data["User_image"] as? String, !image.isEmpty {
                    profileImage = image
                }
                if let userAge = data["User_age"] as? String, !userAge.isEmpty {
                    age = userAge
                }
                if let userGender = data["User_gender"] as? String, !userGender.isEmpty {
                    gender = userGender
                }
                if let userLanguage = data["user_language"] as? String, !userLanguage.isEmpty {
                    language = userLanguage
                }
                if let userCountry = data["User_country"] as? String, !userCountry.isEmpty {
                    country = userCountry
        }
        
        // Update session manager with fresh data
        let userSessionManager = UserSessionManager.shared
        userSessionManager.userName = userName
        userSessionManager.userAge = age
        userSessionManager.userGender = gender
        userSessionManager.userCountry = country
        userSessionManager.userLanguage = language
        userSessionManager.userProfilePhoto = profileImage
        userSessionManager.synchronize()
        
        buildUserDetails()
        
        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "updateUIFromFirebaseData() updated UI from fresh Firebase data for: \(userName)")
    }
    
    private func buildUserDetails() {
        userDetails.removeAll()
        
        // Email verified
        if let emailVerified = getValue("email_verified"), emailVerified.lowercased() == "true" {
            userDetails.append("Email Verified")
        }
        // Created time
        if let created = getValue("User_registered_time"), !created.isEmpty {
            if let timeInterval = Double(created) {
                let date = timeInterval > 1000000000 ? Date(timeIntervalSince1970: timeInterval) : Date(timeIntervalSince1970: timeInterval * 86400)
                let formatter = DateFormatter()
                formatter.dateFormat = "dd MMM yyyy"
                let dateString = formatter.string(from: date)
                let days = Int(Date().timeIntervalSince(date) / 86400)
                userDetails.append("Created: \(dateString)")
                userDetails.append("\(days) days old")
            }
        }
        // Platform
        if let platform = getValue("platform"), !platform.isEmpty, platform != "null" {
            userDetails.append(platform.lowercased() == "ios" ? "iPhone" : "Android")
        }
        // Age
        if !age.isEmpty && age != "null" && age != "99" { userDetails.append("\(age) Years old") }
        // Gender
        if !gender.isEmpty && gender != "null" { userDetails.append(gender) }
        // Language
        if !language.isEmpty && language != "null" { userDetails.append(language) }
        // City
        if let city = getValue("city"), !city.isEmpty && city != "null" { userDetails.append("Around \(city)") }
        // Country
        if !country.isEmpty && country != "null" { userDetails.append(country) }
        // Height
        if let height = getValue("height"), !height.isEmpty && height != "null" { userDetails.append(Profanity.share.removeProfanityNumbersAllowed(height)) }
        // Occupation
        if let occupation = getValue("occupation"), !occupation.isEmpty && occupation != "null" { userDetails.append(Profanity.share.removeProfanity(occupation)) }
        // Hobbies
        if let hobbies = getValue("hobbies"), !hobbies.isEmpty && hobbies != "null" { userDetails.append(Profanity.share.removeProfanity(hobbies)) }
        // Zodiac
        if let zodiac = getValue("zodiac"), !zodiac.isEmpty && zodiac != "null" { userDetails.append(Profanity.share.removeProfanity(zodiac)) }
        // Relationship prefs
        if let likeMen = getValue("like_men"), likeMen.lowercased() == "yes" { userDetails.append("I like men") }
        if let likeWoman = getValue("like_woman"), likeWoman.lowercased() == "yes" { userDetails.append("I like woman") }
        if let single = getValue("single"), single.lowercased() == "yes" { userDetails.append("Single") }
        if let married = getValue("married"), married.lowercased() == "yes" { userDetails.append("Married") }
        if let children = getValue("children"), children.lowercased() == "yes" { userDetails.append("Have Kids") }
        // Lifestyle
        if let gym = getValue("gym"), gym.lowercased() == "yes" { userDetails.append("Gym") }
        if let smokes = getValue("smokes"), smokes.lowercased() == "yes" { userDetails.append("Smokes") }
        if let drinks = getValue("drinks"), drinks.lowercased() == "yes" { userDetails.append("Drinks") }
        if let games = getValue("games"), games.lowercased() == "yes" { userDetails.append("I play games") }
        if let decentChat = getValue("decent_chat"), decentChat.lowercased() == "yes" { userDetails.append("Strictly decent chats please") }
        // Interests
        if let pets = getValue("pets"), pets.lowercased() == "yes" { userDetails.append("I love pets") }
        if let travel = getValue("travel"), travel.lowercased() == "yes" { userDetails.append("I travel") }
        if let music = getValue("music"), music.lowercased() == "yes" { userDetails.append("I love music") }
        if let movies = getValue("movies"), movies.lowercased() == "yes" { userDetails.append("I love movies") }
        if let naughty = getValue("naughty"), naughty.lowercased() == "yes" { userDetails.append("I am naughty") }
        if let foodie = getValue("foodie"), foodie.lowercased() == "yes" { userDetails.append("Foodie") }
        if let dates = getValue("dates"), dates.lowercased() == "yes" { userDetails.append("I go on dates") }
        if let fashion = getValue("fashion"), fashion.lowercased() == "yes" { userDetails.append("I love fashion") }
        // Emotional states
        if let broken = getValue("broken"), broken.lowercased() == "yes" { userDetails.append("Broken") }
        if let depressed = getValue("depressed"), depressed.lowercased() == "yes" { userDetails.append("Depressed") }
        if let lonely = getValue("lonely"), lonely.lowercased() == "yes" { userDetails.append("Lonely") }
        if let cheated = getValue("cheated"), cheated.lowercased() == "yes" { userDetails.append("I got cheated") }
        if let insomnia = getValue("insomnia"), insomnia.lowercased() == "yes" { userDetails.append("I can't sleep") }
        // Permissions
        if let voice = getValue("voice_allowed"), voice.lowercased() == "yes" { userDetails.append("Voice calls allowed") }
        if let video = getValue("video_allowed"), video.lowercased() == "yes" { userDetails.append("Video calls allowed") }
        if let pics = getValue("pics_allowed"), pics.lowercased() == "yes" { userDetails.append("Pictures allowed") }
        // Stats
        if let voiceCalls = getValue("voicecalls"), !voiceCalls.isEmpty, voiceCalls != "0" { userDetails.append("\(voiceCalls) voice calls") }
        if let videoCalls = getValue("videocalls"), !videoCalls.isEmpty, videoCalls != "0" { userDetails.append("\(videoCalls) video calls") }
        if let good = getValue("goodexperience"), !good.isEmpty, good != "0" { userDetails.append("\(good) thumbs up") }
        if let bad = getValue("badexperience"), !bad.isEmpty, bad != "0" { userDetails.append("\(bad) thumbs down") }
        if let maleAccounts = getValue("male_accounts"), !maleAccounts.isEmpty, maleAccounts != "0" { userDetails.append("\(maleAccounts) male accounts") }
        if let femaleAccounts = getValue("female_accounts"), !femaleAccounts.isEmpty, femaleAccounts != "0" { userDetails.append("\(femaleAccounts) female accounts") }
        if let maleChats = getValue("male_chats"), !maleChats.isEmpty, maleChats != "0" { userDetails.append("\(maleChats) male chats") }
        if let femaleChats = getValue("female_chats"), !femaleChats.isEmpty, femaleChats != "0" { userDetails.append("\(femaleChats) female chats") }
        if let reports = getValue("reports"), !reports.isEmpty, reports != "0" { userDetails.append("\(reports) reports") }
        if let blocks = getValue("blocks"), !blocks.isEmpty, blocks != "0" { userDetails.append("\(blocks) blocks") }
        // Socials
        if let snap = getValue("snap"), !snap.isEmpty { userDetails.append("Snap: \(Profanity.share.removeProfanityNumbersAllowed(snap))") }
        if let insta = getValue("insta"), !insta.isEmpty { userDetails.append("Insta: \(Profanity.share.removeProfanityNumbersAllowed(insta))") }

        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "buildUserDetails() built \(userDetails.count) detail items")
    }

    private func getValue(_ key: String) -> String? {
        // Try from local DB latest cached fields via Session (if mirrored) else rely on UI state values
        // Since we already copied essential fields to state, this helper is for the extra fields fetched from Firebase and saved to DB
        // Here we read from UserDefaults via UserSessionManager when mirrored, otherwise return nil
        // For now, we return nil so details rely on explicit state fields and known keys updated in updateUIFromFirebaseData
        return nil
    }
    
    // Removed local profanity filter - now using ProfanityService.shared consistently
    
    private func updateUserDefaults() {
        let userSessionManager = UserSessionManager.shared
        userSessionManager.userName = userName
        userSessionManager.userProfilePhoto = profileImage
        userSessionManager.userAge = age
        userSessionManager.userGender = gender
        userSessionManager.userLanguage = language
        userSessionManager.userCountry = country
        userSessionManager.synchronize()
        
        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "updateUserDefaults() Session updated successfully")
    }
}

#Preview {
    MyProfileView()
} 