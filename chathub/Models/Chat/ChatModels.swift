import Foundation

// MARK: - Chat Pay Data Model
struct ChatPayData {
    let otherUserId: String
    let otherUserName: String
    let otherUserGender: String
    let otherUserImage: String
    let otherUserDevId: String
    let coins: Int
    let freeMessage: Bool
}

// MARK: - Chat Models

struct ChatUser: Identifiable, Codable {
    var id: String
    var name: String
    var profileImage: String
    var gender: String
    var deviceId: String
    var isOnline: Bool
    var fcmToken: String? // FCM token for sending notifications
}

// MARK: - Direct Call Types
enum DirectCallType {
    case audio, video
}

// MARK: - Permission Types
enum PermissionType {
    case microphone, camera, microphoneAndCamera, liveFeature
} 