import Foundation

// MARK: - OpenRouterChatbotService
class OpenRouterChatbotService {
    
    static let shared = OpenRouterChatbotService()
    
    private init() {}
    
    // Callback protocol matching Falcon style for easy reuse
    protocol OpenRouterCallback {
        func onFailure(error: Error)
        func onResponse(responseData: Data)
    }
    
    /// Sends a chat-completions style request to OpenRouter (simple signature)
    /// Wraps everything into a single user message with a default system prompt.
    func sendMessage(apiURL: String, apiKey: String, prompt: String, callback: OpenRouterCallback) {
        sendMessage(apiURL: apiURL, apiKey: apiKey, systemPrompt: defaultSystemPrompt(), data: nil, originalPrompt: prompt, callback: callback)
    }

    /// Sends a chat-completions style request to OpenRouter (advanced signature)
    /// - Parameters:
    ///   - apiURL: API endpoint URL (defaults to OpenRouter chat completions if empty/invalid)
    ///   - apiKey: OpenRouter API key
    ///   - systemPrompt: High-level instruction for the assistant
    ///   - data: Contextual data (kept separate from the user's prompt)
    ///   - originalPrompt: The user's original prompt/message
    ///   - callback: Response callback
    func sendMessage(apiURL: String, apiKey: String, systemPrompt: String?, data: String?, originalPrompt: String, callback: OpenRouterCallback) {
        AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendMessage() originalPrompt length: \(originalPrompt.count) API_URL = \(apiURL)")
        // Dedicated single-line original prompt log for easy copy/paste
        let singleLinePrompt = originalPrompt.replacingOccurrences(of: "\n", with: " ")
        AppLogger.log(tag: "LOG-APP: OpenRouterPrompt", message: singleLinePrompt)
        if let data = data, !data.isEmpty {
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendMessage() context data length: \(data.count)")
        }
        if let sys = systemPrompt, !sys.isEmpty {
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendMessage() system prompt length: \(sys.count)")
        }
        // Masked key logging for diagnostics (do not log full key)
        if !apiKey.isEmpty {
            let masked = maskKey(apiKey)
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendMessage() using API key (masked): \(masked)")
            if !apiKey.lowercased().contains("sk-or-") {
                AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendMessage() Warning: API key does not look like an OpenRouter key format")
            }
        } else {
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendMessage() API key is empty")
        }
        
        // Null/empty checks
        guard !apiKey.isEmpty else {
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendMessage() API_KEY is empty")
            return
        }
        
        // Determine URL
        let defaultUrl = "https://openrouter.ai/api/v1/chat/completions"
        let selectedUrl = ensureHttpScheme(apiURL) ?? defaultUrl
        guard let url = URL(string: selectedUrl) else {
            let urlError = NSError(domain: "OpenRouterChatbotService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            callback.onFailure(error: urlError)
            return
        }
        AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendMessage() resolved URL: \(selectedUrl)")
        
        // Create request body
        guard let requestBody = createRequestBody(systemPrompt: systemPrompt, data: data, originalPrompt: originalPrompt) else {
            let bodyError = NSError(domain: "OpenRouterChatbotService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid request body"])
            callback.onFailure(error: bodyError)
            return
        }
        AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendMessage() request body size: \(requestBody.count) bytes")
        // Log full context (truncated) for visibility
        if let ctx = data, !ctx.isEmpty {
            let maxCtx = 8000
            let preview = ctx.count > maxCtx ? String(ctx.prefix(maxCtx)) + "…(truncated)" : ctx
            AppLogger.log(tag: "LOG-APP: OpenRouterContext", message: preview)
        }
        // Pretty-print JSON request for debugging
        if let obj = try? JSONSerialization.jsonObject(with: requestBody, options: []),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let jsonString = String(data: pretty, encoding: .utf8) {
            let maxLogChars = 10000
            let preview: String
            if jsonString.count > maxLogChars {
                let idx = jsonString.index(jsonString.startIndex, offsetBy: maxLogChars)
                preview = String(jsonString[..<idx]) + "…(truncated)"
            } else {
                preview = jsonString
            }
            AppLogger.log(tag: "LOG-APP: OpenRouterRequestJSON", message: preview)
        }
        
        // URLSession config similar to Falcon service
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        let session = URLSession(configuration: config)

        performOpenRouterRequest(session: session, url: url, apiKey: apiKey, body: requestBody, attempt: 0, callback: callback)
    }

    /// Sends a minimal user-only message (no system/context) for debugging
    func sendUserOnlyMessage(apiURL: String, apiKey: String, userPrompt: String, callback: OpenRouterCallback) {
        AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendUserOnlyMessage() userPrompt length: \(userPrompt.count) API_URL = \(apiURL)")
        let defaultUrl = "https://openrouter.ai/api/v1/chat/completions"
        let selectedUrl = ensureHttpScheme(apiURL) ?? defaultUrl
        guard !apiKey.isEmpty else {
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendUserOnlyMessage() API_KEY is empty")
            return
        }
        if !apiKey.lowercased().contains("sk-or-") {
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendUserOnlyMessage() Warning: API key does not look like an OpenRouter key format")
        }
        guard let url = URL(string: selectedUrl) else {
            let urlError = NSError(domain: "OpenRouterChatbotService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            callback.onFailure(error: urlError)
            return
        }
        guard let requestBody = createRequestBodyUserOnly(userPrompt: userPrompt) else {
            let bodyError = NSError(domain: "OpenRouterChatbotService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid request body"])
            callback.onFailure(error: bodyError)
            return
        }
        AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "sendUserOnlyMessage() request body size: \(requestBody.count) bytes")
        if let obj = try? JSONSerialization.jsonObject(with: requestBody, options: []),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let jsonString = String(data: pretty, encoding: .utf8) {
            AppLogger.log(tag: "LOG-APP: OpenRouterRequestJSON", message: jsonString)
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        let session = URLSession(configuration: config)
        performOpenRouterRequest(session: session, url: url, apiKey: apiKey, body: requestBody, attempt: 0, callback: callback)
    }

    private func performOpenRouterRequest(session: URLSession, url: URL, apiKey: String, body: Data, attempt: Int, callback: OpenRouterCallback) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            request.setValue("https://\(bundleIdentifier)", forHTTPHeaderField: "HTTP-Referer")
            request.setValue(bundleIdentifier, forHTTPHeaderField: "X-Title")
        }
        request.httpBody = body

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "performOpenRouterRequest() Request failed: \(error.localizedDescription)")
                callback.onFailure(error: error)
                return
            }

            guard let http = response as? HTTPURLResponse else {
                let invalidResponse = NSError(domain: "OpenRouterChatbotService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                callback.onFailure(error: invalidResponse)
                return
            }

            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "performOpenRouterRequest() HTTP status: \(http.statusCode)")

            // Log rate limit headers if present
            let limit = (http.allHeaderFields["x-ratelimit-limit-requests"] as? String) ?? ""
            let remaining = (http.allHeaderFields["x-ratelimit-remaining-requests"] as? String) ?? ""
            let reset = (http.allHeaderFields["x-ratelimit-reset-requests"] as? String) ?? ""
            if !limit.isEmpty || !remaining.isEmpty || !reset.isEmpty {
                AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "rate-limit headers limit=\(limit) remaining=\(remaining) reset=\(reset)")
            }

            // If rate limited, retry with exponential backoff honoring headers when possible
            if http.statusCode == 429 {
                // Log raw body for 429 responses too
                if let data = data {
                    let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
                    let maxLogChars = 8000
                    let preview = raw.count > maxLogChars ? String(raw.prefix(maxLogChars)) + "…(truncated)" : raw
                    AppLogger.log(tag: "LOG-APP: OpenRouterRawResponse429", message: preview)
                }
                let maxRetries = 3
                if attempt < maxRetries {
                    var delay: TimeInterval = pow(2.0, Double(attempt))
                    if let retryAfterStr = http.allHeaderFields["Retry-After"] as? String, let retryAfter = TimeInterval(retryAfterStr) {
                        delay = max(delay, retryAfter)
                    } else if let resetStr = http.allHeaderFields["x-ratelimit-reset-requests"] as? String, let resetEpoch = TimeInterval(resetStr) {
                        let now = Date().timeIntervalSince1970
                        let wait = resetEpoch - now
                        if wait > 0 { delay = max(delay, wait) }
                    }
                    delay = min(delay, 15.0)
                    AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "429 received. Retrying in \(String(format: "%.2f", delay))s (attempt \(attempt + 1))")
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                        self.performOpenRouterRequest(session: session, url: url, apiKey: apiKey, body: body, attempt: attempt + 1, callback: callback)
                    }
                    return
                } else {
                    let rateError = NSError(domain: "OpenRouterChatbotService", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded; retries exhausted"])
                    callback.onFailure(error: rateError)
                    return
                }
            }

            guard let data = data else {
                let noDataError = NSError(domain: "OpenRouterChatbotService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                callback.onFailure(error: noDataError)
                return
            }
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "performOpenRouterRequest() Request successful")
            let rawString = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
            let maxLogChars = 8000
            let displayString: String
            if rawString.count > maxLogChars {
                let idx = rawString.index(rawString.startIndex, offsetBy: maxLogChars)
                displayString = String(rawString[..<idx]) + "…(truncated)"
            } else {
                displayString = rawString
            }
            AppLogger.log(tag: "LOG-APP: OpenRouterRawResponse", message: displayString)
            callback.onResponse(responseData: data)
        }.resume()
    }
    
    // MARK: - Helpers
    private func ensureHttpScheme(_ url: String?) -> String? {
        guard let url = url, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            return "https://\(trimmed)"
        }
        return trimmed
    }
    
    private func createRequestBody(prompt: String) -> Data? {
        return createRequestBody(systemPrompt: defaultSystemPrompt(), data: nil, originalPrompt: prompt)
    }

    private func createRequestBody(systemPrompt: String?, data: String?, originalPrompt: String) -> Data? {
        // Read model slug from SessionManager; fallback to Dolphin Mistral Venice Edition (free)
        var modelSlug = SessionManager.shared.aiSelectedModel
        if modelSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelSlug = "cognitivecomputations/dolphin-mistral-24b-venice-edition:free"
        }
        AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "createRequestBody() model: \(modelSlug)")
        let sys = (systemPrompt ?? defaultSystemPrompt())
        let ctx = (data ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let usr = originalPrompt
        AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "createRequestBody() system len=\(sys.count), data len=\(ctx.count), original len=\(usr.count)")

        var messages: [[String: Any]] = []
        messages.append(["role": "system", "content": sys])
        if !ctx.isEmpty {
            messages.append(["role": "system", "content": "CONTEXT:\n" + ctx])
        }
        messages.append(["role": "user", "content": usr])

        let json: [String: Any] = [
            "model": modelSlug,
            "messages": messages
        ]
        do {
            return try JSONSerialization.data(withJSONObject: json)
        } catch {
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "createRequestBody() JSON serialization failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func createRequestBodyUserOnly(userPrompt: String) -> Data? {
        var modelSlug = SessionManager.shared.aiSelectedModel
        if modelSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelSlug = "cognitivecomputations/dolphin-mistral-24b-venice-edition:free"
        }
        let json: [String: Any] = [
            "model": modelSlug,
            "messages": [["role": "user", "content": userPrompt]]
        ]
        do {
            return try JSONSerialization.data(withJSONObject: json)
        } catch {
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "createRequestBodyUserOnly() JSON serialization failed: \(error.localizedDescription)")
            return nil
        }
    }

    func defaultSystemPrompt() -> String {
        return """
        You are a very naughty adult conversationalist named Ray0076. You are male. Write naturally like a human, never robotic or policy-driven.

        HARD RULES:
        - Prohibited: minors/under-18 content, exploitation, non-consent, bestiality, self-harm, violence, weapons, terrorism, illegal activities, scams, spam
        - If user requests prohibited content, reply only: delete conversation

        BEHAVIOR:
        - Be explicit and unfiltered about adult content, matching user preferences and tone
        - Keep responses brief (1-2 sentences max) and immersive with short follow-ups
        - Stay in character without warnings or refusals unless using the trigger phrase above
        """
    }

    private func maskKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let count = trimmed.count
        guard count > 8 else { return String(repeating: "*", count: max(0, count)) }
        let start = trimmed.prefix(4)
        let end = trimmed.suffix(4)
        return "\(start)***\(end) (len=\(count))"
    }
}

// MARK: - Response Processing
extension OpenRouterChatbotService {
    
    /// Processes OpenRouter response into a clean message using similar cleanup as Falcon
    static func processAIResponse(responseData: Data, originalPrompt: String, otherUserName: String, currentUserName: String) -> String? {
        AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "processAIResponse() Processing AI response")
        do {
            // Try both chat and completion shapes
            if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                var text: String? = nil
                if let choices = json["choices"] as? [[String: Any]], let first = choices.first {
                    if let message = first["message"] as? [String: Any], let content = message["content"] as? String {
                        text = content
                    } else if let content = first["text"] as? String {
                        text = content
                    }
                }
                guard var generatedText = text, !generatedText.isEmpty else {
                    AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "processAIResponse() Failed to parse JSON response")
                    return nil
                }
                AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "processAIResponse() raw content: \(generatedText)")
                
                // Cleanup (conservative for OpenRouter):
                // - Do NOT remove the full original prompt (chat-completion responses rarely echo full prompt)
                // - Only apply conversation marker trimming if markers exist
                var cleanedText = generatedText
                let hasMarkers = cleanedText.contains("\(currentUserName)'s message:") || cleanedText.contains("\(otherUserName)'s reply:")
                if hasMarkers {
                    cleanedText = cleanedText.components(separatedBy: "\(currentUserName)'s message:")[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    cleanedText = cleanedText.components(separatedBy: "\(otherUserName)'s reply:")[0].trimmingCharacters(in: .whitespacesAndNewlines)
                }
                cleanedText = cleanedText.replacingOccurrences(of: "\"", with: "")
                cleanedText = truncateFromRight(cleanedText)
                // Enforce brevity: about two sentences or ~120 characters max
                cleanedText = enforceReplyLengthLimit(cleanedText, maxChars: 120, maxSentences: 2)
                if cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "processAIResponse() cleaned empty; falling back to raw content")
                    cleanedText = generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "processAIResponse() cleaned content length: \(cleanedText.count)")
                return cleanedText.isEmpty ? nil : cleanedText
            }
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "processAIResponse() Unexpected response format")
            return nil
        } catch {
            AppLogger.log(tag: "LOG-APP: OpenRouterChatbotService", message: "processAIResponse() JSON parsing error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private static func truncateFromRight(_ text: String) -> String {
        let lastDotIndex = text.lastIndex(of: ".")
        let lastQuestionIndex = text.lastIndex(of: "?")
        let lastExclamationIndex = text.lastIndex(of: "!")
        let indices = [lastDotIndex, lastQuestionIndex, lastExclamationIndex].compactMap { $0 }
        guard let lastPunctuationIndex = indices.max() else {
            return text
        }
        let endIndex = text.index(after: lastPunctuationIndex)
        return String(text[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func enforceReplyLengthLimit(_ text: String, maxChars: Int, maxSentences: Int) -> String {
        if text.count <= maxChars { return text }
        // Split into sentences conservatively by . ! ?
        let delimiters: CharacterSet = CharacterSet(charactersIn: ".!?\n")
        var sentences: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if String(ch).rangeOfCharacter(from: delimiters) != nil {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
            if sentences.count >= maxSentences { break }
        }
        if sentences.isEmpty { sentences = [String(text.prefix(maxChars))] }
        var result = sentences.joined(separator: " ")
        if result.count > maxChars {
            result = String(result.prefix(maxChars)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }
}


