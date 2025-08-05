import Foundation
import UIKit

// MARK: - HiveImageModerationService (Android Parity)
class HiveImageModerationService {
    
    // Android Parity: Same API endpoint and token
    private static let API_URL = "https://api.thehive.ai/api/v2/task/sync"
    private static let API_TOKEN = "DJC9ynSrTdSb6RirwOXkvXSgtzPs2Zn6"
    
    // Android Parity: Same callback protocol
    protocol HiveImageModerationCallback {
        func onHiveImageModerationComplete(_ isNSFW: Bool)
    }
    
    // Android Parity: Same moderation threshold
    private static let MODERATION_THRESHOLD = 0.8000
    private static let TOTAL_SCORE_THRESHOLD = 0.9000
    
    // Android Parity: Same flagged content categories
    private static let flaggedCategories = [
        "general_nsfw", "general_suggestive", "yes_female_underwear", "yes_male_underwear",
        "yes_sex_toy", "yes_female_nudity", "yes_male_nudity", "yes_female_swimwear",
        "yes_male_shirtless", "text", "animated_gun", "gun_in_hand", "gun_not_in_hand",
        "culinary_knife_in_hand", "knife_in_hand", "knife_not_in_hand", "a_little_bloody",
        "other_blood", "very_bloody", "yes_pills", "yes_smoking", "illicit_injectables",
        "medical_injectables", "yes_nazi", "yes_kkk", "yes_middle_finger", "yes_terrorist",
        "yes_overlay_text", "yes_sexual_activity", "hanging", "noose", "yes_realistic_nsfw",
        "animated_corpse", "human_corpse", "yes_self_harm", "yes_drawing", "yes_emaciated_body",
        "yes_sexual_intent", "animal_genitalia_and_human", "animal_genitalia_only",
        "animated_animal_genitalia", "yes_gambling", "yes_undressed", "yes_confederate"
    ]
    
    // Android Parity: Singleton instance
    static let shared = HiveImageModerationService()
    
    private init() {}
    
    // Android Parity: Main moderation method matching Android signature
    func moderateImage(imagePath: String, callback: HiveImageModerationCallback) {
        AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "moderateImage() starting moderation for image: \(imagePath)")
        
        let sessionManager = SessionManager.shared
        let userId = sessionManager.userId ?? "unknown"
        let imageName = "\(userId)_\(Int(Date().timeIntervalSince1970))"
        
        // Android Parity: Check user flags first
        if sessionManager.multipleReportsSB || sessionManager.imageModerationIssueSB {
            AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "moderateImage() User flagged for multiple reports or image issues - marking as NSFW")
            callback.onHiveImageModerationComplete(true)
            return
        }
        
        // Android Parity: Load image and create multipart request
        guard let imageData = loadImageData(from: imagePath) else {
            AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "moderateImage() Failed to load image data")
            callback.onHiveImageModerationComplete(false)
            return
        }
        
        performModerationRequest(imageData: imageData, imageName: imageName, callback: callback)
    }
    
    // Android Parity: Load image data from path
    private func loadImageData(from path: String) -> Data? {
        if path.hasPrefix("file://") {
            let url = URL(string: path)!
            return try? Data(contentsOf: url)
        } else {
            return try? Data(contentsOf: URL(fileURLWithPath: path))
        }
    }
    
    // Android Parity: Perform HTTP request to Hive API
    private func performModerationRequest(imageData: Data, imageName: String, callback: HiveImageModerationCallback) {
        guard let url = URL(string: Self.API_URL) else {
            callback.onHiveImageModerationComplete(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Android Parity: Same headers
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("token \(Self.API_TOKEN)", forHTTPHeaderField: "authorization")
        
        // Android Parity: Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = createMultipartBody(imageData: imageData, imageName: imageName, boundary: boundary)
        request.httpBody = httpBody
        
        // Android Parity: Execute request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleModerationResponse(data: data, error: error, callback: callback)
            }
        }.resume()
    }
    
    // Android Parity: Create multipart form body
    private func createMultipartBody(imageData: Data, imageName: String, boundary: String) -> Data {
        var body = Data()
        
        // Android Parity: Same form field structure
        let fieldName = "image"
        let filename = imageName
        let mimeType = "multipart/form-data"
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    // Android Parity: Handle API response
    private func handleModerationResponse(data: Data?, error: Error?, callback: HiveImageModerationCallback) {
        if let error = error {
            AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "handleModerationResponse() Error: \(error.localizedDescription)")
            callback.onHiveImageModerationComplete(false)
            return
        }
        
        guard let data = data else {
            AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "handleModerationResponse() No data received")
            callback.onHiveImageModerationComplete(false)
            return
        }
        
        // Android Parity: Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            logSplit(responseString)
        }
        
        let isNSFW = parseHiveResponse(data: data)
        AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "handleModerationResponse() Final result: \(isNSFW)")
        callback.onHiveImageModerationComplete(isNSFW)
    }
    
    // Android Parity: Parse JSON response exactly like Android
    private func parseHiveResponse(data: Data) -> Bool {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let statusArray = json["status"] as? [[String: Any]],
                  let firstStatus = statusArray.first,
                  let response = firstStatus["response"] as? [String: Any],
                  let output = response["output"] as? [[String: Any]],
                  let firstOutput = output.first,
                  let classes = firstOutput["classes"] as? [[String: Any]] else {
                AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "parseHiveResponse() Failed to parse JSON structure")
                return false
            }
            
            var imageModerationScore = 0.0
            
            // Android Parity: Loop through classes and check scores
            for classObject in classes {
                guard let className = classObject["class"] as? String,
                      let scoreString = classObject["score"] as? String,
                      let score = Double(scoreString) else {
                    continue
                }
                
                // Android Parity: Format score like Android (BigDecimal -> DecimalFormat)
                let formattedScore = Double(String(format: "%.4f", score)) ?? 0.0
                
                AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "parseHiveResponse() Class: \(className), Score: \(scoreString), Formatted: \(formattedScore)")
                
                // Android Parity: Check if class is flagged and score exceeds threshold
                if Self.flaggedCategories.contains(className) && formattedScore > Self.MODERATION_THRESHOLD {
                    imageModerationScore += formattedScore
                    
                    // Android Parity: Same total threshold check
                    if imageModerationScore > Self.TOTAL_SCORE_THRESHOLD {
                        AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "parseHiveResponse() NSFW detected")
                        
                        // Android Parity: Update session manager score
                        let sessionManager = SessionManager.shared
                        sessionManager.hiveImageModerationScore += 1
                        
                        return true
                    }
                }
            }
            
            return false
            
        } catch {
            AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "parseHiveResponse() JSON parsing error: \(error)")
            return false
        }
    }
    
    // Android Parity: Split long log messages like Android LogSplit method
    private func logSplit(_ message: String) {
        let maxLength = 3000
        if message.count > maxLength {
            let firstPart = String(message.prefix(maxLength))
            let remaining = String(message.dropFirst(maxLength))
            AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "logSplit() \(firstPart)")
            logSplit(remaining)
        } else {
            AppLogger.log(tag: "LOG-APP: HiveImageModerationService", message: "logSplit() \(message)")
        }
    }
} 