import Foundation

// MARK: - VeniceChatbotService
class VeniceChatbotService {
    
    static let shared = VeniceChatbotService()
    
    private init() {}
    private var didLogModelsOnce: Bool = false
    
    // OpenAI-compatible Chat Completions endpoint for Venice
    // Base URL should be like: https://api.venice.ai/api/v1
    // We will normalize and append /chat/completions when needed.
    
    protocol VeniceCallback {
        func onFailure(error: Error)
        func onResponse(responseData: Data)
    }
    
    // Single-prompt variant: one user message containing entire prompt
    func sendSinglePrompt(apiURL: String, apiKey: String, prompt: String, callback: VeniceCallback) {
        AppLogger.log(tag: "LOG-APP: VenicePrompt", message: prompt)
        AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "sendSinglePrompt() prompt length: \(prompt.count) API_URL = \(apiURL)")
        if !apiKey.isEmpty {
            let masked = maskKey(apiKey)
            AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "sendSinglePrompt() using API key (masked): \(masked)")
        }
        guard !apiKey.isEmpty else {
            AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "sendSinglePrompt() API_KEY is empty")
            return
        }
        let normalizedUrl = normalizeChatCompletionsUrl(apiURL)
        guard let url = URL(string: normalizedUrl) else {
            let urlError = NSError(domain: "VeniceChatbotService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            callback.onFailure(error: urlError)
            return
        }
        guard let body = createRequestBodySinglePrompt(prompt: prompt) else {
            let bodyError = NSError(domain: "VeniceChatbotService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid request body"])
            callback.onFailure(error: bodyError)
            return
        }
        AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "sendSinglePrompt() request body size: \(body.count) bytes")
        if let obj = try? JSONSerialization.jsonObject(with: body, options: []),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let jsonString = String(data: pretty, encoding: .utf8) {
            AppLogger.log(tag: "LOG-APP: VeniceRequestJSON", message: jsonString)
        }
        performRequest(url: url, apiKey: apiKey, body: body, callback: callback)
    }

    func sendMessage(apiURL: String, apiKey: String, systemPrompt: String?, data: String?, originalPrompt: String, callback: VeniceCallback) {
        AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "sendMessage() originalPrompt length: \(originalPrompt.count) API_URL = \(apiURL)")
        let singleLinePrompt = originalPrompt.replacingOccurrences(of: "\n", with: " ")
        AppLogger.log(tag: "LOG-APP: VenicePrompt", message: singleLinePrompt)
        if let data = data, !data.isEmpty {
            AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "sendMessage() context data length: \(data.count)")
        }
        if let sys = systemPrompt, !sys.isEmpty {
            AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "sendMessage() system prompt length: \(sys.count)")
        }
        if !apiKey.isEmpty {
            let masked = maskKey(apiKey)
            AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "sendMessage() using API key (masked): \(masked)")
        }
        guard !apiKey.isEmpty else {
            AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "sendMessage() API_KEY is empty")
            return
        }
        // Normalize URL: accept either base or full chat completions URL
        let normalizedUrl = normalizeChatCompletionsUrl(apiURL)
        guard let url = URL(string: normalizedUrl) else {
            let urlError = NSError(domain: "VeniceChatbotService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            callback.onFailure(error: urlError)
            return
        }
        guard let body = createRequestBody(systemPrompt: systemPrompt, data: data, originalPrompt: originalPrompt) else {
            let bodyError = NSError(domain: "VeniceChatbotService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid request body"])
            callback.onFailure(error: bodyError)
            return
        }
        AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "sendMessage() request body size: \(body.count) bytes")
        if let obj = try? JSONSerialization.jsonObject(with: body, options: []),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let jsonString = String(data: pretty, encoding: .utf8) {
            AppLogger.log(tag: "LOG-APP: VeniceRequestJSON", message: jsonString)
        }
        performRequest(url: url, apiKey: apiKey, body: body, callback: callback)
    }
    
    private func maskKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let count = trimmed.count
        guard count > 8 else { return String(repeating: "*", count: max(0, count)) }
        let start = trimmed.prefix(4)
        let end = trimmed.suffix(4)
        return "\(start)***\(end) (len=\(count))"
    }
    
    private func normalizeChatCompletionsUrl(_ baseOrFull: String) -> String {
        let trimmed = baseOrFull.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().contains("/chat/completions") { return trimmed }
        let base = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return base + "/chat/completions"
    }
    
    private func createRequestBody(systemPrompt: String?, data: String?, originalPrompt: String) -> Data? {
        let sys = systemPrompt ?? OpenRouterChatbotService.shared.defaultSystemPrompt()
        let ctx = (data ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let usr = originalPrompt
        var messages: [[String: Any]] = []
        messages.append(["role": "system", "content": sys])
        if !ctx.isEmpty {
            messages.append(["role": "system", "content": "CONTEXT:\n" + ctx])
        }
        messages.append(["role": "user", "content": usr])
        // Venice is OpenAI-compatible; include model if caller set it in SessionManager.aiSelectedModel
        var json: [String: Any] = [
            "messages": messages
        ]
        let modelSlug = "venice-uncensored"
        AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "createRequestBody() model (hardcoded): \(modelSlug)")
        json["model"] = modelSlug
        do {
            return try JSONSerialization.data(withJSONObject: json)
        } catch {
            AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "createRequestBody() JSON serialization failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func createRequestBodySinglePrompt(prompt: String) -> Data? {
        var messages: [[String: Any]] = []
        messages.append(["role": "user", "content": prompt])
        var json: [String: Any] = [
            "messages": messages
        ]
        let modelSlug = "venice-uncensored"
        AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "createRequestBodySinglePrompt() model (hardcoded): \(modelSlug)")
        json["model"] = modelSlug
        do {
            return try JSONSerialization.data(withJSONObject: json)
        } catch {
            AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "createRequestBodySinglePrompt() JSON serialization failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func performRequest(url: URL, apiKey: String, body: Data, callback: VeniceCallback) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        let session = URLSession(configuration: .default)
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "performRequest() failed: \(error.localizedDescription)")
                callback.onFailure(error: error)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                let invalidResponse = NSError(domain: "VeniceChatbotService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                callback.onFailure(error: invalidResponse)
                return
            }
            AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "performRequest() HTTP status: \(http.statusCode)")
            guard let data = data else {
                let noDataError = NSError(domain: "VeniceChatbotService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                callback.onFailure(error: noDataError)
                return
            }
            let rawString = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
            AppLogger.log(tag: "LOG-APP: VeniceRawResponse", message: rawString)
            if (http.statusCode == 400 || http.statusCode == 404 || http.statusCode == 422) && rawString.lowercased().contains("model not found") {
                // On model error, fetch and log the available models once for operator to choose the correct ID
                if !self.didLogModelsOnce {
                    self.didLogModelsOnce = true
                    let base = self.extractApiBase(fromChatCompletionsUrl: url.absoluteString)
                    self.fetchAvailableModels(apiBaseURL: base, apiKey: apiKey)
                }
            }
            callback.onResponse(responseData: data)
        }.resume()
    }

    private func extractApiBase(fromChatCompletionsUrl url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: "/chat/completions", options: [.caseInsensitive, .backwards]) {
            let base = String(trimmed[..<range.lowerBound])
            return base
        }
        return trimmed
    }

    private func fetchAvailableModels(apiBaseURL: String, apiKey: String) {
        var base = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix("/") { base.removeLast() }
        let modelsUrlString = base + "/models"
        guard let modelsUrl = URL(string: modelsUrlString) else {
            AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "fetchAvailableModels() invalid models URL: \(modelsUrlString)")
            return
        }
        var req = URLRequest(url: modelsUrl)
        req.httpMethod = "GET"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let session = URLSession(configuration: .default)
        session.dataTask(with: req) { data, response, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "fetchAvailableModels() failed: \(error.localizedDescription)")
                return
            }
            guard let http = response as? HTTPURLResponse else {
                AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "fetchAvailableModels() invalid response")
                return
            }
            AppLogger.log(tag: "LOG-APP: VeniceChatbotService", message: "fetchAvailableModels() HTTP status: \(http.statusCode)")
            guard let data = data else { return }
            if let obj = try? JSONSerialization.jsonObject(with: data, options: []),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
               let jsonString = String(data: pretty, encoding: .utf8) {
                AppLogger.log(tag: "LOG-APP: VeniceModels", message: jsonString)
            } else if let raw = String(data: data, encoding: .utf8) {
                AppLogger.log(tag: "LOG-APP: VeniceModelsRaw", message: raw)
            }
        }.resume()
    }
}

// MARK: - Response Processing (reuse OpenRouter parser)
extension VeniceChatbotService {
    static func processAIResponse(responseData: Data, originalPrompt: String, otherUserName: String, currentUserName: String) -> String? {
        return OpenRouterChatbotService.processAIResponse(responseData: responseData, originalPrompt: originalPrompt, otherUserName: otherUserName, currentUserName: currentUserName)
    }
}


