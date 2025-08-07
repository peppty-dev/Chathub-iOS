import Foundation

/**
 * ConversationFlowLogger - Enhanced logging system for tracking conversation flow
 * 
 * This provides structured, filterable logging specifically for conversation initiation,
 * algorithm execution, and routing decisions. Makes debugging and monitoring much easier.
 */
class ConversationFlowLogger {
    
    static let shared = ConversationFlowLogger()
    private init() {}
    
    // MARK: - Flow Session Management
    
    /// Generate unique session ID for tracking a complete conversation flow
    private func generateFlowSessionId() -> String {
        return "FLOW_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 1000...9999))"
    }
    
    // MARK: - Structured Logging Methods
    
    /// Log the start of conversation flow with user classification
    func logFlowStart(
        initiatorUserId: String,
        targetUserId: String,
        userType: ConversationUserType,
        sessionId: String? = nil
    ) {
        let flowId = sessionId ?? generateFlowSessionId()
        
        AppLogger.log(
            tag: "🚀 CONVERSATION-FLOW",
            message: """
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            🎯 CONVERSATION FLOW STARTED
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            📋 Flow ID: \(flowId)
            👤 Initiator: \(initiatorUserId)
            🎯 Target: \(targetUserId)
            🏷️ User Type: \(userType.description)
            ⏰ Time: \(Date().formatted())
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        )
    }
    
    /// Log limit check results
    func logLimitCheck(
        flowId: String,
        result: FeatureLimitResult,
        userType: ConversationUserType
    ) {
        let status = result.showPopup ? "🚧 POPUP_REQUIRED" : "✅ BYPASS_LIMITS"
        let canProceed = result.canProceed ? "✅ CAN_PROCEED" : "❌ BLOCKED"
        
        AppLogger.log(
            tag: "🔒 CONVERSATION-LIMITS",
            message: """
            📋 Flow ID: \(flowId)
            🏷️ User Type: \(userType.description)
            🚧 Popup Status: \(status)
            🎯 Proceed Status: \(canProceed)
            📊 Usage: \(result.currentUsage)/\(result.limit)
            ⏳ Cooldown: \(result.remainingCooldown)s
            """
        )
    }
    
    /// Log routing decision (Lite bypass or algorithm execution)
    func logRoutingDecision(
        flowId: String,
        decision: RoutingDecision,
        userType: ConversationUserType,
        bypassReason: String? = nil
    ) {
        let routingText = decision.toInbox ? "📥 INBOX" : "💬 DIRECT_CHAT"
        let reasonText = bypassReason ?? "Algorithm decision"
        
        AppLogger.log(
            tag: "🎯 CONVERSATION-ROUTING",
            message: """
            📋 Flow ID: \(flowId)
            🏷️ User Type: \(userType.description)
            🎯 Routing: \(routingText)
            💰 Paid Status: \(decision.isPaid ? "PAID" : "FREE")
            📝 Reason: \(reasonText)
            """
        )
    }
    
    /// Log algorithm execution with detailed factor analysis
    func logAlgorithmExecution(
        flowId: String,
        factors: CompatibilityFactors,
        result: CompatibilityResult
    ) {
        let factorDetails = """
        🌍 Country: \(factors.countryMatch ? "✅" : "❌") (\(factors.userCountry) vs \(factors.otherCountry))
        👫 Gender: \(factors.genderMatch ? "✅" : "❌") (\(factors.userGender) → \(factors.otherGender))
        🎂 Age: \(factors.ageMatch ? "✅" : "❌") (\(factors.userAge) vs \(factors.otherAge), diff: \(abs(factors.userAge - factors.otherAge)))
        🗣️ Language: \(factors.languageMatch ? "✅" : "❌") (\(factors.userLanguage) vs \(factors.otherLanguage))
        """
        
        AppLogger.log(
            tag: "🧮 CONVERSATION-ALGORITHM",
            message: """
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            🧮 COMPATIBILITY ALGORITHM EXECUTION
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            📋 Flow ID: \(flowId)
            
            📊 FACTOR ANALYSIS:
            \(factorDetails)
            
            📈 ALGORITHM RESULT:
            🔢 Mismatches: \(result.mismatchCount)/4
            📊 Compatibility Score: \(4-result.mismatchCount)/4 (\(Int((4-result.mismatchCount)/4*100))%)
            🎯 Threshold: 3 mismatches
            📥 Routing Decision: \(result.mismatchCount >= 3 ? "INBOX" : "DIRECT_CHAT")
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        )
    }
    
    /// Log chat creation success
    func logChatCreation(
        flowId: String,
        chatId: String,
        routing: RoutingDecision,
        timeTaken: TimeInterval
    ) {
        let routingText = routing.toInbox ? "📥 INBOX" : "💬 DIRECT_CHAT"
        
        AppLogger.log(
            tag: "✅ CONVERSATION-SUCCESS",
            message: """
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            ✅ CONVERSATION CREATED SUCCESSFULLY
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            📋 Flow ID: \(flowId)
            💬 Chat ID: \(chatId)
            🎯 Routing: \(routingText)
            💰 Paid: \(routing.isPaid ? "YES" : "NO")
            ⏱️ Total Time: \(String(format: "%.2f", timeTaken))s
            ⏰ Completed: \(Date().formatted())
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        )
    }
    
    /// Log flow errors
    func logFlowError(
        flowId: String,
        error: Error,
        step: ConversationFlowStep,
        context: [String: String] = [:]
    ) {
        let contextText = context.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        
        AppLogger.log(
            tag: "❌ CONVERSATION-ERROR",
            message: """
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            ❌ CONVERSATION FLOW ERROR
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            📋 Flow ID: \(flowId)
            🚫 Step: \(step.description)
            ⚠️ Error: \(error.localizedDescription)
            📝 Context:
            \(contextText)
            ⏰ Time: \(Date().formatted())
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        )
    }
    
    /// Log performance metrics
    func logPerformanceMetrics(
        flowId: String,
        metrics: ConversationFlowMetrics
    ) {
        AppLogger.log(
            tag: "📊 CONVERSATION-PERFORMANCE",
            message: """
            📋 Flow ID: \(flowId)
            ⏱️ Limit Check: \(String(format: "%.2f", metrics.limitCheckTime))s
            ⏱️ Algorithm: \(String(format: "%.2f", metrics.algorithmTime))s
            ⏱️ Chat Creation: \(String(format: "%.2f", metrics.chatCreationTime))s
            ⏱️ Total: \(String(format: "%.2f", metrics.totalTime))s
            """
        )
    }
}

// MARK: - Supporting Data Structures

enum ConversationUserType {
    case free
    case lite
    case plus
    case pro
    case newUser
    
    var description: String {
        switch self {
        case .free: return "FREE"
        case .lite: return "LITE"
        case .plus: return "PLUS"
        case .pro: return "PRO"
        case .newUser: return "NEW_USER"
        }
    }
}

enum ConversationFlowStep {
    case start
    case limitCheck
    case popupDisplay
    case usageIncrement
    case routingDecision
    case algorithmExecution
    case chatCreation
    case navigation
    
    var description: String {
        switch self {
        case .start: return "FLOW_START"
        case .limitCheck: return "LIMIT_CHECK"
        case .popupDisplay: return "POPUP_DISPLAY"
        case .usageIncrement: return "USAGE_INCREMENT"
        case .routingDecision: return "ROUTING_DECISION"
        case .algorithmExecution: return "ALGORITHM_EXECUTION"
        case .chatCreation: return "CHAT_CREATION"
        case .navigation: return "NAVIGATION"
        }
    }
}

struct RoutingDecision {
    let toInbox: Bool
    let isPaid: Bool
}

struct CompatibilityFactors {
    let userCountry: String
    let otherCountry: String
    let countryMatch: Bool
    
    let userGender: String
    let otherGender: String
    let genderMatch: Bool
    
    let userAge: Int
    let otherAge: Int
    let ageMatch: Bool
    
    let userLanguage: String
    let otherLanguage: String
    let languageMatch: Bool
}

struct CompatibilityResult {
    let mismatchCount: Int
    let details: [String: Bool]
}

struct ConversationFlowMetrics {
    let limitCheckTime: TimeInterval
    let algorithmTime: TimeInterval
    let chatCreationTime: TimeInterval
    let totalTime: TimeInterval
}
