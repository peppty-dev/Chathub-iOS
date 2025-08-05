import Foundation

// MARK: - Search User Model
struct SearchUser: Identifiable, Codable {
    let id: String
    let userId: String
    let deviceId: String
    let userName: String
    let userImage: String
    let userGender: String
    let userAge: String
    let userCountry: String
    
    init(userId: String, deviceId: String, userName: String, userImage: String, userGender: String, userAge: String, userCountry: String) {
        self.id = userId
        self.userId = userId
        self.deviceId = deviceId
        self.userName = userName
        self.userImage = userImage
        self.userGender = userGender
        self.userAge = userAge
        self.userCountry = userCountry
    }
}