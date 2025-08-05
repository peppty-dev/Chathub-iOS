import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit

/// iOS equivalent of Android ChatsWorker
/// Handles chats synchronization from Firebase to local database with 100% Android parity
class ChatsSyncService {
    static let shared = ChatsSyncService()
    
    private let db = Firestore.firestore()
    private let sessionManager = SessionManager.shared
    private var chatsListener: ListenerRegistration?
    
    // MARK: - Continuous Retry Properties (Android Parity)
    private static let TAG = "ChatsSyncService"
    private static let RETRY_DELAY_SECONDS: TimeInterval = 30.0 // 30 seconds like current implementation
    private var retryTimer: Timer?
    private var retryCount = 0
    private var isRetryingForUserId: String? = nil
    
    private init() {}
    
    /// Starts the chats listener - equivalent to FirebaseServices.getChatsListener()
    /// This is the main method that should be called to start listening for chat updates
    func startChatsListener() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startChatsListener() starting Firebase chats listener")
        
        guard let userId = sessionManager.userId, !userId.isEmpty else {
            // Android parity: Continuous retry until user is authenticated
            if isRetryingForUserId == nil {
                retryCount += 1
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startChatsListener() no user ID available, scheduling CONTINUOUS retry attempt \(retryCount) in \(Self.RETRY_DELAY_SECONDS)s")
                isRetryingForUserId = nil // Mark that we're retrying for null user
                scheduleContinuousRetry()
            } else {
                AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startChatsListener() already retrying for user authentication")
            }
            return
        }
        
        // User authenticated successfully - stop any retry timers and proceed
        stopRetryTimer()
        retryCount = 0
        isRetryingForUserId = userId
        
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "startChatsListener() User authenticated, starting listener for userId: \(userId)")
        
        // Remove existing listener if active
        if let existingListener = chatsListener {
            existingListener.remove()
            chatsListener = nil
        }
        
        let lastTimeInterval = sessionManager.chatLastTime
        let lastTime = Timestamp(seconds: Int64(lastTimeInterval), nanoseconds: 0)
        
        // Set up Firebase listener (matching FirebaseServices.getChatsListener exactly)
        chatsListener = db.collection("Users")
            .document(userId)
            .collection("Chats")
            .order(by: "last_message_timestamp", descending: true)
            .end(before: [lastTime as Any])
            .limit(to: 10)
            .addSnapshotListener { [weak self] (snapshot, error) in
                guard let self = self else { return }
                guard let snap = snapshot else { return }
                
                snap.documentChanges.forEach { diff in
                    if (diff.type == .added) {
                        self.processAddedChatDocument(diff.document)
                    }
                    
                    if (diff.type == .modified) {
                        self.processModifiedChatDocument(diff.document)
                    }
                }
            }
    }
    
    /// Stops the chats listener
    func stopChatsListener() {
        AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "stopChatsListener() stopping Firebase chats listener")
        
        // Stop continuous retry mechanism
        stopRetryTimer()
        retryCount = 0
        isRetryingForUserId = nil
        
        if let listener = chatsListener {
            listener.remove()
            chatsListener = nil
        }
    }
    
    // MARK: - Continuous Retry Methods (Android Parity)
    
    /// Schedules continuous retry until user authentication - iOS equivalent of Android Handler.postDelayed loop
    private func scheduleContinuousRetry() {
        stopRetryTimer() // Cancel any existing timer
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: Self.RETRY_DELAY_SECONDS, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.log(tag: "LOG-APP: \(Self.TAG)", message: "scheduleContinuousRetry() Executing scheduled retry attempt")
            self.startChatsListener() // CONTINUOUS RETRY - calls itself again until user is authenticated
        }
    }
    
    /// Stops the retry timer
    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    /// Process added chat document (from FirebaseServices.getChatsListener)
    private func processAddedChatDocument(_ document: DocumentSnapshot) {
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processAddedChatDocument() Processing added document: \(document.documentID)")
        
        let data = document.data() ?? [:]
        let documentid = document.documentID
        let title = data["User_name"] as? String ?? ""
        let deletedata = data["conversation_deleted"] as? Bool ?? false
        let gender = data["User_gender"] as? String ?? ""
        let profileimage = data["User_image"] as? String ?? ""
        let lastsentby = data["last_message_sent_by_user_id"] as? String ?? ""
        let deviceId = data["User_device_id"] as? String ?? ""
        let lasttimestamp = data["last_message_timestamp"] as? Timestamp ?? Timestamp(date: Date())
        let id = data["Chat_id"] as? String ?? ""
        let newmes = data["new_message"] as? Bool ?? false
        let inbox = data["inbox"] as? Bool ?? true
        let aDate = lasttimestamp.dateValue()
        var newmess = 0
        var inbo = 0
        if inbox {
            inbo = 1
        }
        if newmes {
            newmess = 1
        }
        
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processAddedChatDocument() INBOX = \(inbox), converting to inbo = \(inbo)")
        
        // CRITICAL FIX: Validate essential chat data before processing
        guard !documentid.isEmpty && documentid != "null" && 
              !title.isEmpty && title != "null" && title.trimmingCharacters(in: .whitespaces) != "" &&
              !id.isEmpty && id != "null" else {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processAddedChatDocument() REJECTING invalid chat - documentid: '\(documentid)', title: '\(title)', id: '\(id)'")
            return
        }
        
        // Additional validation: Check for meaningful user data
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processAddedChatDocument() REJECTING chat with empty/whitespace-only name: '\(title)'")
            return
        }
        
        if !deletedata {
            DatabaseManager.shared.getChatDB()?.insert(ChatId: id, UserId: documentid, Image: profileimage, UserName: title, Gender: gender, Lastsentby: lastsentby, DeviceId: deviceId, LastTimeStamp: aDate, NewMessage: newmess, Group: 0, /* Excluded feature: groups - always 0 */ Inbox: inbo, Type: "chat", LastMessageSentByUserId: lastsentby)
            DatabaseManager.shared.getChatDB()?.update(LastTimeStamp: aDate, NewMessage: newmess, ChatId: id, Lastsentby: lastsentby, Inbox: inbo, LastMessageSentByUserId: lastsentby)
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processAddedChatDocument() Added to local database - ChatId: \(id), Inbox: \(inbo)")
        } else {
            DatabaseManager.shared.getChatDB()?.delete(ChatId: id)
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processAddedChatDocument() Deleted chat from local database: \(id)")
        }
        let seconds = lasttimestamp.seconds
        sessionManager.chatLastTime = Double(seconds)
    }
    
    /// Process modified chat document (from FirebaseServices.getChatsListener)
    private func processModifiedChatDocument(_ document: DocumentSnapshot) {
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processModifiedChatDocument() Processing modified document: \(document.documentID)")
        
        let data = document.data() ?? [:]
        let documentid = document.documentID
        let title = data["User_name"] as? String ?? ""
        let deletedata = data["conversation_deleted"] as? Bool ?? false
        let gender = data["User_gender"] as? String ?? ""
        let profileimage = data["User_image"] as? String ?? ""
        let lastsentby = data["last_message_sent_by_user_id"] as? String ?? ""
        let deviceId = data["User_device_id"] as? String ?? ""
        let lasttimestamp = data["last_message_timestamp"] as? Timestamp ?? Timestamp(date: Date())
        let id = data["Chat_id"] as? String ?? ""
        let newmes = data["new_message"] as? Bool ?? true
        let inbox = data["inbox"] as? Bool ?? true
        let aDate = lasttimestamp.dateValue()
        var newmess = 0
        var inbo = 0
        if inbox {
            inbo = 1
        }
        if newmes {
            newmess = 1
        }
        
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processModifiedChatDocument() INBOX = \(inbox), converting to inbo = \(inbo)")
        
        // CRITICAL FIX: Validate essential chat data before processing
        guard !documentid.isEmpty && documentid != "null" && 
              !title.isEmpty && title != "null" && title.trimmingCharacters(in: .whitespaces) != "" &&
              !id.isEmpty && id != "null" else {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processModifiedChatDocument() REJECTING invalid chat - documentid: '\(documentid)', title: '\(title)', id: '\(id)'")
            return
        }
        
        // Additional validation: Check for meaningful user data
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processModifiedChatDocument() REJECTING chat with empty/whitespace-only name: '\(title)'")
            return
        }
        
        if !deletedata {
            DatabaseManager.shared.getChatDB()?.insert(ChatId: id, UserId: documentid, Image: profileimage, UserName: title, Gender: gender, Lastsentby: lastsentby, DeviceId: deviceId, LastTimeStamp: aDate, NewMessage: newmess, Group: 0, /* Excluded feature: groups - always 0 */ Inbox: inbo, Type: "chat", LastMessageSentByUserId: lastsentby)
            DatabaseManager.shared.getChatDB()?.update(LastTimeStamp: aDate, NewMessage: newmess, ChatId: id, Lastsentby: lastsentby, Inbox: inbo, LastMessageSentByUserId: lastsentby)
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processModifiedChatDocument() Updated local database - ChatId: \(id), Inbox: \(inbo)")
        } else {
            DatabaseManager.shared.getChatDB()?.delete(ChatId: id)
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processModifiedChatDocument() Deleted chat from local database: \(id)")
        }

        let seconds = lasttimestamp.seconds
        sessionManager.chatLastTime = Double(seconds)
    }

    /// Android parity: ChatsWorker.doWork()
    /// Syncs chats from Firebase to local database
    func syncChatsFromFirebase(lastChatTime: String?, completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "syncChatsFromFirebase() Starting chats sync with lastChatTime: \(lastChatTime ?? "nil")")
        
        guard let userId = sessionManager.userId, !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "syncChatsFromFirebase() No valid user ID, skipping chats sync")
            completion(false)
            return
        }
        
        // Guard: Check if user is authenticated (Android parity)
        guard Auth.auth().currentUser != nil else {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "syncChatsFromFirebase() User not authenticated, skipping chats sync")
            completion(false)
            return
        }
        
        // Parse timestamp (Android parity: exact same logic)
        var timestamp: Timestamp
        let lastTime = lastChatTime ?? "0"
        
        if !lastTime.isEmpty && lastTime != "null" && lastTime != " " {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "syncChatsFromFirebase() LASTCHATTIME exists: \(lastTime)")
            if lastTime.count > 12 {
                let millisecond = Int64(lastTime) ?? 0
                timestamp = Timestamp(date: Date(timeIntervalSince1970: TimeInterval(millisecond / 1000)))
            } else {
                let millisecond = (Int64(lastTime) ?? 0) * 1000
                timestamp = Timestamp(date: Date(timeIntervalSince1970: TimeInterval(millisecond / 1000)))
            }
        } else {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "syncChatsFromFirebase() LASTCHATTIME does not exist")
            timestamp = Timestamp(date: Date(timeIntervalSince1970: 10))
        }
        
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "syncChatsFromFirebase() Timestamp: \(timestamp)")
        
        // Remove existing listener (Android parity)
        if let existingListener = chatsListener {
            existingListener.remove()
            chatsListener = nil
        }
        
        // Set up Firebase listener (Android parity: exact same query structure)
        chatsListener = db.collection("Users")
            .document(userId)
            .collection("Chats")
            .order(by: "last_message_timestamp", descending: true)
            .end(before: [timestamp])
            .limit(to: 10)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "syncChatsFromFirebase() Listen error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let documents = querySnapshot?.documentChanges else {
                    AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "syncChatsFromFirebase() No document changes")
                    completion(true)
                    return
                }
                
                var operationCount = 0
                let totalOperations = documents.count
                
                if totalOperations == 0 {
                    completion(true)
                    return
                }
                
                // Process document changes (Android parity)
                for documentChange in documents {
                    let document = documentChange.document
                    
                    switch documentChange.type {
                    case .added:
                        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "syncChatsFromFirebase() Added: \(document.documentID)")
                        self.processChatDocument(document: document) {
                            operationCount += 1
                            if operationCount >= totalOperations {
                                completion(true)
                            }
                        }
                        
                    case .modified:
                        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "syncChatsFromFirebase() Modified: \(document.documentID)")
                        self.processChatDocument(document: document) {
                            operationCount += 1
                            if operationCount >= totalOperations {
                                completion(true)
                            }
                        }
                        
                    case .removed:
                        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "syncChatsFromFirebase() Removed: \(document.documentID)")
                        self.deleteChatFromLocalDatabase(chatId: document.get("Chat_id") as? String ?? document.documentID) {
                            operationCount += 1
                            if operationCount >= totalOperations {
                                completion(true)
                            }
                        }
                    }
                }
            }
    }
    
    /// Android parity: Process individual chat document
    private func processChatDocument(document: DocumentSnapshot, completion: @escaping () -> Void) {
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processChatDocument() Processing document: \(document.documentID)")
        
        // Extract data (Android parity: exact same field extraction)
        let time: Int64
        if let timestamp = document.get("last_message_timestamp") as? Timestamp {
            time = timestamp.seconds
        } else {
            time = Int64(Date().timeIntervalSince1970)
        }
        
        let inbox = document.get("inbox") as? Bool ?? true
        let paid = document.get("paid") as? Bool ?? false
        let fetchMessageAfter = document.get("fetch_message_after") as? String ?? ""
        let coinGivenTime = document.get("coin_given_time") as? Int64 ?? 0
        let newMessage = document.get("new_message") as? Bool ?? false
        
        // Extract essential chat data
        let userUid = document.documentID
        let userName = document.get("User_name") as? String ?? ""
        let userGender = document.get("User_gender") as? String ?? ""
        let userImage = document.get("User_image") as? String ?? ""
        let userChatId = document.get("Chat_id") as? String ?? ""
        
        // CRITICAL FIX: Validate essential chat data before processing
        guard !userUid.isEmpty && userUid != "null" && 
              !userName.isEmpty && userName != "null" && userName.trimmingCharacters(in: .whitespaces) != "" &&
              !userChatId.isEmpty && userChatId != "null" else {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processChatDocument() REJECTING invalid chat - userUid: '\(userUid)', userName: '\(userName)', userChatId: '\(userChatId)'")
            completion()
            return
        }
        
        // Additional validation: Check for meaningful user data
        if userName.trimmingCharacters(in: .whitespaces).isEmpty {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processChatDocument() REJECTING chat with empty/whitespace-only userName: '\(userName)'")
            completion()
            return
        }
        
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processChatDocument() NEW_MESSAGE = \(newMessage)")
        
        // Check for conversation deletion (Android parity)
        if let conversationDeleted = document.get("conversation_deleted") as? Bool, conversationDeleted {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "processChatDocument() Conversation deleted, removing from local database")
            deleteChatFromLocalDatabase(chatId: userChatId, completion: completion)
            return
        }
        
        // Insert/update chat in local database (Android parity: InsertChatListUserAsyncTask)
        insertChatToLocalDatabase(
            userUid: userUid,
            userChatId: userChatId,
            userName: userName,
            userGender: userGender,
            userImage: userImage,
            time: time,
            completion: completion
        )
    }
    
    /// Android parity: InsertChatListUserAsyncTask.doInBackground()
    private func insertChatToLocalDatabase(
        userUid: String,
        userChatId: String,
        userName: String,
        userGender: String,
        userImage: String,
        time: Int64,
        completion: @escaping () -> Void
    ) {
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "insertChatToLocalDatabase() Inserting chat for user: \(userUid)")
        
        // CRITICAL FIX: Use ChatsDB directly instead of ChatManager to ensure proper view model updates
        guard let chatsDB = DatabaseManager.shared.getChatDB() else {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "insertChatToLocalDatabase() ChatsDB not available")
            completion()
            return
        }
        
        let timestamp = Date(timeIntervalSince1970: TimeInterval(time))
        
        // Use ChatsDB directly to ensure view model updates are triggered (Android parity)
        chatsDB.insert(
            ChatId: userChatId,
            UserId: userUid,
            Image: userImage,
            UserName: userName,
            Gender: userGender,
            Lastsentby: "", // Will be updated when messages are synced
            DeviceId: sessionManager.deviceId ?? "",
            LastTimeStamp: timestamp,
            NewMessage: 0, // Default value
            Group: 0, // Excluded feature: groups - always 0
            Inbox: 0, // Default to regular chat (not inbox)
            Type: "chat",
            LastMessageSentByUserId: nil
        )
        
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "insertChatToLocalDatabase() Chat saved successfully using ChatsDB: \(userChatId)")
        
        DispatchQueue.main.async {
            completion()
        }
    }
    
    /// Android parity: DeleteChatListUserAsyncTask.doInBackground()
    private func deleteChatFromLocalDatabase(chatId: String, completion: @escaping () -> Void) {
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "deleteChatFromLocalDatabase() Deleting chat: \(chatId)")
        
        // CRITICAL FIX: Use ChatsDB directly instead of ChatManager to ensure proper view model updates
        guard let chatsDB = DatabaseManager.shared.getChatDB() else {
            AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "deleteChatFromLocalDatabase() ChatsDB not available")
            completion()
            return
        }
        
        // Use ChatsDB directly to ensure view model updates are triggered (Android parity)
        chatsDB.delete(ChatId: chatId)
        
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "deleteChatFromLocalDatabase() Chat deletion completed: \(chatId)")
        
        DispatchQueue.main.async {
            completion()
        }
    }
    
    /// Clean up listeners (Android parity: onStopped)
    func stopListener() {
        AppLogger.log(tag: "LOG-APP: ChatsSyncService", message: "stopListener() Stopping chats listener")
        
        if let listener = chatsListener {
            listener.remove()
            chatsListener = nil
        }
    }
} 