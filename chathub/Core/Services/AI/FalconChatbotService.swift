import Foundation

// MARK: - FalconChatbotService (Android Parity)
class FalconChatbotService {
    
    // Android Parity: Singleton instance
    static let shared = FalconChatbotService()
    
    private init() {}
    
    // Android Parity: Callback protocol matching Android's Callback interface
    protocol FalconChatbotCallback {
        func onFailure(error: Error)
        func onResponse(responseData: Data)
    }
    
    // Android Parity: Main sendMessage method matching Android signature exactly
    func sendMessage(apiURL: String, apiKey: String, prompt: String, callback: FalconChatbotCallback) {
        // Dedicated single-line prompt log for easy copy/paste during testing
        AppLogger.log(tag: "LOG-APP: FalconPrompt", message: prompt)
        AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "sendMessage() prompt: \(prompt) \nAPI_URL = \(apiURL)")
        
        // Android Parity: Null checks
        guard !apiURL.isEmpty, !apiKey.isEmpty else {
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "sendMessage() API_URL or API_KEY is null/empty")
            return
        }
        
        // Android Parity: Ensure HTTP scheme
        guard let validURL = ensureHttpScheme(apiURL) else {
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "sendMessage() Invalid URL provided")
            return
        }
        
        // Android Parity: Create URLSession with timeouts matching OkHttpClient
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0  // connectTimeout
        config.timeoutIntervalForResource = 60.0  // readTimeout
        let session = URLSession(configuration: config)
        
        // Android Parity: Create JSON request body
        guard let requestBody = createRequestBody(prompt: prompt) else {
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "sendMessage() Failed to create request body")
            return
        }
        
        // Android Parity: Create request with same headers
        guard let url = URL(string: validURL) else {
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "sendMessage() Failed to create URL from validURL: \(validURL)")
            let urlError = NSError(domain: "FalconChatbotService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            callback.onFailure(error: urlError)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody
        
        // Android Parity: Execute request asynchronously
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "sendMessage() Request failed: \(error.localizedDescription)")
                callback.onFailure(error: error)
            } else if let data = data {
                AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "sendMessage() Request successful")
                callback.onResponse(responseData: data)
            } else {
                AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "sendMessage() No data received")
                let noDataError = NSError(domain: "FalconChatbotService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                callback.onFailure(error: noDataError)
            }
        }.resume()
    }
    
    // Android Parity: ensureHttpScheme method matching Android implementation exactly
    private func ensureHttpScheme(_ url: String?) -> String? {
        guard let url = url else {
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "ensureHttpScheme() URL is null")
            return nil
        }
        
        let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUrl.isEmpty {
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "ensureHttpScheme() URL is empty after trimming")
            return nil
        }
        
        let lowercaseUrl = trimmedUrl.lowercased()
        if !lowercaseUrl.hasPrefix("http://") && !lowercaseUrl.hasPrefix("https://") {
            return "https://\(trimmedUrl)"
        }
        return trimmedUrl
    }
    
    // Android Parity: Create JSON request body matching Android JSONObject structure
    private func createRequestBody(prompt: String) -> Data? {
        let jsonObject: [String: Any] = [
            "inputs": prompt
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject)
            return jsonData
        } catch {
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "createRequestBody() JSON serialization failed: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - AI Response Processing (Android Parity)
extension FalconChatbotService {
    
    // Android Parity: Process AI response matching AiMessageWorker.processAiMessage()
    static func processAIResponse(responseData: Data, originalPrompt: String, otherUserName: String, currentUserName: String) -> String? {
        AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "processAIResponse() Processing AI response")
        
        do {
            // Android Parity: Parse JSON array response
            guard let jsonArray = try JSONSerialization.jsonObject(with: responseData) as? [[String: Any]],
                  let firstObject = jsonArray.first,
                  let generatedText = firstObject["generated_text"] as? String else {
                AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "processAIResponse() Failed to parse JSON response")
                return nil
            }
            
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "processAIResponse() Response1: \(generatedText)")
            
            // Android Parity: Remove original prompt from response
            var cleanedText = generatedText.replacingOccurrences(of: originalPrompt, with: "")
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "processAIResponse() replace prompt Response2: \(cleanedText)")
            
            // Android Parity: Remove conversation markers exactly like Android
            cleanedText = cleanedText.components(separatedBy: "\(currentUserName)'s message:")[0].trimmingCharacters(in: .whitespacesAndNewlines)
            cleanedText = cleanedText.components(separatedBy: "\(otherUserName)'s reply:")[0].trimmingCharacters(in: .whitespacesAndNewlines)
            cleanedText = cleanedText.components(separatedBy: "\(currentUserName)'s message:")[0].trimmingCharacters(in: .whitespacesAndNewlines)
            cleanedText = cleanedText.components(separatedBy: "\(otherUserName)'s reply:")[0].trimmingCharacters(in: .whitespacesAndNewlines)
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "processAIResponse() (\(currentUserName)'s message) (\(otherUserName)'s reply) Response3: \(cleanedText)")
            
            // Android Parity: Remove quotes
            cleanedText = cleanedText.replacingOccurrences(of: "\"", with: "")
            
            // Android Parity: Truncate from right (find last punctuation)
            cleanedText = truncateFromRight(cleanedText)
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "processAIResponse() final Response: \(cleanedText)")
            
            return cleanedText.isEmpty ? nil : cleanedText
            
        } catch {
            AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "processAIResponse() JSON parsing error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Android Parity: truncateFromRight method matching AiMessageWorker exactly
    private static func truncateFromRight(_ text: String) -> String {
        AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "truncateFromRight() text = \(text)")
        
        // Android Parity: Find the last punctuation mark (excluding trailing comma)
        let lastDotIndex = text.lastIndex(of: ".")
        let lastQuestionIndex = text.lastIndex(of: "?")
        let lastExclamationIndex = text.lastIndex(of: "!")
        
        let indices = [lastDotIndex, lastQuestionIndex, lastExclamationIndex].compactMap { $0 }
        
        // Android Parity: If no punctuation is found, return the whole text
        guard let lastPunctuationIndex = indices.max() else {
            return text
        }
        
        // Android Parity: Return the substring up to the last punctuation (inclusive)
        let endIndex = text.index(after: lastPunctuationIndex)
        return String(text[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Android Parity: Check sentence similarity matching AiMessageWorker.areSentencesSimilar()
    static func areSentencesSimilar(_ sentence1: String, _ sentence2: String, thresholdPercent: Int) -> Bool {
        AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "areSentencesSimilar() sentence1 = \(sentence1) sentence2 = \(sentence2) thresholdPercent = \(thresholdPercent)")
        
        // Android Parity: Normalize sentences (convert to lowercase)
        let normalized1 = sentence1.lowercased()
        let normalized2 = sentence2.lowercased()
        
        // Android Parity: Calculate Levenshtein Distance
        let editDistance = levenshteinDistance(normalized1, normalized2)
        
        // Android Parity: Calculate similarity percentage
        let maxLength = max(normalized1.count, normalized2.count)
        if maxLength == 0 { return true } // Both strings are empty, so they are 100% similar
        
        let similarity = (1 - Double(editDistance) / Double(maxLength)) * 100
        
        // Android Parity: Return true if similarity meets or exceeds the threshold
        let result = similarity >= Double(thresholdPercent)
        AppLogger.log(tag: "LOG-APP: FalconChatbotService", message: "areSentencesSimilar() similarity: \(similarity)%, result: \(result)")
        return result
    }
    
    // Android Parity: Levenshtein Distance calculation
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        // Guard against empty strings to avoid invalid ranges (1...0)
        if s1Count == 0 { return s2Count }
        if s2Count == 0 { return s1Count }
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[s1Count][s2Count]
    }
} 