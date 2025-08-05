

import KeychainSwift

class UUIDManager {

	static let sharedInstance = UUIDManager()

	private let keychain = KeychainSwift()
	private let uuidKey = "UUIDChatHub"

	private init() {}

	func getUUID() -> String {
		// Check if the UUID is already saved in the keychain
		if let savedUUID = keychain.get(uuidKey) {
			return savedUUID
		} else {
			// Generate a new UUID and save it in the keychain
			let newUUID = UUID().uuidString
			keychain.set(newUUID, forKey: uuidKey)
			return newUUID
		}
	}
}
