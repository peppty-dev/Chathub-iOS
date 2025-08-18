# Two-Layer Safety Signal Collection System

## Executive Summary

This document defines ChatHub's comprehensive two-layer safety signal collection system that combines fast, action-oriented detection with sophisticated AI-powered categorization for complete safety compliance and user protection.

## System Architecture Overview

### **Layer 1: Fast Detection + Immediate Action**
- **Purpose**: Real-time user protection and immediate threat mitigation
- **Response Time**: Instantaneous (< 50ms)
- **User Impact**: Direct (blocks, warnings, penalties)
- **Technology**: Rule-based profanity detection

### **Layer 2: Advanced Detection + Data Collection**
- **Purpose**: Comprehensive safety intelligence and compliance tracking
- **Response Time**: Background processing (< 200ms)
- **User Impact**: None (silent data collection)
- **Technology**: AI/ML-powered content analysis

## Detailed Layer Specifications

### **🚨 Layer 1: Immediate Protection System**

#### **Detection Methods**:
```swift
// Fast rule-based detection
Profanity.share.doesContainProfanity(text)           // General profanity
Profanity.share.doesContainProfanityAppName(text)    // App name violations  
Profanity.share.doesContainProfanityNumbersAllowed(text) // Number-inclusive profanity
```

#### **Immediate Actions**:

| **Detection Type** | **Penalty** | **Action** | **User Experience** |
|-------------------|-------------|------------|---------------------|
| **General Profanity** | +10 score | First message blocks sending | Message not sent, no notification |
| **App Name Violation** | +101 score | Immediate conversation move | Moved to inbox, user notified |
| **Numbers + Profanity** | +10 score | Standard profanity handling | Same as general profanity |

#### **Immediate Action Logic**:
```swift
// Current implementation in MessagesView.sendMessage()
if Profanity.share.doesContainProfanityAppName(text) {
    // IMMEDIATE: High penalty for app name violations
    ModerationSettingsSessionManager.shared.hiveTextModerationScore += 101
    // IMMEDIATE: Move conversation to inbox
    setMoveToInbox(true)
}

if !conversationStarted && bad {
    // IMMEDIATE: Block first message with profanity
    ModerationSettingsSessionManager.shared.hiveTextModerationScore += 10
    // IMMEDIATE: Prevent message from sending
    return // Message blocked
}
```

#### **Layer 1 Characteristics**:
- ✅ **Blocking**: Prevents message from being sent
- ✅ **Scoring**: Updates user moderation scores immediately
- ✅ **Flow Control**: Changes conversation behavior
- ✅ **User Feedback**: Shows warnings and notifications
- ✅ **Performance**: < 50ms response time
- ✅ **Reliability**: Simple, tested rule-based logic

---

### **🤖 Layer 2: Intelligence Collection System**

#### **Detection Methods**:
```swift
// Advanced AI/ML analysis
ProfanityFilterService.shared.analyzeContent(text, config: FilterConfig(
    strictnessLevel: .moderate,
    enableSentimentAnalysis: true,
    enablePatternDetection: true, 
    enableContextAnalysis: true,
    profanityThreshold: 0.1
))
```

#### **AI Analysis Components**:

1. **Sentiment Analysis**
   - Detects negative emotional content
   - Maps to toxicity/harassment categories
   - Uses Apple's NLTagger framework

2. **Pattern Detection**
   - Identifies offensive language patterns
   - Regex-based threat detection
   - Harassment and bullying identification

3. **Context Analysis**
   - Aggressive language detection
   - Excessive capitalization (shouting)
   - Suspicious conversation patterns

4. **Word-level Analysis**
   - Profanity ratio calculation
   - Strictness-based classification
   - Advanced word boundary detection

#### **Safety Category Mapping**:

| **AI Detection Result** | **Safety Category** | **Counter Field** | **Action** |
|------------------------|---------------------|-------------------|------------|
| Negative sentiment | Toxicity/Harassment | `toxicity_hits_30d` | Silent increment |
| Hate speech patterns | Hate/Violence | `hate_hits_30d` | Silent increment |
| Threat patterns | Hate/Violence | `violent_threat_hits_30d` | Silent increment |
| Adult language | Adult Content | `adult_text_hits_30d` | Silent increment |
| Scam patterns | Scam/Spam | `scam_hits_30d` | Silent increment |
| PII detection | Privacy Violations | `pii_share_hits_30d` | Silent increment |
| Self-harm content | Self-Harm | `self_harm_hits_30d` | Silent increment |
| Extremist content | Extremism | `extremism_hits_30d` | Silent increment |
| Child safety threats | Child Safety | `child_exploitation_hits_30d` | Silent increment |
| Terrorism content | Terrorism/Security | `terrorism_content_hits_30d` | Silent increment |

#### **Layer 2 Characteristics**:
- ❌ **No Blocking**: Messages are sent normally
- ❌ **No User Penalties**: No immediate score changes
- ❌ **No UI Changes**: No warnings or notifications
- ✅ **Data Collection**: Updates safety signal database
- ✅ **Compliance**: Builds comprehensive safety intelligence
- ✅ **Analytics**: Powers internal safety dashboards

---

## Implementation Architecture

### **Integration Point: MessagesView.sendMessage()**

```swift
private func sendMessage() {
    let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    
    // ⚡ LAYER 1: Fast Detection + Immediate Action
    let appNameViolation = Profanity.share.doesContainProfanityAppName(text)
    let generalProfanity = Profanity.share.doesContainProfanity(text)
    
    // IMMEDIATE ACTIONS
    if appNameViolation {
        ModerationSettingsSessionManager.shared.hiveTextModerationScore += 101
        AppLogger.log(tag: "MessagesView", message: "Layer 1: App name violation - blocking")
        // Block sending logic...
        return
    }
    
    if !conversationStarted && generalProfanity {
        ModerationSettingsSessionManager.shared.hiveTextModerationScore += 10
        AppLogger.log(tag: "MessagesView", message: "Layer 1: First message profanity - blocking")
        // Block sending logic...
        return
    }
    
    // 🤖 LAYER 2: Advanced Analysis (Background/Async)
    DispatchQueue.global(qos: .utility).async {
        SafetySignalManager.shared.analyzeMessageForSafetySignals(
            text, 
            userId: self.otherUser.id
        )
    }
    
    // Continue with normal message sending...
    let messageData: [String: Any] = [
        "message": text,
        "timestamp": Date().timeIntervalSince1970,
        // ... other fields
    ]
    
    FirebaseManager.shared.sendMessage(messageData)
}
```

### **SafetySignalManager Implementation**

```swift
class SafetySignalManager {
    static let shared = SafetySignalManager()
    
    func analyzeMessageForSafetySignals(_ text: String, userId: String) {
        // This runs in background - NO user impact
        AppLogger.log(tag: "SafetySignalManager", message: "Layer 2: Starting silent analysis")
        
        // 1. Advanced AI Analysis
        let aiResults = ProfanityFilterService.shared.analyzeContent(text)
        
        // 2. Specialized Pattern Detection
        let childSafetyThreats = detectChildSafetyThreats(text)
        let terrorismContent = detectTerrorismContent(text)
        let scamPatterns = detectScamSpam(text)
        let privacyViolations = detectPrivacyViolations(text)
        
        // 3. Map to Safety Categories
        var detectedCategories: [SafetyCategory] = []
        
        switch aiResults {
        case .safe:
            break // No categories detected
        case .questionable(let reasons), .unsafe(let reasons):
            detectedCategories.append(contentsOf: mapReasonsToCategories(reasons))
        }
        
        // Add specialized detections
        if !childSafetyThreats.isEmpty {
            detectedCategories.append(.childSafety)
        }
        if !terrorismContent.isEmpty {
            detectedCategories.append(.terrorismSecurity)
        }
        
        // 4. Update Database (Silent - No User Impact)
        updateSafetyCounters(categories: detectedCategories, userId: userId)
        
        AppLogger.log(tag: "SafetySignalManager", message: "Layer 2: Silent analysis complete")
    }
    
    private func updateSafetyCounters(categories: [SafetyCategory], userId: String) {
        let currentTime = Date().timeIntervalSince1970
        
        // Firebase update - completely silent
        let safetyRef = Firestore.firestore()
            .collection("Users").document(userId)
            .collection("Profile").document("safety")
        
        var updateData: [String: Any] = [:]
        
        for category in categories {
            updateData["\(category.rawValue)_hits_30d"] = FieldValue.increment(Int64(1))
            updateData["\(category.rawValue)_timestamps"] = FieldValue.arrayUnion([currentTime])
        }
        
        if !categories.isEmpty {
            updateData["total_flags_30d"] = FieldValue.increment(Int64(categories.count))
            updateData["last_flag_at"] = currentTime
        }
        
        safetyRef.updateData(updateData) { error in
            if let error = error {
                AppLogger.log(tag: "SafetySignalManager", message: "Layer 2: Database update failed: \(error)")
            } else {
                AppLogger.log(tag: "SafetySignalManager", message: "Layer 2: Safety signals updated silently")
            }
        }
    }
}
```

## Data Flow Architecture

### **Layer 1 Flow: Immediate Protection**
```
User types message 
    ↓
Layer 1 Detection (< 50ms)
    ↓
[IF VIOLATION DETECTED]
    ↓
Immediate Action:
- Block message sending
- Update moderation score  
- Show user warning
- Change conversation flow
    ↓
User Experience Impact
```

### **Layer 2 Flow: Intelligence Collection**
```
Message successfully sent
    ↓
Background AI Analysis (< 200ms)
    ↓  
Category Detection:
- Sentiment analysis
- Pattern matching
- Specialized threat detection
    ↓
Silent Database Update:
- Increment 30-day counters
- Update safety subdocument
- No user notification
    ↓
Analytics Dashboard Update
```

## Storage Architecture

### **Layer 1 Storage: Immediate Actions**
```
// Local UserDefaults (SessionManager)
ModerationSettingsSessionManager.shared.hiveTextModerationScore

// Firebase Root Document  
Users/{userId} {
    textModerationScore: 15,
    imageModerationScore: 3,
    showTextModerationWarning: true
}
```

### **Layer 2 Storage: Safety Intelligence**
```
// Firebase Safety Subdocument
Users/{userId}/Profile/safety {
    // Adult Content
    adult_text_hits_30d: 5,
    adult_image_hits_30d: 2,
    
    // Toxicity/Harassment  
    toxicity_hits_30d: 3,
    harassment_hits_30d: 1,
    bullying_hits_30d: 0,
    
    // Hate/Violence
    hate_hits_30d: 0,
    violent_threat_hits_30d: 0,
    graphic_gore_hits_30d: 0,
    
    // Scam/Spam
    scam_hits_30d: 1,
    spam_ads_hits_30d: 2,
    phishing_link_hits_30d: 0,
    
    // Privacy Violations
    doxxing_attempt_hits_30d: 0,
    pii_share_hits_30d: 1,
    
    // Self-Harm
    self_harm_hits_30d: 0,
    
    // Extremism
    extremism_hits_30d: 0,
    
    // Child Safety
    child_exploitation_hits_30d: 0,
    child_grooming_hits_30d: 0,
    underage_content_hits_30d: 0,
    child_endangerment_hits_30d: 0,
    
    // Terrorism/Security
    terrorism_content_hits_30d: 0,
    violence_incitement_hits_30d: 0,
    weapon_trafficking_hits_30d: 0,
    coordinated_harmful_activity_hits_30d: 0,
    
    // Aggregates
    total_flags_30d: 15,
    last_flag_at: 1703123456789
}
```

## Performance Considerations

### **Layer 1 Performance Requirements**
- **Response Time**: < 50ms (critical path)
- **Memory Usage**: Minimal (cached profanity sets)
- **CPU Impact**: Low (simple string matching)
- **User Experience**: Zero latency perception

### **Layer 2 Performance Requirements**  
- **Response Time**: < 200ms (background processing)
- **Memory Usage**: Moderate (AI model loading)
- **CPU Impact**: Medium (NLP processing)
- **User Experience**: Completely invisible

### **Optimization Strategies**
1. **Layer 1**: Pre-loaded profanity sets with NSCache
2. **Layer 2**: Background queue processing
3. **Database**: Batch updates to reduce Firebase calls
4. **Memory**: Lazy loading of AI models
5. **Network**: Compressed data payloads

## Security and Privacy

### **Data Protection**
- **Layer 1**: No raw content stored (only scores)
- **Layer 2**: No raw offensive content stored (only counters)
- **Compliance**: GDPR/CCPA compliant (aggregated data only)
- **Retention**: 30-day rolling windows with auto-cleanup

### **Privacy Safeguards**
- **User Anonymity**: No personal identification in safety signals
- **Content Privacy**: Original messages never stored in safety system
- **Access Control**: Safety data only accessible to authorized systems
- **Audit Trail**: All safety actions logged for compliance

## Testing Strategy

### **Layer 1 Testing**
- **Unit Tests**: Profanity detection accuracy
- **Integration Tests**: Message blocking functionality  
- **Performance Tests**: Response time < 50ms
- **User Experience Tests**: Smooth blocking behavior

### **Layer 2 Testing**
- **AI Model Tests**: Category detection accuracy
- **Background Processing Tests**: No UI blocking
- **Database Tests**: Correct counter updates
- **Privacy Tests**: No raw content leakage

### **End-to-End Testing**
- **Combined Scenarios**: Both layers working together
- **Edge Cases**: Unusual content patterns
- **Scale Testing**: High message volume handling
- **Compliance Testing**: All 9 safety categories covered

## Monitoring and Analytics

### **Layer 1 Metrics**
- **Block Rate**: Messages blocked per hour
- **False Positives**: Legitimate messages blocked
- **Response Time**: Detection speed metrics
- **User Impact**: Warning display frequency

### **Layer 2 Metrics**  
- **Detection Coverage**: Categories detected per message
- **Processing Speed**: AI analysis completion time
- **Data Quality**: Counter accuracy validation
- **Compliance Coverage**: All safety categories active

### **Combined System Metrics**
- **Overall Safety**: Total threats detected
- **System Health**: Both layers operational
- **Compliance Status**: Legal requirement coverage
- **Performance Impact**: User experience preservation

## Future Enhancements

### **Phase 1 Extensions**
- **Dynamic Thresholds**: Adaptive detection sensitivity
- **Machine Learning**: Improved pattern recognition
- **Real-time Updates**: Live profanity set updates
- **Advanced Patterns**: More sophisticated threat detection

### **Phase 2 Extensions**  
- **Behavioral Analysis**: User pattern recognition
- **Cross-Platform Sync**: Consistent safety across devices
- **Advanced AI**: Custom-trained safety models
- **Predictive Safety**: Proactive threat prevention

### **Phase 3 Extensions**
- **Community Safety**: User-driven moderation
- **Advanced Analytics**: Comprehensive safety insights
- **Automated Actions**: Smart response escalation
- **Global Safety**: Multi-language threat detection

## Implementation Timeline

### **Week 1-2: Foundation**
- [ ] Create SafetySignalManager class
- [ ] Implement two-layer integration
- [ ] Basic category mapping
- [ ] Layer 1 preservation (keep existing logic)

### **Week 3-4: Advanced Detection**
- [ ] Implement all 9 safety category detections
- [ ] Add specialized pattern detection
- [ ] Create 30-day rolling counter system
- [ ] Database storage structure

### **Week 5-6: Integration & Testing**
- [ ] Full MessagesView integration
- [ ] Comprehensive testing suite
- [ ] Performance optimization
- [ ] Documentation completion

### **Week 7-8: Deployment**
- [ ] Production deployment
- [ ] Monitoring setup
- [ ] Analytics dashboard
- [ ] Compliance verification

## Success Criteria

### **Technical Success**
- ✅ Layer 1: 100% preservation of existing blocking behavior
- ✅ Layer 2: 95%+ safety category coverage
- ✅ Performance: No user experience degradation
- ✅ Reliability: 99.9% uptime for safety systems

### **Business Success**
- ✅ Compliance: Full App Store policy adherence
- ✅ Safety: Comprehensive threat detection
- ✅ User Experience: Seamless protection
- ✅ Analytics: Rich safety intelligence

### **Compliance Success**
- ✅ Child Safety: Zero tolerance enforcement
- ✅ Terrorism Prevention: Comprehensive detection
- ✅ Privacy Protection: GDPR/CCPA compliance
- ✅ Platform Policies: App Store guideline adherence

## Conclusion

The Two-Layer Safety Signal Collection System provides ChatHub with:

1. **Immediate Protection**: Fast, reliable threat blocking (Layer 1)
2. **Comprehensive Intelligence**: Complete safety categorization (Layer 2) 
3. **User Experience**: Seamless, non-disruptive operation
4. **Compliance**: Full regulatory and platform policy adherence
5. **Scalability**: Foundation for advanced safety features

This architecture transforms ChatHub from basic profanity detection to a sophisticated, compliant safety platform while maintaining the fast, smooth user experience that makes the app successful.

**Layer 1 ensures user protection. Layer 2 ensures platform compliance. Together, they provide comprehensive safety without compromising user experience.**
