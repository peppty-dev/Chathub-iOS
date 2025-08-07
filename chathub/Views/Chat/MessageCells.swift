import SwiftUI
import SDWebImageSwiftUI

// MARK: - Shared Gradient Background Component
/**
 * SharedGradientBackground provides a FIXED continuous gradient that spans the entire chat area.
 * Message bubbles reveal portions of this gradient based on their position,
 * creating the Instagram DM-like effect where all bubbles share the same background gradient.
 */
struct SharedGradientBackground: View {
    let gradientHeight: CGFloat
    let bubblePosition: CGFloat // Y position of the bubble in the scroll view
    let bubbleHeight: CGFloat
    
    // Create a FIXED gradient that all bubbles share
    private let fixedGradientColors = [
        Color.red,
        Color.orange, 
        Color.yellow,
        Color.green,
        Color.blue,
        Color.purple,
        Color.pink,
        Color.cyan,
        Color.red  // Loop back for seamless effect
    ]
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: fixedGradientColors),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: gradientHeight) // Large fixed height
        .offset(y: -bubblePosition) // Reveal correct portion based on bubble position
        .clipped() // Clip to bubble bounds
        .onAppear {
            print("🌈 SHARED GRADIENT: Fixed gradient at position \(bubblePosition) of total height \(gradientHeight)")
        }
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Codable {
    var id: String
    var text: String
    var isFromCurrentUser: Bool
    var timestamp: Date
    var isMessageSeen: Bool // Android Parity: Renamed from isRead to match Firebase field message_seen
    var hasAd: Bool
    var actualMessage: String
    var isPremium: Bool
    var isAIMessage: Bool
    var imageUrl: String?
    // Android Parity: Profanity masking state
    var containsProfanity: Bool = false
    var isProfanityMasked: Bool = false
    
    // Computed property for backward compatibility
    var isRead: Bool {
        get { isMessageSeen }
        set { isMessageSeen = newValue }
    }
    
    // MARK: - Logging Helper
    func logDetails(context: String, itemNumber: Int? = nil) {
        let itemInfo = itemNumber != nil ? "Item #\(itemNumber!)" : "Message"
        let side = isFromCurrentUser ? "RIGHT (Sent)" : "LEFT (Received)"
        let seenStatus = isMessageSeen ? "SEEN" : "UNSEEN"
        let profanityStatus = containsProfanity ? "CONTAINS_PROFANITY" : "CLEAN"
        let messageType = imageUrl != nil && !imageUrl!.isEmpty ? "IMAGE" : "TEXT"
        
        AppLogger.log(tag: "LOG-APP: MessageCells", message: "\(context) - \(itemInfo) | ID: \(id) | Side: \(side) | Type: \(messageType) | Status: \(seenStatus) | Profanity: \(profanityStatus) | Text: '\(text.prefix(50))\(text.count > 50 ? "..." : "")' | Timestamp: \(timestamp)")
    }
}

// MARK: - Message Position Types (Legacy - kept for compatibility)
enum MessagePosition {
    case standalone      // Single message with full corners and tail
    case firstInGroup   // First message in group (tail, but rounded top)
    case middleInGroup  // Middle message in group (no tail, partial rounding)
    case lastInGroup    // Last message in group (tail, rounded bottom)
}



// MARK: - Android-Parity Corner Radius Modifier
extension View {
    func messageCornerRadius(isFromCurrentUser: Bool) -> some View {
        // Android Parity: Exact corner radius values from Android
        let fullRadius: CGFloat = 20  // Android 30dp -> 15pt
        let smallRadius: CGFloat = 12  // Android 5dp -> 2.5pt
        
        // Android Parity: Corner radius logic
        // Right side messages (sent): Small corners on right (tail effect), full corners on left
        // Left side messages (received): Small corners on left (tail effect), full corners on right
        let topLeftRadius = isFromCurrentUser ? fullRadius : smallRadius
        let topRightRadius = isFromCurrentUser ? smallRadius : fullRadius
        let bottomLeftRadius = isFromCurrentUser ? fullRadius : smallRadius
        let bottomRightRadius = isFromCurrentUser ? smallRadius : fullRadius
        
        return self
            .clipShape(
                RoundedCornerShape(
                    topLeft: topLeftRadius,
                    topRight: topRightRadius,
                    bottomLeft: bottomLeftRadius,
                    bottomRight: bottomRightRadius
                )
            )
    }
}

// MARK: - Custom Rounded Corner Shape (Android Parity)
struct RoundedCornerShape: Shape {
    let topLeft: CGFloat
    let topRight: CGFloat
    let bottomLeft: CGFloat
    let bottomRight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.size.width
        let height = rect.size.height
        
        // Ensure corner radii don't exceed half the width or height
        let maxRadius = min(width, height) / 2
        let tl = min(topLeft, maxRadius)
        let tr = min(topRight, maxRadius)
        let bl = min(bottomLeft, maxRadius)
        let br = min(bottomRight, maxRadius)
        
        path.move(to: CGPoint(x: 0, y: tl))
        
        // Top-left corner
        if tl > 0 {
            path.addArc(
                center: CGPoint(x: tl, y: tl),
                radius: tl,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false
            )
        }
        
        // Top edge
        path.addLine(to: CGPoint(x: width - tr, y: 0))
        
        // Top-right corner
        if tr > 0 {
            path.addArc(
                center: CGPoint(x: width - tr, y: tr),
                radius: tr,
                startAngle: Angle(degrees: 270),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
        }
        
        // Right edge
        path.addLine(to: CGPoint(x: width, y: height - br))
        
        // Bottom-right corner
        if br > 0 {
            path.addArc(
                center: CGPoint(x: width - br, y: height - br),
                radius: br,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
        }
        
        // Bottom edge
        path.addLine(to: CGPoint(x: bl, y: height))
        
        // Bottom-left corner
        if bl > 0 {
            path.addArc(
                center: CGPoint(x: bl, y: height - bl),
                radius: bl,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
        }
        
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: tl))
        
        return path
    }
}

// MARK: - Modern Message Bubble View
/**
 * Modern Message Bubble with Simplified Corner Design
 *
 * CORNER STRATEGY:
 * - Right side messages (sent): Full rounded corners on left side, small corners on right side
 * - Left side messages (received): Small corners on left side, full rounded corners on right side
 * - This creates a natural "tail" effect pointing toward the sender
 *
 * TIMESTAMP DISPLAY:
 * - Shown on every message for consistency
 * - Format: Uses TimeFormatter utility (now, 1m, 2h, 3d, etc.)
 * - Includes "seen" status for sent messages that are read
 *
 * VISUAL DESIGN:
 * - Consistent corner rounding for all messages
 * - Clean, modern appearance without complex grouping logic
 * - Maintains conversation flow readability
 *
 * This approach provides optimal UX by:
 * - Simple, predictable visual design
 * - Clear message ownership indication
 * - Consistent timestamp display
 */
struct ModernMessageBubbleView: View {
    let message: ChatMessage
    let currentUserId: String
    let previousMessage: ChatMessage?
    let nextMessage: ChatMessage?
    
    // Android Parity: Profanity masking state
    @State private var isMessageRevealed: Bool = false
    
    init(message: ChatMessage, currentUserId: String, previousMessage: ChatMessage?, nextMessage: ChatMessage?) {
        self.message = message
        self.currentUserId = currentUserId
        self.previousMessage = previousMessage
        self.nextMessage = nextMessage
        
        // Log bubble view initialization
        AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.init() Initializing bubble view | Message ID: \(message.id) | Current User: \(currentUserId) | Has Previous: \(previousMessage != nil) | Has Next: \(nextMessage != nil)")
        message.logDetails(context: "BUBBLE_VIEW_INIT")
    }
    
    private var shouldShowTimestamp: Bool {
        // Simplified timestamp logic: Show timestamp on every message
        // This ensures consistency and removes complexity from grouping
        AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.shouldShowTimestamp Always showing timestamp for message: \(message.id)")
        return true
    }
    
    private var bubbleColor: Color {
        let color: Color
        if message.isFromCurrentUser {
            color = Color("ColorAccent")
        } else {
            color = Color("MessageBubbleGray")
        }
        
        AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.bubbleColor Selected color for message: \(message.id) | Side: \(message.isFromCurrentUser ? "RIGHT" : "LEFT") | Color: \(message.isFromCurrentUser ? "ColorAccent" : "MessageBubbleGray")")
        
        return color
    }
    
    private var textColor: Color {
        let color: Color
        if message.isFromCurrentUser {
            color = .white
        } else {
            color = Color("dark")
        }
        
        AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.textColor Selected text color for message: \(message.id) | Side: \(message.isFromCurrentUser ? "RIGHT" : "LEFT") | Color: \(message.isFromCurrentUser ? "white" : "dark")")
        
        return color
    }
    
    private var timestampColor: Color {
        let color: Color
        if message.isFromCurrentUser {
            color = .white.opacity(0.7) // Android white_500 equivalent
        } else {
            color = Color("shade6") // Android shade_600 equivalent - darker gray as requested
        }
        
        AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.timestampColor Selected timestamp color for message: \(message.id) | Side: \(message.isFromCurrentUser ? "RIGHT" : "LEFT") | Color: \(message.isFromCurrentUser ? "white.opacity(0.7)" : "shade6")")
        
        return color
    }
    
    private var bubbleHorizontalPadding: CGFloat {
        message.isFromCurrentUser ? 12 : 12
    }
    
    var body: some View {
        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.body Rendering bubble for message: \(message.id) | Side: \(message.isFromCurrentUser ? "RIGHT" : "LEFT")")
        
        return HStack(alignment: .bottom, spacing: 0) {
            if message.isFromCurrentUser {
                Spacer()
                sentMessageContent
            } else {
                receivedMessageContent
                Spacer()
            }
        }
        .padding(.horizontal, 10) // Android Parity: Consistent horizontal padding matching live button and status views
        .onAppear {
            AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.onAppear Message bubble appeared on screen | ID: \(message.id) | Side: \(message.isFromCurrentUser ? "RIGHT" : "LEFT")")
            message.logDetails(context: "BUBBLE_APPEARED")
        }
        .onDisappear {
            AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.onDisappear Message bubble disappeared from screen | ID: \(message.id) | Side: \(message.isFromCurrentUser ? "RIGHT" : "LEFT")")
        }
    }
    

    
    private var sentMessageContent: some View {
        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.sentMessageContent Rendering sent message content for: \(message.id)")
        
        return VStack(alignment: .trailing, spacing: 2) {
            messageContentView
        }
    }
    
    private var receivedMessageContent: some View {
        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.receivedMessageContent Rendering received message content for: \(message.id)")
        
        return VStack(alignment: .leading, spacing: 2) {
            messageContentView
        }
    }
    
    private var messageContentView: some View {
        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.messageContentView Determining content type for message: \(message.id) | Has image: \(message.imageUrl != nil && !message.imageUrl!.isEmpty)")
        
        return Group {
            if let imageUrl = message.imageUrl, !imageUrl.isEmpty {
                let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.messageContentView Rendering image message | ID: \(message.id) | URL: \(imageUrl)")
                imageMessageView(imageUrl: imageUrl)
            } else {
                let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.messageContentView Rendering text message | ID: \(message.id) | Text length: \(message.text.count)")
                textMessageView
            }
        }
    }
    
    private var textMessageView: some View {
        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.textMessageView Rendering text view for message: \(message.id) | Profanity: \(message.containsProfanity) | Revealed: \(isMessageRevealed)")
        
        // Android Pattern: Message text and timestamp in single line layout
        return Group {
            // Android Parity: Profanity masking logic
            if message.containsProfanity && !isMessageRevealed {
                let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.textMessageView Showing masked profanity message for: \(message.id)")
                
                // Show masked message (Android pattern) - separate layout for profanity
                VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 6) {
                    Text("This message contains inappropriate content.\nClick to view the message.")
                        .font(.system(size: 12, weight: .regular)) // Android uses 12sp for masked messages
                        .italic() // Android uses italic for masked messages
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.leading) // Always left-align
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture {
                            // Android Parity: Click to reveal functionality
                            AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.textMessageView User tapped to reveal profanity message: \(message.id)")
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isMessageRevealed = true
                            }
                            AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.textMessageView Profanity message revealed for: \(message.id)")
                        }
                    
                    // Timestamp for profanity message
                    if shouldShowTimestamp {
                        let timestampText = formatTime(message.timestamp)
                        Text(timestampText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(timestampColor)
                    }
                }
                .padding(.horizontal, bubbleHorizontalPadding) // Android Parity: Horizontal padding for message content
                .padding(.vertical, 8) // Android Parity: Consistent padding for profanity messages
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: 20)) // Symmetric 20 radius
            } else {
                let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.textMessageView Showing actual message text in single line layout for: \(message.id) | Text: '\(message.text.prefix(100))\(message.text.count > 100 ? "..." : "")'")
                
                // Single line layout for normal messages
                HStack(alignment: .bottom, spacing: 8) {
                    // Message text - takes available space
                    Text(message.text)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.leading) // Always left-align
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                    
                    // Timestamp - fixed size, doesn't wrap
                    if shouldShowTimestamp {
                        let timestampText = formatTime(message.timestamp)
                        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.textMessageView Showing timestamp in single line for message: \(message.id) | Timestamp: '\(timestampText)'")
                        
                        Text(timestampText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(timestampColor)
                            .fixedSize(horizontal: true, vertical: false) // Prevent timestamp from wrapping
                    }
                }
            }
        }
        .padding(.horizontal, bubbleHorizontalPadding) // Android Parity: Horizontal padding for message content
        .padding(.vertical, 8) // Android Parity: Vertical padding for message content
        .background(bubbleColor)
        .clipShape(RoundedRectangle(cornerRadius: 20)) // Symmetric 20 radius
    }
    
    private func imageMessageView(imageUrl: String) -> some View {
        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.imageMessageView Rendering image view for message: \(message.id) | URL: \(imageUrl)")
        
        // Android Pattern: Show image blob with timestamp in single line
        return HStack(alignment: .bottom, spacing: 8) {
            // Image text - takes available space
            Text("📷 Image - tap to view")
                .font(.system(size: 16, weight: .medium)) // Consistent with text messages
                .foregroundColor(.white)
            
            // Timestamp - fixed size, doesn't wrap
            if shouldShowTimestamp {
                let timestampText = formatTime(message.timestamp)
                let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.imageMessageView Showing timestamp in single line for image message: \(message.id) | Timestamp: '\(timestampText)'")
                
                Text(timestampText)
                    .font(.system(size: 11, weight: .medium)) // Consistent with text messages
                    .foregroundColor(.white.opacity(0.8)) // Slightly more opaque for better readability
                    .fixedSize(horizontal: true, vertical: false) // Prevent timestamp from wrapping
            }
        }
        .padding(.horizontal, bubbleHorizontalPadding) // Android Parity: Consistent with text messages
        .padding(.vertical, 8) // Android Parity: Consistent with text messages
        .background(Color("ColorAccent")) // Use accent color for all image messages
        .clipShape(RoundedRectangle(cornerRadius: 20)) // Symmetric 20 radius
    }
    
    // Android Parity: Format time with seen status (matching Android's exact format)
    private func formatTime(_ date: Date) -> String {
        AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.formatTime Formatting time for message: \(message.id) | Date: \(date) | Is from current user: \(message.isFromCurrentUser) | Is seen: \(message.isMessageSeen)")
        
        // Use TimeFormatter utility to match Android's exact timestamp format (now, 1m, 2h, 3d, etc.)
        let timeString = TimeFormatter.getTimeAgo(date)
        
        // Android Parity: Show "time • seen" format for sent messages that are seen
        // Only show "seen" status for messages from current user (sent messages) that are marked as seen
        if message.isFromCurrentUser && message.isMessageSeen {
            AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.formatTime Showing seen status for message: \(message.id) | Final format: '\(timeString) • seen'")
            return "\(timeString) • seen"
        } else {
            AppLogger.log(tag: "LOG-APP: MessageCells", message: "ModernMessageBubbleView.formatTime No seen status for message: \(message.id) | Final format: '\(timeString)'")
            return timeString
        }
    }
}

// MARK: - Enhanced Message Bubble View (Updated for MessagesView compatibility)
struct EnhancedMessageBubbleView: View {
    let message: ChatMessage
    let currentUserId: String
    let previousMessage: ChatMessage?
    let nextMessage: ChatMessage?
    
    init(message: ChatMessage, currentUserId: String, previousMessage: ChatMessage?, nextMessage: ChatMessage?) {
        self.message = message
        self.currentUserId = currentUserId
        self.previousMessage = previousMessage
        self.nextMessage = nextMessage
        
        AppLogger.log(tag: "LOG-APP: MessageCells", message: "EnhancedMessageBubbleView.init() Initializing enhanced bubble view | Message ID: \(message.id) | Current User: \(currentUserId)")
        message.logDetails(context: "ENHANCED_BUBBLE_INIT")
    }
    
    var body: some View {
        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "EnhancedMessageBubbleView.body Rendering enhanced bubble for message: \(message.id)")
        
        return ModernMessageBubbleView(
            message: message,
            currentUserId: currentUserId,
            previousMessage: previousMessage,
            nextMessage: nextMessage
        )
    }
}

// MARK: - Legacy Components (kept for backward compatibility)

struct LeftMessageCellView: View {
    let message: String
    let time: String
    let senderType: MessageSenderType
    let hasGap: Bool
    
    init(message: String, time: String, senderType: MessageSenderType, hasGap: Bool) {
        self.message = message
        self.time = time
        self.senderType = senderType
        self.hasGap = hasGap
        
        AppLogger.log(tag: "LOG-APP: MessageCells", message: "LeftMessageCellView.init() Legacy left message cell | Message: '\(message.prefix(50))' | Time: \(time) | Sender Type: \(senderType) | Has Gap: \(hasGap)")
    }
    
    var body: some View {
        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "LeftMessageCellView.body Rendering legacy left message cell | Message: '\(message.prefix(50))'")
        
        // Convert legacy to modern
        let chatMessage = ChatMessage(
            id: UUID().uuidString,
            text: message,
            isFromCurrentUser: false,
            timestamp: Date(),
            isMessageSeen: false,
            hasAd: false,
            actualMessage: message,
            isPremium: false,
            isAIMessage: false,
            containsProfanity: false,
            isProfanityMasked: false
        )
        
        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "LeftMessageCellView.body Converted to modern message | ID: \(chatMessage.id)")
        let _ = chatMessage.logDetails(context: "LEGACY_LEFT_CONVERTED")
        
        return ModernMessageBubbleView(
            message: chatMessage,
            currentUserId: "",
            previousMessage: nil,
            nextMessage: nil
        )
    }
}

struct RightMessageCellView: View {
    let message: String
    let time: String
    let bubbleStyle: Int
    let hasGap: Bool
    
    init(message: String, time: String, bubbleStyle: Int, hasGap: Bool) {
        self.message = message
        self.time = time
        self.bubbleStyle = bubbleStyle
        self.hasGap = hasGap
        
        AppLogger.log(tag: "LOG-APP: MessageCells", message: "RightMessageCellView.init() Legacy right message cell | Message: '\(message.prefix(50))' | Time: \(time) | Bubble Style: \(bubbleStyle) | Has Gap: \(hasGap)")
    }
    
    var body: some View {
        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "RightMessageCellView.body Rendering legacy right message cell | Message: '\(message.prefix(50))'")
        
        // Convert legacy to modern
        let chatMessage = ChatMessage(
            id: UUID().uuidString,
            text: message,
            isFromCurrentUser: true,
            timestamp: Date(),
            isMessageSeen: false,
            hasAd: false,
            actualMessage: message,
            isPremium: false,
            isAIMessage: false,
            containsProfanity: false,
            isProfanityMasked: false
        )
        
        let _ = AppLogger.log(tag: "LOG-APP: MessageCells", message: "RightMessageCellView.body Converted to modern message | ID: \(chatMessage.id)")
        let _ = chatMessage.logDetails(context: "LEGACY_RIGHT_CONVERTED")
        
        return ModernMessageBubbleView(
            message: chatMessage,
            currentUserId: "",
            previousMessage: nil,
            nextMessage: nil
        )
    }
}

// MARK: - Legacy Types (kept for compatibility)
enum MessageSenderType: Int, CaseIterable {
    case standalone = 0
    case firstInGroup = 1
    case middleInGroup = 2
    case lastInGroup = 3
    case firstOfTwoInGroup = 4
    case secondOfTwoInGroup = 5
    case singleAfterGap = 6
    case firstAfterGap = 7
    case lastBeforeGap = 8
}

struct CornerRadiusConfig {
    let topLeft: CGFloat
    let topRight: CGFloat
    let bottomLeft: CGFloat
    let bottomRight: CGFloat
    
    static func all(_ radius: CGFloat) -> Self {
        CornerRadiusConfig(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
    }
    
    static func selective(topLeft: CGFloat = 0, topRight: CGFloat = 0, bottomLeft: CGFloat = 0, bottomRight: CGFloat = 0) -> Self {
        CornerRadiusConfig(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
    }
}

struct MessageBubbleShape: Shape {
    let cornerConfig: CornerRadiusConfig
    
    init(isFromCurrentUser: Bool, senderType: MessageSenderType) {
        let radius: CGFloat = 18
        
        switch senderType {
        case .standalone:
            cornerConfig = CornerRadiusConfig.all(radius)
        case .firstInGroup:
            cornerConfig = CornerRadiusConfig.selective(topLeft: radius, topRight: radius, bottomLeft: 0, bottomRight: radius)
        case .middleInGroup:
            cornerConfig = CornerRadiusConfig.selective(topLeft: 0, topRight: radius, bottomLeft: 0, bottomRight: radius)
        case .lastInGroup:
            cornerConfig = CornerRadiusConfig.selective(topLeft: 0, topRight: radius, bottomLeft: radius, bottomRight: radius)
        case .firstOfTwoInGroup:
            cornerConfig = CornerRadiusConfig.selective(topLeft: radius, topRight: radius, bottomLeft: 0, bottomRight: radius)
        case .secondOfTwoInGroup:
            cornerConfig = CornerRadiusConfig.selective(topLeft: 0, topRight: radius, bottomLeft: radius, bottomRight: radius)
        case .singleAfterGap:
            cornerConfig = CornerRadiusConfig.selective(topLeft: 0, topRight: radius, bottomLeft: radius, bottomRight: radius)
        case .firstAfterGap:
            cornerConfig = CornerRadiusConfig.all(radius)
        case .lastBeforeGap:
            cornerConfig = CornerRadiusConfig.selective(topLeft: radius, topRight: radius, bottomLeft: 0, bottomRight: radius)
        }
    }
    
    init(isFromCurrentUser: Bool, bubbleStyle: Int) {
        let radius: CGFloat = 18
        
        switch bubbleStyle {
        case 0:
            cornerConfig = CornerRadiusConfig.all(radius)
        case 1:
            cornerConfig = CornerRadiusConfig.selective(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: 0)
        case 2:
            cornerConfig = CornerRadiusConfig.selective(topLeft: radius, topRight: 0, bottomLeft: radius, bottomRight: radius)
        default:
            cornerConfig = CornerRadiusConfig.selective(topLeft: radius, topRight: 0, bottomLeft: radius, bottomRight: 0)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start from top-left corner
        path.move(to: CGPoint(x: rect.minX + cornerConfig.topLeft, y: rect.minY))
        
        // Top edge to top-right corner
        path.addLine(to: CGPoint(x: rect.maxX - cornerConfig.topRight, y: rect.minY))
        
        // Top-right corner
        if cornerConfig.topRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - cornerConfig.topRight, y: rect.minY + cornerConfig.topRight),
                       radius: cornerConfig.topRight,
                       startAngle: Angle(degrees: -90),
                       endAngle: Angle(degrees: 0),
                       clockwise: false)
        }
        
        // Right edge to bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerConfig.bottomRight))
        
        // Bottom-right corner
        if cornerConfig.bottomRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - cornerConfig.bottomRight, y: rect.maxY - cornerConfig.bottomRight),
                       radius: cornerConfig.bottomRight,
                       startAngle: Angle(degrees: 0),
                       endAngle: Angle(degrees: 90),
                       clockwise: false)
        }
        
        // Bottom edge to bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + cornerConfig.bottomLeft, y: rect.maxY))
        
        // Bottom-left corner
        if cornerConfig.bottomLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + cornerConfig.bottomLeft, y: rect.maxY - cornerConfig.bottomLeft),
                       radius: cornerConfig.bottomLeft,
                       startAngle: Angle(degrees: 90),
                       endAngle: Angle(degrees: 180),
                       clockwise: false)
        }
        
        // Left edge to top-left corner
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerConfig.topLeft))
        
        // Top-left corner
        if cornerConfig.topLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + cornerConfig.topLeft, y: rect.minY + cornerConfig.topLeft),
                       radius: cornerConfig.topLeft,
                       startAngle: Angle(degrees: 180),
                       endAngle: Angle(degrees: 270),
                       clockwise: false)
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Chat List Cell (for ChatsView)
// Note: This component is defined in ChatsTabView.swift with proper dependencies

// MARK: - Profile Image View
struct ProfileImageView: View {
    let imageUrl: String
    let gender: String
    let size: CGFloat
    
    var body: some View {
        if imageUrl == "null" || imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Image(gender == "Male" ? "male" : "female")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()
        } else {
            WebImage(url: URL(string: imageUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(gender == "Male" ? "male" : "female")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .frame(width: size, height: size)
            .clipped()
        }
    }
}

// MARK: - Chat Type Icon View
struct ChatTypeIconView: View {
    let chatType: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 40, height: 40)
            
            Image(iconName)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(iconColor)
        }
    }
    
    private var iconName: String {
        // Only handle regular chat type (excluded features: roleplay, channel, room)
        return "chat copy"
    }
    
    private var backgroundColor: Color {
        // Only handle regular chat type (excluded features: roleplay, channel, room)
        return Color("AudioBackground")
    }
    
    private var iconColor: Color {
        // Only handle regular chat type (excluded features: roleplay, channel, room)
        return Color("Audio")
    }
}

// MARK: - People Table View Cell
// Note: This component is defined in PeopleTabView.swift with proper dependencies

// MARK: - Notification Table View Cell
struct NotificationTableCellView: View {
    let notification: LocalNotificationItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon/Image
            ZStack {
                Circle()
                    .fill(notificationBackgroundColor)
                    .frame(width: 60, height: 60)
                
                Image(systemName: notificationIconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(notificationIconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(notification.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color("dark"))
                    .lineLimit(1)
                
                // Message
                Text(notification.message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.gray)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Time
            Text(formatTime(notification.timestamp))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.gray)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(minHeight: 80)
        .contentShape(Rectangle())
    }
    
    private var notificationIconName: String {
        switch notification.type {
        case .message:
            return "message.fill"
        case .call:
            return "phone.fill"
        case .videoCall:
            return "video.fill"
        case .system:
            return "gear"
        case .friend:
            return "person.fill"
        }
    }
    
    private var notificationBackgroundColor: Color {
        switch notification.type {
        case .message:
            return Color("blue").opacity(0.1)
        case .call:
            return Color("green").opacity(0.1)
        case .videoCall:
            return Color("red").opacity(0.1)
        case .system:
            return Color("gray").opacity(0.1)
        case .friend:
            return Color("orange").opacity(0.1)
        }
    }
    
    private var notificationIconColor: Color {
        switch notification.type {
        case .message:
            return Color("blue")
        case .call:
            return Color.green
        case .videoCall:
            return Color.red
        case .system:
            return Color.gray
        case .friend:
            return Color.orange
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let timeInterval = Int(Date().timeIntervalSinceReferenceDate - date.timeIntervalSinceReferenceDate)
            if timeInterval < 60 {
                return "now"
            } else if timeInterval < 3600 {
                return "\(timeInterval / 60)m"
            } else {
                return "\(timeInterval / 3600)h"
            }
        } else {
            let components = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date()))
            let days = components.day ?? 0
            return "\(days)d"
        }
    }
}

// MARK: - Notification Model
struct LocalNotificationItem: Identifiable {
    let id: String
    let title: String
    let message: String
    let timestamp: Date
    let type: NotificationType
    let isRead: Bool
}

enum NotificationType {
    case message
    case call
    case videoCall
    case system
    case friend
}

// MARK: - Inbox Table View Cell
struct InboxTableCellView: View {
    let inboxItem: InboxItem
    
    var body: some View {
        VStack {
            // Main container with shadow
            VStack(spacing: 0) {
                // Header section
                HStack(spacing: 15) {
                    // Inbox icon
                    Image("inboxfill")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundColor(Color("ButtonColor"))
                    
                    // Title
                    Text("Inbox")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.primary)
                    
                    // Count
                    Text("· \(inboxItem.count)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 15)
                .padding(.top, 14)
                
                // Preview section (semi-transparent)
                HStack(spacing: 15) {
                    // Profile image
                    ProfileImageView(
                        imageUrl: inboxItem.previewUser?.profileImage ?? "",
                        gender: inboxItem.previewUser?.gender ?? "Male",
                        size: 60
                    )
                    .clipShape(Circle())
                    
                    // User details
                    VStack(alignment: .leading, spacing: 8) {
                        Text(inboxItem.previewUser?.name ?? "No messages")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color("shade9"))
                            .lineLimit(1)
                        
                        Text(inboxItem.previewMessage ?? "Your inbox is empty")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color("shade8"))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color("background"))
                        .opacity(0.5)
                )
                .padding(.horizontal, 15)
                .padding(.bottom, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color("shade2"))
                    .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 5)
        }
        .frame(height: 150)
        .contentShape(Rectangle())
    }
}

// MARK: - Inbox Model
struct InboxItem {
    let count: Int
    let previewUser: InboxPreviewUser?
    let previewMessage: String?
}

struct InboxPreviewUser {
    let name: String
    let profileImage: String
    let gender: String
}

// MARK: - Previews
#Preview("Modern Message Bubbles - Android Parity") {
    VStack(spacing: 8) {
        // Received messages (small corners on left for tail effect, full corners on right)
        ModernMessageBubbleView(
            message: ChatMessage(
                id: "1",
                text: "Hey! How are you doing today?",
                isFromCurrentUser: false,
                timestamp: Date(),
                isMessageSeen: false,
                hasAd: false,
                actualMessage: "Hey! How are you doing today?",
                isPremium: false,
                isAIMessage: false,
                containsProfanity: false,
                isProfanityMasked: false
            ),
            currentUserId: "current",
            previousMessage: nil,
            nextMessage: nil
        )
        
        ModernMessageBubbleView(
            message: ChatMessage(
                id: "2",
                text: "I'm doing great! Thanks for asking.",
                isFromCurrentUser: false,
                timestamp: Date(),
                isMessageSeen: false,
                hasAd: false,
                actualMessage: "I'm doing great! Thanks for asking.",
                isPremium: false,
                isAIMessage: false,
                containsProfanity: false,
                isProfanityMasked: false
            ),
            currentUserId: "current",
            previousMessage: nil,
            nextMessage: nil
        )
        
        // Sent messages (full corners on left, small corners on right for tail effect)
        ModernMessageBubbleView(
            message: ChatMessage(
                id: "3",
                text: "That's awesome to hear! 😊",
                isFromCurrentUser: true,
                timestamp: Date(),
                isMessageSeen: true,
                hasAd: false,
                actualMessage: "That's awesome to hear! 😊",
                isPremium: false,
                isAIMessage: false,
                containsProfanity: false,
                isProfanityMasked: false
            ),
            currentUserId: "current",
            previousMessage: nil,
            nextMessage: nil
        )
        
        ModernMessageBubbleView(
            message: ChatMessage(
                id: "4",
                text: "What are you up to today?",
                isFromCurrentUser: true,
                timestamp: Date(),
                isMessageSeen: false,
                hasAd: false,
                actualMessage: "What are you up to today?",
                isPremium: false,
                isAIMessage: false,
                containsProfanity: false,
                isProfanityMasked: false
            ),
            currentUserId: "current",
            previousMessage: nil,
            nextMessage: nil
        )
    }
    .padding()
    .background(Color("Background Color"))
} 