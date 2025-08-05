import Foundation
import BackgroundTasks
import UIKit

/// iOS equivalent of Android WorkManager
/// Provides centralized background task management with 100% Android parity
class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    // Task identifiers (Android parity: WorkManager task names)
    private let profileSyncTaskId = "com.peppty.ChatApp.profile.sync"
    private let subscriptionSyncTaskId = "com.peppty.ChatApp.subscription.sync"
    private let profanityUpdateTaskId = "com.peppty.ChatApp.profanity.update"
    private let gamesUpdateTaskId = "com.peppty.ChatApp.games.update"
    private let ipDetailsTaskId = "com.peppty.ChatApp.ipdetails.fetch"
    private let chatsSyncTaskId = "com.peppty.ChatApp.chats.sync"
    private let notificationsSyncTaskId = "com.peppty.ChatApp.notifications.sync"
    private let manualBanCheckTaskId = "com.peppty.ChatApp.manualban.check"
    private let onlineUsersTaskId = "com.peppty.ChatApp.onlineusers.fetch"
    private let deleteChatTaskId = "com.peppty.ChatApp.deletechat.process"
    private let aiMessageTaskId = "com.peppty.ChatApp.aimessage.generate"
    private let clearConversationTaskId = "com.peppty.ChatApp.clearconversation.process"
    private let getReportsTaskId = "com.peppty.ChatApp.getreports.sync"
    private let reportPhotoTaskId = "com.peppty.ChatApp.reportphoto.submit"
    
    private init() {}
    
    // MARK: - Android Parity: WorkManager.enqueueUniqueWork equivalent
    
    /// Registers all background tasks - Android parity: WorkManager initialization
    func registerBackgroundTasks() {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "registerBackgroundTasks() Registering all background tasks")
        
        // Profile sync task (Android parity: GetProfileWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: profileSyncTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleProfileSyncTask(task: refreshTask)
        }
        
        // Subscription sync task (Android parity: SubscriptionWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: subscriptionSyncTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleSubscriptionSyncTask(task: refreshTask)
        }
        
        // Profanity update task (Android parity: ProfanityWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: profanityUpdateTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleProfanityUpdateTask(task: refreshTask)
        }
        
        // Games update task (Android parity: GamesWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: gamesUpdateTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleGamesUpdateTask(task: refreshTask)
        }
        
        // IP details task (Android parity: IpDetailsWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: ipDetailsTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleIpDetailsTask(task: refreshTask)
        }
        
        // Chats sync task (Android parity: ChatsWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: chatsSyncTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleChatsSyncTask(task: refreshTask)
        }
        
        // Notifications sync task (Android parity: NotificationsWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: notificationsSyncTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleNotificationsSyncTask(task: refreshTask)
        }
        
        // Manual ban check task (Android parity: ManualBanWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: manualBanCheckTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleManualBanCheckTask(task: refreshTask)
        }
        
        // Online users task (Android parity: OnlineUsersWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: onlineUsersTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleOnlineUsersTask(task: refreshTask)
        }
        
        // Delete chat task (Android parity: DeleteChatWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: deleteChatTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleDeleteChatTask(task: refreshTask)
        }
        
        // AI message task (Android parity: AiMessageWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: aiMessageTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAiMessageTask(task: refreshTask)
        }
        
        // Clear conversation task (Android parity: ClearConversationWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: clearConversationTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleClearConversationTask(task: refreshTask)
        }
        
        // Get reports task (Android parity: GetReportsWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: getReportsTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleGetReportsTask(task: refreshTask)
        }
        
        // Report photo task (Android parity: ReportPhotoWorker)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: reportPhotoTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                AppLogger.log(tag: "BackgroundTaskManager", message: "CRITICAL: Task is not BGAppRefreshTask type")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleReportPhotoTask(task: refreshTask)
        }
        
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "registerBackgroundTasks() All background tasks registered successfully")
    }
    
    /// Schedules all periodic background tasks - Android parity: WorkManager periodic work
    func scheduleAllPeriodicTasks() {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleAllPeriodicTasks() Scheduling all periodic tasks")
        
        scheduleProfileSync()
        scheduleSubscriptionSync()
        scheduleProfanityUpdate()
        scheduleGamesUpdate()
        scheduleIpDetailsUpdate()
        scheduleChatsSync()
        scheduleNotificationsSync()
        scheduleManualBanCheck()
        scheduleOnlineUsersSync()
        scheduleGetReportsSync()
    }
    
    // MARK: - Individual Task Scheduling (Android Parity)
    
    /// Android parity: GetProfileWorker scheduling
    func scheduleProfileSync() {
        let request = BGAppRefreshTaskRequest(identifier: profileSyncTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 15) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleProfileSync() Profile sync task scheduled")
        } catch {
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleProfileSync() Failed to schedule: \(error.localizedDescription)")
        }
    }
    
    /// Android parity: SubscriptionWorker scheduling
    func scheduleSubscriptionSync() {
        let request = BGAppRefreshTaskRequest(identifier: subscriptionSyncTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 20) // 20 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleSubscriptionSync() Subscription sync task scheduled")
        } catch {
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleSubscriptionSync() Failed to schedule: \(error.localizedDescription)")
        }
    }
    
    /// Android parity: ProfanityWorker scheduling
    func scheduleProfanityUpdate() {
        let request = BGAppRefreshTaskRequest(identifier: profanityUpdateTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleProfanityUpdate() Profanity update task scheduled")
        } catch {
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleProfanityUpdate() Failed to schedule: \(error.localizedDescription)")
        }
    }
    
    /// Android parity: GamesWorker scheduling
    func scheduleGamesUpdate() {
        let request = BGAppRefreshTaskRequest(identifier: gamesUpdateTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 30) // 30 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleGamesUpdate() Games update task scheduled")
        } catch {
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleGamesUpdate() Failed to schedule: \(error.localizedDescription)")
        }
    }
    
    /// Android parity: IpDetailsWorker scheduling
    func scheduleIpDetailsUpdate() {
        let request = BGAppRefreshTaskRequest(identifier: ipDetailsTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 45) // 45 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleIpDetailsUpdate() IP details task scheduled")
        } catch {
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleIpDetailsUpdate() Failed to schedule: \(error.localizedDescription)")
        }
    }
    
    /// Android parity: ChatsWorker scheduling
    func scheduleChatsSync() {
        let request = BGAppRefreshTaskRequest(identifier: chatsSyncTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 10) // 10 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleChatsSync() Chats sync task scheduled")
        } catch {
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleChatsSync() Failed to schedule: \(error.localizedDescription)")
        }
    }
    
    /// Android parity: NotificationsWorker scheduling
    func scheduleNotificationsSync() {
        let request = BGAppRefreshTaskRequest(identifier: notificationsSyncTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 12) // 12 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleNotificationsSync() Notifications sync task scheduled")
        } catch {
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleNotificationsSync() Failed to schedule: \(error.localizedDescription)")
        }
    }
    
    /// Android parity: ManualBanWorker scheduling
    func scheduleManualBanCheck() {
        let request = BGAppRefreshTaskRequest(identifier: manualBanCheckTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 5) // 5 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleManualBanCheck() Manual ban check task scheduled")
        } catch {
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleManualBanCheck() Failed to schedule: \(error.localizedDescription)")
        }
    }
    
    /// Android parity: OnlineUsersWorker scheduling
    func scheduleOnlineUsersSync() {
        let request = BGAppRefreshTaskRequest(identifier: onlineUsersTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 8) // 8 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleOnlineUsersSync() Online users sync task scheduled")
        } catch {
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleOnlineUsersSync() Failed to schedule: \(error.localizedDescription)")
        }
    }
    
    /// Android parity: GetReportsWorker scheduling
    func scheduleGetReportsSync() {
        let request = BGAppRefreshTaskRequest(identifier: getReportsTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 25) // 25 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleGetReportsSync() Get reports sync task scheduled")
        } catch {
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "scheduleGetReportsSync() Failed to schedule: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Task Handlers (Android Parity)
    
    /// Android parity: GetProfileWorker.doWork()
    private func handleProfileSyncTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleProfileSyncTask() Started profile sync background task")
        
        scheduleProfileSync() // Schedule next execution
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = ProfileSyncBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleProfileSyncTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleProfileSyncTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: SubscriptionWorker.doWork()
    private func handleSubscriptionSyncTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleSubscriptionSyncTask() Started subscription sync background task")
        
        scheduleSubscriptionSync() // Schedule next execution
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = SubscriptionSyncBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleSubscriptionSyncTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleSubscriptionSyncTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: ProfanityWorker.doWork()
    private func handleProfanityUpdateTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleProfanityUpdateTask() Started profanity update background task")
        
        scheduleProfanityUpdate() // Schedule next execution
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = ProfanityUpdateBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleProfanityUpdateTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleProfanityUpdateTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: GamesWorker.doWork()
    private func handleGamesUpdateTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleGamesUpdateTask() Started games update background task")
        
        scheduleGamesUpdate() // Schedule next execution
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = GamesUpdateBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleGamesUpdateTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleGamesUpdateTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: IpDetailsWorker.doWork()
    private func handleIpDetailsTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleIpDetailsTask() Started IP details background task")
        
        scheduleIpDetailsUpdate() // Schedule next execution
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = IpDetailsBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleIpDetailsTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleIpDetailsTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: ChatsWorker.doWork()
    private func handleChatsSyncTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleChatsSyncTask() Started chats sync background task")
        
        scheduleChatsSync() // Schedule next execution
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = ChatsSyncBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleChatsSyncTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleChatsSyncTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: NotificationsWorker.doWork()
    private func handleNotificationsSyncTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleNotificationsSyncTask() Started notifications sync background task")
        
        scheduleNotificationsSync() // Schedule next execution
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = NotificationsSyncBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleNotificationsSyncTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleNotificationsSyncTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: ManualBanWorker.doWork()
    private func handleManualBanCheckTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleManualBanCheckTask() Started manual ban check background task")
        
        scheduleManualBanCheck() // Schedule next execution
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = ManualBanCheckBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleManualBanCheckTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleManualBanCheckTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: OnlineUsersWorker.doWork()
    private func handleOnlineUsersTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleOnlineUsersTask() Started online users background task")
        
        scheduleOnlineUsersSync() // Schedule next execution
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = OnlineUsersBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleOnlineUsersTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleOnlineUsersTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: DeleteChatWorker.doWork()
    private func handleDeleteChatTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleDeleteChatTask() Started delete chat background task")
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = DeleteChatBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleDeleteChatTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleDeleteChatTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: AiMessageWorker.doWork()
    private func handleAiMessageTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleAiMessageTask() Started AI message background task")
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = AiMessageBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleAiMessageTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleAiMessageTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: ClearConversationWorker.doWork()
    private func handleClearConversationTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleClearConversationTask() Started clear conversation background task")
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = ClearConversationBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleClearConversationTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleClearConversationTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: GetReportsWorker.doWork()
    private func handleGetReportsTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleGetReportsTask() Started get reports background task")
        
        scheduleGetReportsSync() // Schedule next execution
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = GetReportsBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleGetReportsTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleGetReportsTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    /// Android parity: ReportPhotoWorker.doWork()
    private func handleReportPhotoTask(task: BGAppRefreshTask) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleReportPhotoTask() Started report photo background task")
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = ReportPhotoBackgroundOperation()
        
        task.expirationHandler = {
            queue.cancelAllOperations()
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleReportPhotoTask() Task expired")
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "handleReportPhotoTask() Completed with success=\(!operation.isCancelled)")
        }
        
        queue.addOperation(operation)
    }
    
    // MARK: - Immediate Task Execution (Android Parity)
    
    /// Android parity: WorkManager.enqueueUniqueWork with ExistingWorkPolicy.REPLACE
    func executeImmediateProfileSync() {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateProfileSync() Executing immediate profile sync")
        
        DispatchQueue.global(qos: .background).async {
            let operation = ProfileSyncBackgroundOperation()
            operation.start()
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateSubscriptionSync() {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateSubscriptionSync() Executing immediate subscription sync")
        
        DispatchQueue.global(qos: .background).async {
            let operation = SubscriptionSyncBackgroundOperation()
            operation.start()
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateProfanityUpdate() {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateProfanityUpdate() Executing immediate profanity update")
        
        DispatchQueue.global(qos: .background).async {
            ProfanityService.shared.checkProfanityUpdate()
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateGamesUpdate() {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateGamesUpdate() Executing immediate games update")
        
        DispatchQueue.global(qos: .background).async {
            GamesService.shared.fetchGamesIfNeeded { success in
                AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateGamesUpdate() Completed with success: \(success)")
            }
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateIpDetailsUpdate() {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateIpDetailsUpdate() Executing immediate IP details update")
        
        DispatchQueue.global(qos: .background).async {
            IPAddressService().getIPAddress()
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateChatsSync(lastChatTime: String? = nil) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateChatsSync() Executing immediate chats sync")
        
        DispatchQueue.global(qos: .background).async {
            let operation = ChatsSyncBackgroundOperation(lastChatTime: lastChatTime)
            operation.start()
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateNotificationsSync(lastNotificationTime: String? = nil) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateNotificationsSync() Executing immediate notifications sync")
        
        DispatchQueue.global(qos: .background).async {
            let operation = NotificationsSyncBackgroundOperation(lastNotificationTime: lastNotificationTime)
            operation.start()
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateManualBanCheck() {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateManualBanCheck() Executing immediate manual ban check")
        
        DispatchQueue.global(qos: .background).async {
            let operation = ManualBanCheckBackgroundOperation()
            operation.start()
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateOnlineUsersSync(lastOnlineUserTime: String? = nil) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateOnlineUsersSync() Executing immediate online users sync")
        
        DispatchQueue.global(qos: .background).async {
            OnlineUsersService.shared.fetchOnlineUsers(lastOnlineUserTime: lastOnlineUserTime) { success in
                AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateOnlineUsersSync() Completed with success: \(success)")
            }
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateDeleteChat(chatId: String) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateDeleteChat() Executing immediate delete chat: \(chatId)")
        
        DispatchQueue.global(qos: .background).async {
            DeleteChatService.shared.deleteChat(chatId: chatId) { success in
                AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateDeleteChat() Completed with success: \(success)")
            }
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateAiMessage(
        aiApiUrl: String,
        aiApiKey: String,
        chatId: String,
        otherProfile: UserCoreDataReplacement,
        myProfile: UserCoreDataReplacement,
        lastTypingTime: Int64,
        isProfanity: Bool,
        lastAiMessage: String?
    ) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateAiMessage() Executing immediate AI message generation")
        
        DispatchQueue.global(qos: .background).async {
            AIMessageService.shared.generateAiMessage(
                aiApiUrl: aiApiUrl,
                aiApiKey: aiApiKey,
                chatId: chatId,
                otherProfile: otherProfile,
                myProfile: myProfile,
                lastTypingTime: lastTypingTime,
                isProfanity: isProfanity,
                lastAiMessage: lastAiMessage
            ) { success in
                AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateAiMessage() Completed with success: \(success)")
            }
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateClearConversation(myUserId: String, otherUserId: String, chatId: String? = nil) {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateClearConversation() Executing immediate clear conversation")
        
        DispatchQueue.global(qos: .background).async {
            ClearConversationService.shared.clearConversation(
                myUserId: myUserId,
                otherUserId: otherUserId,
                chatId: chatId
            ) { success in
                AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateClearConversation() Completed with success: \(success)")
            }
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateGetReportsSync() {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateGetReportsSync() Executing immediate get reports sync")
        
        DispatchQueue.global(qos: .background).async {
            GetReportsService.shared.refreshReportsData()
        }
    }
    
    /// Android parity: WorkManager.enqueueUniqueWork for immediate execution
    func executeImmediateReportPhoto(imageUrl: String, otherUserId: String, reason: String = "Inappropriate content") {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateReportPhoto() Executing immediate report photo")
        
        DispatchQueue.global(qos: .background).async {
            ReportPhotoService.shared.reportPhoto(
                imageUrl: imageUrl,
                otherUserId: otherUserId,
                reason: reason
            ) { success in
                AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "executeImmediateReportPhoto() Completed with success: \(success)")
            }
        }
    }
    
    // MARK: - Task Cancellation (Android Parity)
    
    /// Android parity: WorkManager.cancelUniqueWork()
    func cancelAllBackgroundTasks() {
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "cancelAllBackgroundTasks() Cancelling all background tasks")
        
        BGTaskScheduler.shared.cancelAllTaskRequests()
        
        AppLogger.log(tag: "LOG-APP: BackgroundTaskManager", message: "cancelAllBackgroundTasks() All background tasks cancelled")
    }
}

// MARK: - Background Operation Classes

/// Android parity: GetProfileWorker
class ProfileSyncBackgroundOperation: Operation, @unchecked Sendable {
    private let userId: String?
    
    init(userId: String? = nil) {
        self.userId = userId
        super.init()
    }
    
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: ProfileSyncBackgroundOperation", message: "main() Profile sync background operation started")
        
        // Android parity: GetProfileWorker.doWork() implementation
        let sessionManager = SessionManager.shared
        let targetUserId = userId ?? sessionManager.userId
        
        guard let validUserId = targetUserId, !validUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ProfileSyncBackgroundOperation", message: "main() No valid user ID, skipping profile sync")
            return
        }
        
        // Use semaphore to wait for async Firebase operation
        let semaphore = DispatchSemaphore(value: 0)
        var operationSuccess = false
        
        // Fetch profile from Firebase (Android parity)
        ProfileSyncService.shared.fetchAndSyncProfile(userId: validUserId) { success in
            operationSuccess = success
            semaphore.signal()
        }
        
        // Wait for operation to complete
        semaphore.wait()
        
        AppLogger.log(tag: "LOG-APP: ProfileSyncBackgroundOperation", message: "main() Profile sync background operation completed with success: \(operationSuccess)")
    }
}

/// Android parity: ProfanityWorker
class ProfanityUpdateBackgroundOperation: Operation, @unchecked Sendable {
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: ProfanityUpdateBackgroundOperation", message: "main() Profanity update background operation started")
        
        // Android parity: ProfanityWorker.doWork() implementation
        ProfanityService.shared.checkProfanityUpdate()
        
        AppLogger.log(tag: "LOG-APP: ProfanityUpdateBackgroundOperation", message: "main() Profanity update background operation completed")
    }
}

/// Android parity: GamesWorker
class GamesUpdateBackgroundOperation: Operation, @unchecked Sendable {
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: GamesUpdateBackgroundOperation", message: "main() Games update background operation started")
        
        // Android parity: GamesWorker.doWork() implementation
        let semaphore = DispatchSemaphore(value: 0)
        
        GamesService.shared.fetchGamesIfNeeded { success in
            AppLogger.log(tag: "LOG-APP: GamesUpdateBackgroundOperation", message: "main() Games update completed with success: \(success)")
            semaphore.signal()
        }
        
        semaphore.wait()
        AppLogger.log(tag: "LOG-APP: GamesUpdateBackgroundOperation", message: "main() Games update background operation completed")
    }
}

/// Android parity: IpDetailsWorker
class IpDetailsBackgroundOperation: Operation, @unchecked Sendable {
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: IpDetailsBackgroundOperation", message: "main() IP details background operation started")
        
        // Android parity: IpDetailsWorker.doWork() implementation
        IPAddressService().getIPAddress()
        
        AppLogger.log(tag: "LOG-APP: IpDetailsBackgroundOperation", message: "main() IP details background operation completed")
    }
}

/// Android parity: ChatsWorker
class ChatsSyncBackgroundOperation: Operation, @unchecked Sendable {
    private let lastChatTime: String?
    
    init(lastChatTime: String? = nil) {
        self.lastChatTime = lastChatTime
        super.init()
    }
    
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: ChatsSyncBackgroundOperation", message: "main() Chats sync background operation started")
        
        // Android parity: ChatsWorker.doWork() implementation
        let semaphore = DispatchSemaphore(value: 0)
        
        ChatsSyncService.shared.syncChatsFromFirebase(lastChatTime: lastChatTime) { success in
            AppLogger.log(tag: "LOG-APP: ChatsSyncBackgroundOperation", message: "main() Chats sync completed with success: \(success)")
            semaphore.signal()
        }
        
        semaphore.wait()
        AppLogger.log(tag: "LOG-APP: ChatsSyncBackgroundOperation", message: "main() Chats sync background operation completed")
    }
}

/// Android parity: NotificationsWorker
class NotificationsSyncBackgroundOperation: Operation, @unchecked Sendable {
    private let lastNotificationTime: String?
    
    init(lastNotificationTime: String? = nil) {
        self.lastNotificationTime = lastNotificationTime
        super.init()
    }
    
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: NotificationsSyncBackgroundOperation", message: "main() Notifications sync background operation started")
        
        // Android parity: NotificationsWorker.doWork() implementation
        let semaphore = DispatchSemaphore(value: 0)
        
        InAppNotificationsSyncService.shared.syncNotificationsFromFirebase(lastNotificationTime: lastNotificationTime) { success in
            AppLogger.log(tag: "LOG-APP: NotificationsSyncBackgroundOperation", message: "main() Notifications sync completed with success: \(success)")
            semaphore.signal()
        }
        
        semaphore.wait()
        AppLogger.log(tag: "LOG-APP: NotificationsSyncBackgroundOperation", message: "main() Notifications sync background operation completed")
    }
}

/// Android parity: ManualBanWorker
class ManualBanCheckBackgroundOperation: Operation, @unchecked Sendable {
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: ManualBanCheckBackgroundOperation", message: "main() Manual ban check background operation started")
        
        // Android parity: ManualBanWorker.doWork() implementation
        let semaphore = DispatchSemaphore(value: 0)
        
        ManualBanCheckService.shared.checkAllBanTypes { success in
            AppLogger.log(tag: "LOG-APP: ManualBanCheckBackgroundOperation", message: "main() Manual ban check completed with success: \(success)")
            semaphore.signal()
        }
        
        semaphore.wait()
        AppLogger.log(tag: "LOG-APP: ManualBanCheckBackgroundOperation", message: "main() Manual ban check background operation completed")
    }
}

/// Android parity: OnlineUsersWorker
class OnlineUsersBackgroundOperation: Operation, @unchecked Sendable {
    private let lastOnlineUserTime: String?
    
    init(lastOnlineUserTime: String? = nil) {
        self.lastOnlineUserTime = lastOnlineUserTime
        super.init()
    }
    
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: OnlineUsersBackgroundOperation", message: "main() Online users background operation started")
        
        // Android parity: OnlineUsersWorker.doWork() implementation
        let semaphore = DispatchSemaphore(value: 0)
        
        OnlineUsersService.shared.fetchOnlineUsers(lastOnlineUserTime: lastOnlineUserTime) { success in
            AppLogger.log(tag: "LOG-APP: OnlineUsersBackgroundOperation", message: "main() Online users sync completed with success: \(success)")
            semaphore.signal()
        }
        
        semaphore.wait()
        AppLogger.log(tag: "LOG-APP: OnlineUsersBackgroundOperation", message: "main() Online users background operation completed")
    }
}

/// Android parity: DeleteChatWorker
class DeleteChatBackgroundOperation: Operation, @unchecked Sendable {
    private let chatId: String?
    
    init(chatId: String? = nil) {
        self.chatId = chatId
        super.init()
    }
    
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: DeleteChatBackgroundOperation", message: "main() Delete chat background operation started")
        
        // Android parity: DeleteChatWorker.doWork() implementation
        guard let validChatId = chatId, !validChatId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: DeleteChatBackgroundOperation", message: "main() No valid chat ID, skipping delete chat")
            return
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        DeleteChatService.shared.deleteChat(chatId: validChatId) { success in
            AppLogger.log(tag: "LOG-APP: DeleteChatBackgroundOperation", message: "main() Delete chat completed with success: \(success)")
            semaphore.signal()
        }
        
        semaphore.wait()
        AppLogger.log(tag: "LOG-APP: DeleteChatBackgroundOperation", message: "main() Delete chat background operation completed")
    }
}

/// Android parity: AiMessageWorker
class AiMessageBackgroundOperation: Operation, @unchecked Sendable {
    private let aiApiUrl: String?
    private let aiApiKey: String?
    private let chatId: String?
    private let otherProfile: UserCoreDataReplacement?
    private let myProfile: UserCoreDataReplacement?
    private let lastTypingTime: Int64
    private let isProfanity: Bool
    private let lastAiMessage: String?
    
    init(
        aiApiUrl: String? = nil,
        aiApiKey: String? = nil,
        chatId: String? = nil,
        otherProfile: UserCoreDataReplacement? = nil,
        myProfile: UserCoreDataReplacement? = nil,
        lastTypingTime: Int64 = 0,
        isProfanity: Bool = false,
        lastAiMessage: String? = nil
    ) {
        self.aiApiUrl = aiApiUrl
        self.aiApiKey = aiApiKey
        self.chatId = chatId
        self.otherProfile = otherProfile
        self.myProfile = myProfile
        self.lastTypingTime = lastTypingTime
        self.isProfanity = isProfanity
        self.lastAiMessage = lastAiMessage
        super.init()
    }
    
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: AiMessageBackgroundOperation", message: "main() AI message background operation started")
        
        // Android parity: AiMessageWorker.doWork() implementation
        guard let validApiUrl = aiApiUrl, !validApiUrl.isEmpty,
              let validApiKey = aiApiKey, !validApiKey.isEmpty,
              let validChatId = chatId, !validChatId.isEmpty,
              let validOtherProfile = otherProfile,
              let validMyProfile = myProfile else {
            AppLogger.log(tag: "LOG-APP: AiMessageBackgroundOperation", message: "main() Missing required parameters, skipping AI message generation")
            return
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        AIMessageService.shared.generateAiMessage(
            aiApiUrl: validApiUrl,
            aiApiKey: validApiKey,
            chatId: validChatId,
            otherProfile: validOtherProfile,
            myProfile: validMyProfile,
            lastTypingTime: lastTypingTime,
            isProfanity: isProfanity,
            lastAiMessage: lastAiMessage
        ) { success in
            AppLogger.log(tag: "LOG-APP: AiMessageBackgroundOperation", message: "main() AI message generation completed with success: \(success)")
            semaphore.signal()
        }
        
        semaphore.wait()
        AppLogger.log(tag: "LOG-APP: AiMessageBackgroundOperation", message: "main() AI message background operation completed")
    }
}

/// Android parity: ClearConversationWorker
class ClearConversationBackgroundOperation: Operation, @unchecked Sendable {
    private let myUserId: String?
    private let otherUserId: String?
    private let chatId: String?
    
    init(myUserId: String? = nil, otherUserId: String? = nil, chatId: String? = nil) {
        self.myUserId = myUserId
        self.otherUserId = otherUserId
        self.chatId = chatId
        super.init()
    }
    
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: ClearConversationBackgroundOperation", message: "main() Clear conversation background operation started")
        
        // Android parity: ClearConversationWorker.doWork() implementation
        guard let validMyUserId = myUserId, !validMyUserId.isEmpty,
              let validOtherUserId = otherUserId, !validOtherUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ClearConversationBackgroundOperation", message: "main() Missing required user IDs, skipping clear conversation")
            return
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        ClearConversationService.shared.clearConversation(
            myUserId: validMyUserId,
            otherUserId: validOtherUserId,
            chatId: chatId
        ) { success in
            AppLogger.log(tag: "LOG-APP: ClearConversationBackgroundOperation", message: "main() Clear conversation completed with success: \(success)")
            semaphore.signal()
        }
        
        semaphore.wait()
        AppLogger.log(tag: "LOG-APP: ClearConversationBackgroundOperation", message: "main() Clear conversation background operation completed")
    }
}

/// Android parity: GetReportsWorker
class GetReportsBackgroundOperation: Operation, @unchecked Sendable {
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: GetReportsBackgroundOperation", message: "main() Get reports background operation started")
        
        // Android parity: GetReportsWorker.doWork() implementation
        GetReportsService.shared.refreshReportsData()
        
        AppLogger.log(tag: "LOG-APP: GetReportsBackgroundOperation", message: "main() Get reports background operation completed")
    }
}

/// Android parity: ReportPhotoWorker
class ReportPhotoBackgroundOperation: Operation, @unchecked Sendable {
    private let imageUrl: String?
    private let otherUserId: String?
    private let reason: String
    
    init(imageUrl: String? = nil, otherUserId: String? = nil, reason: String = "Inappropriate content") {
        self.imageUrl = imageUrl
        self.otherUserId = otherUserId
        self.reason = reason
        super.init()
    }
    
    override func main() {
        if self.isCancelled { return }
        
        AppLogger.log(tag: "LOG-APP: ReportPhotoBackgroundOperation", message: "main() Report photo background operation started")
        
        // Android parity: ReportPhotoWorker.doWork() implementation
        guard let validImageUrl = imageUrl, !validImageUrl.isEmpty,
              let validOtherUserId = otherUserId, !validOtherUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ReportPhotoBackgroundOperation", message: "main() Missing required parameters, skipping report photo")
            return
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        ReportPhotoService.shared.reportPhoto(
            imageUrl: validImageUrl,
            otherUserId: validOtherUserId,
            reason: reason
        ) { success in
            AppLogger.log(tag: "LOG-APP: ReportPhotoBackgroundOperation", message: "main() Report photo completed with success: \(success)")
            semaphore.signal()
        }
        
        semaphore.wait()
        AppLogger.log(tag: "LOG-APP: ReportPhotoBackgroundOperation", message: "main() Report photo background operation completed")
    }
} 
