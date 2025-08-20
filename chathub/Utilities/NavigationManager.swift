import SwiftUI
import UIKit

// MARK: - Wrapper Views for Report Popups

struct UserReportPopupWrapper: View {
    let reportedUserId: String
    @State private var isPresented = true
    
    var body: some View {
        // Create an OnlineUser from the userId string
        let reportedUser = OnlineUser(
            id: reportedUserId,
            name: "Unknown User", // Default name
            age: "",
            country: "",
            gender: "",
            isOnline: false,
            language: "",
            lastTimeSeen: Date(),
            deviceId: "",
            profileImage: ""
        )
        
        UserReportView(
            isPresented: $isPresented,
            reportedUser: reportedUser,
            onReportSubmitted: {
                // Handle report submission if needed
                AppLogger.log(tag: "LOG-APP: NavigationManager", message: "User report submitted for user: \(reportedUserId)")
            }
        )
    }
}

struct PhotoReportPopupWrapper: View {
    let imageUrl: String
    let imageUserId: String
    @State private var isPresented = true
    
    var body: some View {
        PhotoReportView(imageUrl: imageUrl, imageUserId: imageUserId, isPresented: $isPresented)
    }
}

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    private init() {}
    
    deinit {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "NavigationManager deinit called - cleaning up resources")
        // Clean up any resources if needed
    }
    
    // MARK: - Navigation to SwiftUI Views
    
    func navigateToProfile(userId: String, userName: String, userImage: String) {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToProfile() navigating to profile for user: \(userName)")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let profileView = UIHostingController(rootView: ProfileView(otherUserId: userId))
            
            if let navController = rootVC.presentedViewController as? UINavigationController ??
                                  rootVC as? UINavigationController {
                navController.pushViewController(profileView, animated: true)
            } else {
                rootVC.present(profileView, animated: true)
            }
        }
    }
    
    func navigateToMessages(otherUserId: String, otherUserName: String, otherUserImage: String) {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToMessages() navigating to messages with: \(otherUserName)")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // Create ChatUser object for MessagesView
            let otherUser = ChatUser(
                id: otherUserId,
                name: otherUserName,
                profileImage: otherUserImage,
                gender: "", // Default empty
                deviceId: "", // Default empty
                isOnline: false // Default false
            )
            
            // Use a default chatId - in a real implementation, this would be fetched/generated
            let chatId = "chat_\(otherUserId)_\(SessionManager.shared.userId ?? "")"
            
            let messagesView = UIHostingController(rootView: MessagesView(chatId: chatId, otherUser: otherUser, isFromInbox: false))
            
            if let navController = rootVC.presentedViewController as? UINavigationController ??
                                  rootVC as? UINavigationController {
                navController.pushViewController(messagesView, animated: true)
            } else {
                rootVC.present(messagesView, animated: true)
            }
        }
    }
    
    func navigateToInbox() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToInbox() navigating to inbox")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let inboxView = UIHostingController(rootView: InboxView())
            
            if let navController = rootVC.presentedViewController as? UINavigationController ??
                                  rootVC as? UINavigationController {
                navController.pushViewController(inboxView, animated: true)
            } else {
                rootVC.present(inboxView, animated: true)
            }
        }
    }
    
    func navigateToGameProfile(game: Games) {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToGameProfile() navigating to game: \(game.GameName)")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // Convert Games to GameDetail
            let gameDetail = GameDetail(
                gameId: game.GameId,
                gameUrl: game.GameUrl,
                gameName: game.GameName,
                gameDescription: game.GameDescription,
                gameIcon: game.GameIcon,
                gameCover: game.GameCover,
                gameRating: game.GameRating,
                gamePlays: game.GamePlays,
                isMultiplayer: game.Multiplayer,
                adAvailable: game.Adavailable
            )
            
            let gameProfileView = UIHostingController(rootView: GameProfileView(game: gameDetail))
            
            if let navController = rootVC.presentedViewController as? UINavigationController ??
                                  rootVC as? UINavigationController {
                navController.pushViewController(gameProfileView, animated: true)
            } else {
                rootVC.present(gameProfileView, animated: true)
            }
        }
    }
    
    func navigateToMultiplayerGames() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToMultiplayerGames() navigating to multiplayer games")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let multiplayerView = UIHostingController(rootView: MultiplayerGamesView())
            
            if let navController = rootVC.presentedViewController as? UINavigationController ??
                                  rootVC as? UINavigationController {
                navController.pushViewController(multiplayerView, animated: true)
            } else {
                rootVC.present(multiplayerView, animated: true)
            }
        }
    }
    
    func navigateToRecentGames() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToRecentGames() navigating to recent games")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let recentGamesView = UIHostingController(rootView: RecentGamesView())
            
            if let navController = rootVC.presentedViewController as? UINavigationController ??
                                  rootVC as? UINavigationController {
                navController.pushViewController(recentGamesView, animated: true)
            } else {
                rootVC.present(recentGamesView, animated: true)
            }
        }
    }
    
    func navigateToFilters() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToFilters() navigating to filters")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let filtersView = UIHostingController(rootView: FiltersView())
            
            if let navController = rootVC.presentedViewController as? UINavigationController ??
                                  rootVC as? UINavigationController {
                navController.pushViewController(filtersView, animated: true)
            } else {
                rootVC.present(filtersView, animated: true)
            }
        }
    }
    
    func navigateToBlockedUsers() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToBlockedUsers() navigating to blocked users")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let blockedUsersView = UIHostingController(rootView: BlockedUsersView())
            
            if let navController = rootVC.presentedViewController as? UINavigationController ??
                                  rootVC as? UINavigationController {
                navController.pushViewController(blockedUsersView, animated: true)
            } else {
                rootVC.present(blockedUsersView, animated: true)
            }
        }
    }
    
    // MARK: - Popup Navigation
    
    func showYesNoPopup(title: String, description: String, buttonTitle: String, onConfirm: @escaping ([String]) -> Void, onCancel: (() -> Void)? = nil) {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "showYesNoPopup() showing yes/no popup: \(title)")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let popupView = UIHostingController(rootView: YesOrNoPopUpView(title: title, description: description, buttonTitle: buttonTitle, onConfirm: onConfirm, onCancel: onCancel))
            popupView.modalPresentationStyle = .overFullScreen
            popupView.modalTransitionStyle = .crossDissolve
            
            if let presentedVC = rootVC.presentedViewController {
                presentedVC.present(popupView, animated: true)
            } else {
                rootVC.present(popupView, animated: true)
            }
        }
    }
    
    func showUserReportPopup(userId: String, userName: String) {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "showUserReportPopup() showing report popup for user: \(userName)")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // Create a wrapper view to handle the binding
            let reportView = UIHostingController(rootView: UserReportPopupWrapper(reportedUserId: userId))
            reportView.modalPresentationStyle = UIModalPresentationStyle.pageSheet
            
            if let presentedVC = rootVC.presentedViewController {
                presentedVC.present(reportView, animated: true)
            } else {
                rootVC.present(reportView, animated: true)
            }
        }
    }
    
    func showPhotoReportPopup(photoUrl: String, userId: String) {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "showPhotoReportPopup() showing photo report popup")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // Create a wrapper view to handle the binding
            let reportView = UIHostingController(rootView: PhotoReportPopupWrapper(imageUrl: photoUrl, imageUserId: userId))
            reportView.modalPresentationStyle = UIModalPresentationStyle.pageSheet
            
            if let presentedVC = rootVC.presentedViewController {
                presentedVC.present(reportView, animated: true)
            } else {
                rootVC.present(reportView, animated: true)
            }
        }
    }
    
    func showLivePopup() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "showLivePopup() showing live popup")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let popupView = UIHostingController(rootView: LiveCallPopupView(
                isPresented: .constant(true),
                onSubscribe: {
                    NavigationManager.shared.navigateToSubscription()
                }
            ))
            popupView.modalPresentationStyle = .overFullScreen
            popupView.modalTransitionStyle = .crossDissolve
            
            if let presentedVC = rootVC.presentedViewController {
                presentedVC.present(popupView, animated: true)
            } else {
                rootVC.present(popupView, animated: true)
            }
        }
    }
    
    func showCallPopup(otherId: String, otherName: String, callback: ((String) -> Void)? = nil) {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "showCallPopup() showing call popup for user \(otherName)")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let popupView = UIHostingController(rootView: VoiceCallPopupView(
                isPresented: .constant(true),
                onSubscribe: {
                    NavigationManager.shared.navigateToSubscription()
                    callback?("subscribe")
                }
            ))
            popupView.modalPresentationStyle = .overFullScreen
            popupView.modalTransitionStyle = .crossDissolve
            
            if let presentedVC = rootVC.presentedViewController {
                presentedVC.present(popupView, animated: true)
            } else {
                rootVC.present(popupView, animated: true)
            }
        }
    }

    

    
    // MARK: - App Flow Navigation
    
    func navigateToMainApp() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToMainApp() navigating to main app")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            let mainView = UIHostingController(rootView: MainView())
            window.rootViewController = mainView
            window.makeKeyAndVisible()
        }
    }
    
    func navigateToLogin() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToLogin() navigating to onboarding flow")
        
        // OPTIMIZATION: Ensure navigation happens on main thread immediately
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                
                // OPTIMIZATION: Dismiss any presented view controllers first to prevent conflicts
                if let presentedVC = window.rootViewController?.presentedViewController {
                    presentedVC.dismiss(animated: false) // No animation for faster transition
                }
                
                // OPTIMIZATION: Create AppRootView with optimized initialization
                let appRootView = UIHostingController(rootView: AppRootView())
                
                // OPTIMIZATION: Set root view controller immediately without animation during account removal
                let isAccountRemovalActive = FirebaseOperationCoordinator.shared.isAccountRemovalActive()
                if isAccountRemovalActive {
                    AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToLogin() account removal active, using immediate transition")
                    
                    // Immediate transition without animation for account removal
                    window.rootViewController = appRootView
                    window.makeKeyAndVisible()
                } else {
                    // Normal transition with animation for regular navigation
                    UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
                        window.rootViewController = appRootView
                    }, completion: { _ in
                        window.makeKeyAndVisible()
                    })
                }
                
                AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToLogin() navigation completed")
            }
        }
    }
    
    func navigateToSubscription() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToSubscription() navigating to subscription")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let subscriptionView = UIHostingController(rootView: SubscriptionView())
            
            if let navController = rootVC.presentedViewController as? UINavigationController ??
                                  rootVC as? UINavigationController {
                navController.pushViewController(subscriptionView, animated: true)
            } else {
                rootVC.present(subscriptionView, animated: true)
            }
        }
    }
    
    func navigateToUpdate() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToUpdate() navigating to update view")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            let updateView = UIHostingController(rootView: UpdateView())
            window.rootViewController = updateView
            window.makeKeyAndVisible()
        }
    }
    
    func navigateToBanned() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToBanned() navigating to banned view")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            let bannedView = UIHostingController(rootView: BannedView())
            window.rootViewController = bannedView
            window.makeKeyAndVisible()
        }
    }
    
    // MARK: - Call Navigation
    
    func navigateToAudioCall(channelName: String, otherUserName: String, isVideoCall: Bool = false) {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "navigateToAudioCall() navigating to \(isVideoCall ? "video" : "audio") call")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            let callView: UIViewController
            if isVideoCall {
                // Use default values for required parameters - in real implementation these would be passed
                callView = UIHostingController(rootView: MakeVideoCallView(
                    otherUserId: "unknown",
                    otherUserName: otherUserName,
                    otherUserProfileImage: "",
                    chatId: channelName
                ))
            } else {
                // Use default values for required parameters - in real implementation these would be passed
                callView = UIHostingController(rootView: MakeAudioCallView(
                    otherUserId: "unknown",
                    otherUserName: otherUserName,
                    otherUserProfileImage: "",
                    otherUserGender: "Male",
                    chatId: channelName
                ))
            }
            
            callView.modalPresentationStyle = .fullScreen
            
            if let presentedVC = rootVC.presentedViewController {
                presentedVC.present(callView, animated: true)
            } else {
                rootVC.present(callView, animated: true)
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func dismissCurrentPresentation() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "dismissCurrentPresentation() dismissing current presentation")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            if let presentedVC = rootVC.presentedViewController {
                presentedVC.dismiss(animated: true)
            }
        }
    }
    
    func popToRoot() {
        AppLogger.log(tag: "LOG-APP: NavigationManager", message: "popToRoot() popping to root view controller")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            if let navController = rootVC.presentedViewController as? UINavigationController ??
                                  rootVC as? UINavigationController {
                navController.popToRootViewController(animated: true)
            }
        }
    }
} 