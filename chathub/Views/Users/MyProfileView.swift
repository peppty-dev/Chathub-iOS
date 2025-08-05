import SwiftUI
import FirebaseFirestore

struct MyProfileView: View {
    @State private var userDetails: [String] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    // Note: Removed showCheckoutProfile - no longer needed after ProfileDetailsView removal
    @State private var showEditProfile: Bool = false
    @State private var showPhotoViewer: Bool = false
    
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
                    let profileImageView = AsyncImage(url: URL(string: profileImage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 120, height: 120)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .onAppear {
                                    AppLogger.log(tag: "LOG-APP: MyProfileView", message: "profileImage loaded successfully")
                                }
                        case .failure(let error):
                            Image(gender == "Male" ? "male" : "female")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .onAppear {
                                    AppLogger.log(tag: "LOG-APP: MyProfileView", message: "profileImage loading failed: \(error.localizedDescription)")
                                }
                        @unknown default:
                            Image(gender == "Male" ? "male" : "female")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.shade2, lineWidth: 3)
                    )
                    
                    profileImageView
                }
                .buttonStyle(PlainButtonStyle())
                
                // User Name
                VStack(spacing: 8) {
                    Text(Profanity.share.removeProfanityNumbersAllowed(userName))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(Color("Background Color"))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            // User Details Collection View
            if !userDetails.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: 8)
                ], spacing: 8) {
                    ForEach(userDetails.indices, id: \.self) { index in
                        Text(userDetails[index])
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color("shade2"))
                            .cornerRadius(20)
                            .foregroundColor(Color.primary)
                    }
                }
                .padding(.horizontal, 10)
            }
            
            // Profile details are now part of main view - no separate details needed
            
            Spacer(minLength: 50)
        }
        .padding(.vertical)
    }

    var body: some View {
        NavigationView {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showEditProfile = true
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("blue"))
                }
            }
        }
        // Note: Removed ProfileDetailsView sheet - no longer needed after feature removal
        .background(
            VStack {
                NavigationLink(
                    destination: EditProfileView(),
                    isActive: $showEditProfile
                ) {
                    EmptyView()
                }
                .hidden()
                
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
            
            if profileAge < 3600 {
                // Data is fresh, use it immediately (no loading state needed)
                AppLogger.log(tag: "LOG-APP: MyProfileView", message: "loadUserProfileFromDB() using fresh local data, age: \(profileAge) seconds - showing immediately")
                await MainActor.run {
                    self.updateUIFromProfile(localProfile)
                    self.isLoading = false
                }
            } else {
                // Data is expired, show it immediately but fetch new data in background
                AppLogger.log(tag: "LOG-APP: MyProfileView", message: "loadUserProfileFromDB() using expired local data, showing immediately then refreshing. Age: \(profileAge) seconds")
                await MainActor.run {
                    self.updateUIFromProfile(localProfile)
                    self.isLoading = false
                }
                
                // Fetch fresh data in background (silent refresh)
                await fetchProfileFromFirebaseAndSave()
            }
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
                
                // Update UI from fresh data
                await MainActor.run {
                    self.updateUIFromFirebaseData(data)
                    self.isLoading = false
                    AppLogger.log(tag: "LOG-APP: MyProfileView", message: "fetchProfileFromFirebaseAndSave() UI updated successfully for current user")
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
        
        // Update session manager with cached data
        let userSessionManager = UserSessionManager.shared
        userSessionManager.userName = profile.Name
        userSessionManager.userAge = profile.Age
        userSessionManager.userGender = profile.Gender
        userSessionManager.userCountry = profile.Country
        userSessionManager.userLanguage = profile.Language
        userSessionManager.userProfilePhoto = profile.Image
        userSessionManager.synchronize()
        
        buildUserDetails()
        
        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "updateUIFromProfile() updated UI from cached profile data for: \(userName)")
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
        
        if !age.isEmpty && age != "99" {
            userDetails.append("\(age) Years")
        }
        if !gender.isEmpty {
            userDetails.append(gender)
        }
        if !country.isEmpty {
            userDetails.append(country)
        }
        if !language.isEmpty {
            userDetails.append(language)
        }
        
        AppLogger.log(tag: "LOG-APP: MyProfileView", message: "buildUserDetails() built \(userDetails.count) detail items")
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