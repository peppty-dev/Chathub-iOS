import Foundation


// MARK: - Callback Classes for ProfileView (Android Parity)

// MessageLimitCallback implementation removed - using new unified system

// ConversationLimitCallback implementation for ProfileView
class ProfileViewConversationLimitCallback: ConversationLimitCallback {
    private let onCanProceedClosure: () -> Void
    private let onShowDialogClosure: () -> Void
    private let onErrorClosure: (Error) -> Void
    
    init(onCanProceed: @escaping () -> Void, onShowDialog: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        self.onCanProceedClosure = onCanProceed
        self.onShowDialogClosure = onShowDialog
        self.onErrorClosure = onError
    }
    
    func onCanProceed() {
        onCanProceedClosure()
    }
    
    func onShowDialog() {
        onShowDialogClosure()
    }
    
    func onError(_ error: Error) {
        onErrorClosure(error)
    }
}

// New ChatFlowCallback implementation for ProfileView (Simplified)
class ProfileViewChatFlowCallback: ChatFlowCallback {
    private let onChatCreatedClosure: (String, String) -> Void
    private let onErrorClosure: (Error) -> Void
    
    init(onChatCreated: @escaping (String, String) -> Void, onError: @escaping (Error) -> Void) {
        self.onChatCreatedClosure = onChatCreated
        self.onErrorClosure = onError
    }
    
    func onChatCreated(chatId: String, otherUserId: String) {
        onChatCreatedClosure(chatId, otherUserId)
    }
    
    func onError(_ error: Error) {
        onErrorClosure(error)
    }
}

// Legacy ChatFlowCallback implementation for backward compatibility
class LegacyProfileViewChatFlowCallback: LegacyChatFlowCallback {
    private let onChatCreatedClosure: (String, String) -> Void
    private let onShowMonetizationDialogClosure: (Int, Bool) -> Void
    private let onErrorClosure: (Error) -> Void
    
    init(onChatCreated: @escaping (String, String) -> Void, onShowMonetizationDialog: @escaping (Int, Bool) -> Void, onError: @escaping (Error) -> Void) {
        self.onChatCreatedClosure = onChatCreated
        self.onShowMonetizationDialogClosure = onShowMonetizationDialog
        self.onErrorClosure = onError
    }
    
    func onChatCreated(chatId: String, otherUserId: String) {
        onChatCreatedClosure(chatId, otherUserId)
    }
    
    func onShowMonetizationDialog(coins: Int, freeMessage: Bool) {
        onShowMonetizationDialogClosure(coins, freeMessage)
    }
    
    func onError(_ error: Error) {
        onErrorClosure(error)
    }
}

// Ad callback classes removed - no longer needed with new limit system