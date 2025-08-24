import Foundation

// MARK: - CredentialsService (Android Parity)
class CredentialsService {
    
    // Android Parity: Singleton instance
    static let shared = CredentialsService()
    
    private init() {}
    
    // Android Parity: Credential properties matching Android
    private(set) var aiApiUrl: String = ""
    private(set) var aiApiKey: String = ""
    private(set) var awsCognitoIdentityPoolId: String = ""
    private(set) var awsChatbotEndpointUrl: String = ""
    
    // Android Parity: Load credentials from JSON file
    func loadCredentials() {
        AppLogger.log(tag: "LOG-APP: CredentialsService", message: "loadCredentials() Loading credentials from JSON")
        
        // Determine active provider and pull from SessionManager per-provider keys only
        let provider = SessionManager.shared.aiModelProvider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if provider == "openrouter" {
            aiApiUrl = SessionManager.shared.openRouterApiUrl
            aiApiKey = SessionManager.shared.openRouterApiKey
        } else if provider == "venice" {
            aiApiUrl = SessionManager.shared.veniceApiUrl.isEmpty ? "https://api.venice.ai/api/v1" : SessionManager.shared.veniceApiUrl
            aiApiKey = SessionManager.shared.veniceApiKey
        } else {
            aiApiUrl = SessionManager.shared.falconApiUrl
            aiApiKey = SessionManager.shared.falconApiKey
        }
        
        // Optionally allow JSON overrides to set per-provider values (development convenience)
        if let path = Bundle.main.path(forResource: "credentials", ofType: "json"),
           let data = NSData(contentsOfFile: path) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data as Data) as? [String: Any] {
                    if let falconUrl = json[AppSettingsKeys.falconApiUrl] as? String, !falconUrl.isEmpty {
                        SessionManager.shared.falconApiUrl = falconUrl
                    }
                    if let falconKey = json[AppSettingsKeys.falconApiKey] as? String, !falconKey.isEmpty {
                        SessionManager.shared.falconApiKey = falconKey
                    }
                    if let orUrl = json[AppSettingsKeys.openRouterApiUrl] as? String, !orUrl.isEmpty {
                        SessionManager.shared.openRouterApiUrl = orUrl
                    }
                    if let orKey = (
                        json[AppSettingsKeys.openRouterApiKey] as? String ??
                        json["openrouter_api_key"] as? String ??
                        json["OPENROUTER_API_KEY"] as? String
                    ), !orKey.isEmpty {
                        SessionManager.shared.openRouterApiKey = orKey
                    }
                    if let veniceUrl = json["veniceApiUrl"] as? String, !veniceUrl.isEmpty {
                        SessionManager.shared.veniceApiUrl = veniceUrl
                    }
                    if let veniceKey = (
                        json["veniceApiKey"] as? String ??
                        json["VENICE_API_KEY"] as? String
                    ), !veniceKey.isEmpty {
                        SessionManager.shared.veniceApiKey = veniceKey
                    }
                    // Refresh local vars after potential overrides
                    if provider == "openrouter" {
                        aiApiUrl = SessionManager.shared.openRouterApiUrl
                        aiApiKey = SessionManager.shared.openRouterApiKey
                    } else if provider == "venice" {
                        aiApiUrl = SessionManager.shared.veniceApiUrl
                        aiApiKey = SessionManager.shared.veniceApiKey
                    } else {
                        aiApiUrl = SessionManager.shared.falconApiUrl
                        aiApiKey = SessionManager.shared.falconApiKey
                    }
                }
            } catch {
                AppLogger.log(tag: "LOG-APP: CredentialsService", message: "loadCredentials() JSON parsing error: \(error.localizedDescription)")
            }
        }
        
        AppLogger.log(tag: "LOG-APP: CredentialsService", message: "loadCredentials() AI_API_URL = \(aiApiUrl)")
    }
    
    // Android Parity: Getter methods matching Android pattern
    func getAiApiUrl() -> String {
        return aiApiUrl
    }
    
    func getAiApiKey() -> String {
        return aiApiKey
    }
    
    func getAwsCognitoIdentityPoolId() -> String {
        return awsCognitoIdentityPoolId
    }
    
    func getAwsChatbotEndpointUrl() -> String {
        return awsChatbotEndpointUrl
    }
} 