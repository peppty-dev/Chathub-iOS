import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable {
    var id: String
    var username: String
    var devid: String
    var deviceToken: String
    var gender: String
    var age: String
    var country: String
    var language: String
    var mac_id: String
    var ipv4Address: String?
    var ipv6Address: String?
    var platform: String
    var version: String
    var profilePhoto: String
    var fcmToken: String
    var firebaseInstallationId: String
    var firstLoginTime: Timestamp
    var lastLoginTime: Timestamp
    var appVersion: String
    var deviceModel: String
    var deviceManufacturer: String
    var osVersion: String
    var deviceCountry: String
    var deviceLanguage: String
    var accountStatus: String
    var isOnline: Bool
    var totalReports: Int
    var privacyAccepted: Bool
    var search_name: String
    var search_country: String
    var search_gender: String
    var search_language: String
    var accountCreationTimestamp: Timestamp
    var ipAddress: String?
    
    // Subscription fields for parity with Android
    var subscriptionTier: String?
    var subscriptionExpiry: Int64?
    
    // Additional fields for ProfileView compatibility
    var city: String?
    var height: String?
    var occupation: String?
    var hobbies: String?
    var zodiac: String?
    var snap: String?
    var insta: String?
    var emailVerified: String?
    var userRegisteredTime: String?
    var likeMen: String?
    var likeWoman: String?
    var single: String?
    var married: String?
    var children: String?
    var gym: String?
    var smokes: String?
    var drinks: String?
    var games: String?
    var decentChat: String?
    var pets: String?
    var travel: String?
    var music: String?
    var movies: String?
    var naughty: String?
    var foodie: String?
    var dates: String?
    var fashion: String?
    var broken: String?
    var depressed: String?
    var lonely: String?
    var cheated: String?
    var insomnia: String?
    var voiceAllowed: String?
    var videoAllowed: String?
    var picsAllowed: String?
    var voiceCalls: String?
    var videoCalls: String?
    var live: String?
    var goodExperience: String?
    var badExperience: String?
    var maleAccounts: String?
    var femaleAccounts: String?
    var reports: String?
    var blocks: String?
    var femaleChats: String?
    var maleChats: String?
    
    // Computed properties for ProfileView compatibility
    var name: String { username }
    var profileImage: String { profilePhoto }
    var deviceId: String { devid }
    var lastSeen: Date { lastLoginTime.dateValue() }
    
    // Custom initializer for UserProfile creation
    init(
        id: String,
        username: String,
        devid: String = "",
        deviceToken: String = "",
        gender: String,
        age: String,
        country: String,
        language: String,
        mac_id: String = "",
        ipv4Address: String? = nil,
        ipv6Address: String? = nil,
        platform: String,
        version: String = "",
        profilePhoto: String,
        fcmToken: String = "",
        firebaseInstallationId: String = "",
        firstLoginTime: Timestamp = Timestamp(),
        lastLoginTime: Timestamp = Timestamp(),
        appVersion: String = "",
        deviceModel: String = "",
        deviceManufacturer: String = "",
        osVersion: String = "",
        deviceCountry: String = "",
        deviceLanguage: String = "",
        accountStatus: String = "",
        isOnline: Bool = false,
        totalReports: Int = 0,
        privacyAccepted: Bool = false,
        search_name: String = "",
        search_country: String = "",
        search_gender: String = "",
        search_language: String = "",
        accountCreationTimestamp: Timestamp = Timestamp(),
        ipAddress: String? = nil,
        subscriptionTier: String? = nil,
        subscriptionExpiry: Int64? = nil,
        city: String? = nil,
        height: String? = nil,
        occupation: String? = nil,
        hobbies: String? = nil,
        zodiac: String? = nil,
        snap: String? = nil,
        insta: String? = nil,
        emailVerified: String? = nil,
        userRegisteredTime: String? = nil,
        likeMen: String? = nil,
        likeWoman: String? = nil,
        single: String? = nil,
        married: String? = nil,
        children: String? = nil,
        gym: String? = nil,
        smokes: String? = nil,
        drinks: String? = nil,
        games: String? = nil,
        decentChat: String? = nil,
        pets: String? = nil,
        travel: String? = nil,
        music: String? = nil,
        movies: String? = nil,
        naughty: String? = nil,
        foodie: String? = nil,
        dates: String? = nil,
        fashion: String? = nil,
        broken: String? = nil,
        depressed: String? = nil,
        lonely: String? = nil,
        cheated: String? = nil,
        insomnia: String? = nil,
        voiceAllowed: String? = nil,
        videoAllowed: String? = nil,
        picsAllowed: String? = nil,
        voiceCalls: String? = nil,
        videoCalls: String? = nil,
        live: String? = nil,
        goodExperience: String? = nil,
        badExperience: String? = nil,
        maleAccounts: String? = nil,
        femaleAccounts: String? = nil,
        reports: String? = nil,
        blocks: String? = nil,
        femaleChats: String? = nil,
        maleChats: String? = nil
    ) {
        self.id = id
        self.username = username
        self.devid = devid
        self.deviceToken = deviceToken
        self.gender = gender
        self.age = age
        self.country = country
        self.language = language
        self.mac_id = mac_id
        self.ipv4Address = ipv4Address
        self.ipv6Address = ipv6Address
        self.platform = platform
        self.version = version
        self.profilePhoto = profilePhoto
        self.fcmToken = fcmToken
        self.firebaseInstallationId = firebaseInstallationId
        self.firstLoginTime = firstLoginTime
        self.lastLoginTime = lastLoginTime
        self.appVersion = appVersion
        self.deviceModel = deviceModel
        self.deviceManufacturer = deviceManufacturer
        self.osVersion = osVersion
        self.deviceCountry = deviceCountry
        self.deviceLanguage = deviceLanguage
        self.accountStatus = accountStatus
        self.isOnline = isOnline
        self.totalReports = totalReports
        self.privacyAccepted = privacyAccepted
        self.search_name = search_name
        self.search_country = search_country
        self.search_gender = search_gender
        self.search_language = search_language
        self.accountCreationTimestamp = accountCreationTimestamp
        self.ipAddress = ipAddress
        self.subscriptionTier = subscriptionTier
        self.subscriptionExpiry = subscriptionExpiry
        self.city = city
        self.height = height
        self.occupation = occupation
        self.hobbies = hobbies
        self.zodiac = zodiac
        self.snap = snap
        self.insta = insta
        self.emailVerified = emailVerified
        self.userRegisteredTime = userRegisteredTime
        self.likeMen = likeMen
        self.likeWoman = likeWoman
        self.single = single
        self.married = married
        self.children = children
        self.gym = gym
        self.smokes = smokes
        self.drinks = drinks
        self.games = games
        self.decentChat = decentChat
        self.pets = pets
        self.travel = travel
        self.music = music
        self.movies = movies
        self.naughty = naughty
        self.foodie = foodie
        self.dates = dates
        self.fashion = fashion
        self.broken = broken
        self.depressed = depressed
        self.lonely = lonely
        self.cheated = cheated
        self.insomnia = insomnia
        self.voiceAllowed = voiceAllowed
        self.videoAllowed = videoAllowed
        self.picsAllowed = picsAllowed
        self.voiceCalls = voiceCalls
        self.videoCalls = videoCalls
        self.live = live
        self.goodExperience = goodExperience
        self.badExperience = badExperience
        self.maleAccounts = maleAccounts
        self.femaleAccounts = femaleAccounts
        self.reports = reports
        self.blocks = blocks
        self.femaleChats = femaleChats
        self.maleChats = maleChats
    }
} 