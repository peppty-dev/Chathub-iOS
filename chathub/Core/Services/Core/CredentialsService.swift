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
        
        // Always load AI API URL from SessionManager first (Android parity)
        aiApiUrl = SessionManager.shared.getAiChatBotURL() ?? ""
        AppLogger.log(tag: "LOG-APP: CredentialsService", message: "loadCredentials() Session aiApiUrl = \(aiApiUrl)")
        
        // Try to read a bundled credentials.json if present
        guard let path = Bundle.main.path(forResource: "credentials", ofType: "json"),
              let data = NSData(contentsOfFile: path) else {
            AppLogger.log(tag: "LOG-APP: CredentialsService", message: "loadCredentials() credentials.json file not found - using SessionManager value for aiApiUrl")
            return
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data as Data) as? [String: Any] else {
                AppLogger.log(tag: "LOG-APP: CredentialsService", message: "loadCredentials() Failed to parse JSON")
                return
            }
            
            // Android Parity: Load AI API credentials
            // Prefer SessionManager, but allow JSON to provide/override if present
            let jsonApiUrl = (json["ai_api_url"] as? String)
                ?? (json["AI_API_URL"] as? String)
                ?? (json["aiChatbotUrl"] as? String)
            if let url = jsonApiUrl, !url.isEmpty { aiApiUrl = url }
            // API Key: prefer existing, then JSON, then SessionManager
            if let jsonKey = (
                json["aiChatbotKey"] as? String ??
                json["aiChatbotApiKey"] as? String ??
                json["ai_chatbot_api_key"] as? String ??
                json["hugging_face_api_key"] as? String
            ), !jsonKey.isEmpty {
                aiApiKey = jsonKey
            }
            if aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                aiApiKey = SessionManager.shared.aiApiKey ?? aiApiKey
            }
            
            // Android Parity: Load AWS credentials
            awsCognitoIdentityPoolId = json["aws_cognito_identity_pool_id_for_chatbot"] as? String ?? ""
            awsChatbotEndpointUrl = json["aws_chatbot_endpoint_url"] as? String ?? ""
            
            AppLogger.log(tag: "LOG-APP: CredentialsService", message: "loadCredentials() Credentials loaded successfully")
            AppLogger.log(tag: "LOG-APP: CredentialsService", message: "loadCredentials() AI_API_URL = \(aiApiUrl)")
            
        } catch {
            AppLogger.log(tag: "LOG-APP: CredentialsService", message: "loadCredentials() JSON parsing error: \(error.localizedDescription)")
        }
    }
    
    // Android Parity: Getter methods matching Android pattern
    func getAiApiUrl() -> String {
        return aiApiUrl
    }
    
    func getAiApiKey() -> String {
        if aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Runtime fallback to SessionManager if needed
            return SessionManager.shared.aiApiKey ?? ""
        }
        return aiApiKey
    }
    
    func getAwsCognitoIdentityPoolId() -> String {
        return awsCognitoIdentityPoolId
    }
    
    func getAwsChatbotEndpointUrl() -> String {
        return awsChatbotEndpointUrl
    }
} 