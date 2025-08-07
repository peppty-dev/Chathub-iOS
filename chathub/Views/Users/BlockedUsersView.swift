import SwiftUI
import FirebaseFirestore
import SDWebImageSwiftUI

struct BlockedUsersView: View {
    @State private var blockedUsers: [Chat] = []
    @State private var docIds: [String] = []
    @State private var isLoading = true
    @State private var showUnblockPopup = false
    @State private var selectedUser: Chat?
    @State private var selectedUserId = ""
    @State private var selectedUserDevId = ""
    @State private var firestoreListener: ListenerRegistration?
    @Environment(\.dismiss) private var dismiss
    
    private let userId = UserSessionManager.shared.userId ?? ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Loading blocked users...")
                        .foregroundColor(Color("dark"))
                    Spacer()
                } else if blockedUsers.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 50))
                            .foregroundColor(Color("shade8"))
                        Text("No blocked users")
                            .font(.title2)
                            .foregroundColor(Color("dark"))
                        Text("Users you block will appear here")
                            .font(.body)
                            .foregroundColor(Color("shade8"))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(Array(blockedUsers.enumerated()), id: \.offset) { index, user in
                            BlockedUserRow(
                                user: user,
                                onProfileTap: {
                                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "profileTap() user profile tapped: \(user.Name)")
                                    // Navigate to profile - placeholder for now
                                },
                                onUnblockTap: {
                                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "unblockTap() unblock button tapped for user: \(user.Name)")
                                    selectedUser = user
                                    selectedUserId = docIds[index]
                                    fetchUserDeviceId(userId: selectedUserId)
                                }
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Blocked users")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "onAppear() loading blocked users")
                loadBlockedUsers()
            }
            .onDisappear {
                AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "onDisappear() removing Firebase listener")
                firestoreListener?.remove()
            }
            .sheet(isPresented: $showUnblockPopup) {
                DeleteChatPopUpView(
                    title: "Unblock user",
                    description: "Do you want to Unblock user?",
                    buttonTitle: "Unblock user",
                    isPresented: $showUnblockPopup,
                    onConfirm: {
                        unblockUser()
                    },
                    onCancel: {
                        // Cancel action - no additional logic needed
                    }
                )
            }
        }
    }
    
    private func loadBlockedUsers() {
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "loadBlockedUsers() error: userId is empty")
            isLoading = false
            return
        }
        
        firestoreListener = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("BlockedUserList")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "loadBlockedUsers() Firebase error: \(error.localizedDescription)")
                    isLoading = false
                    return
                }
                
                guard let snapshot = snapshot else {
                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "loadBlockedUsers() error: snapshot is nil")
                    isLoading = false
                    return
                }
                
                snapshot.documentChanges.forEach { diff in
                    let documentId = diff.document.documentID
                    
                    if diff.type == .added {
                        AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "loadBlockedUsers() user added to blocked list: \(documentId)")
                        fetchUserDetails(userId: documentId)
                    }
                    
                    if diff.type == .removed {
                        AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "loadBlockedUsers() user removed from blocked list: \(documentId)")
                        if let index = docIds.firstIndex(of: documentId) {
                            blockedUsers.remove(at: index)
                            docIds.remove(at: index)
                        }
                    }
                }
                
                isLoading = false
            }
    }
    
    private func fetchUserDetails(userId: String) {
        Firestore.firestore()
            .collection("Users")
            .document(userId)
            .getDocument { document, error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "fetchUserDetails() Firebase error: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document,
                      document.exists,
                      let data = document.data() else {
                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "fetchUserDetails() error: document doesn't exist for userId: \(userId)")
                    return
                }
                
                let name = data["User_name"] as? String ?? ""
                let gender = data["User_gender"] as? String ?? ""
                let profileImage = data["User_image"] as? String ?? ""
                
                if !docIds.contains(userId) {
                    let userChat = Chat(
                        ChatId: userId,
                        UserId: document.documentID,
                        ProfileImage: profileImage,
                        Name: name,
                        Lastsentby: "",
                        Gender: gender,
                        DeviceId: "",
                        LastTimeStamp: Date(),
                        newmessage: false,
                        inbox: 0, // Regular chat (not inbox chat)
                        type: "",
                        lastMessageSentByUserId: ""
                    )
                    
                    blockedUsers.insert(userChat, at: 0)
                    docIds.insert(userId, at: 0)
                    
                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "fetchUserDetails() added blocked user: \(name)")
                }
            }
    }
    
    private func fetchUserDeviceId(userId: String) {
        Firestore.firestore()
            .collection("Users")
            .document(userId)
            .getDocument { document, error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "fetchUserDeviceId() Firebase error: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document,
                      document.exists,
                      let data = document.data() else {
                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "fetchUserDeviceId() error: document doesn't exist for userId: \(userId)")
                    return
                }
                
                selectedUserDevId = data["User_device_id"] as? String ?? ""
                showUnblockPopup = true
            }
    }
    
    private func unblockUser() {
        guard !selectedUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "unblockUser() error: selectedUserId is empty")
            return
        }
        
        AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "unblockUser() unblocking user: \(selectedUserId)")
        
        // Decrement blocks count for the user being unblocked
        if !selectedUserDevId.isEmpty {
            let params: [String: Any] = ["blocks": FieldValue.increment(Double(-1))]
            Firestore.firestore()
                .collection("UserDevData")
                .document(selectedUserDevId)
                .setData(params, merge: true)
        }
        
        // Remove from blocked users list
        Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("BlockedUserList")
            .document(selectedUserId)
            .delete { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "unblockUser() Firebase error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "unblockUser() successfully unblocked user: \(selectedUserId)")
                }
            }
        
        // Reset selection
        selectedUser = nil
        selectedUserId = ""
        selectedUserDevId = ""
    }
}

struct BlockedUserRow: View {
    let user: Chat
    let onProfileTap: () -> Void
    let onUnblockTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            Button(action: onProfileTap) {
                WebImage(url: URL(string: user.ProfileImage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(user.Gender == "Male" ? "male" : "female")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                }
                .onSuccess { image, data, cacheType in
                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "blocked user image loaded")
                }
                .onFailure { error in
                    AppLogger.log(tag: "LOG-APP: BlockedUsersView", message: "blocked user image failed: \(error.localizedDescription)")
                }
                .indicator(.activity)
                .transition(.opacity)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color("shade3"), lineWidth: 2)
                    )
                    .background(
                        Image(user.Gender == "Male" ? "male" : "female")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                                        Text(Profanity.share.removeProfanityNumbersAllowed(user.Name))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("dark"))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: user.Gender == "Male" ? "person.fill" : "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(user.Gender == "Male" ? Color("maleColor") : Color("femaleColor"))
                    
                    Text(user.Gender)
                        .font(.system(size: 14))
                        .foregroundColor(Color("shade8"))
                }
            }
            
            Spacer()
            
            // Unblock Button
            Button(action: onUnblockTap) {
                Text("Unblock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color("Here"))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("Background Color"))
        .onTapGesture {
            onUnblockTap()
        }
    }
}

// REMOVED: Duplicate profanity function - using the global one from Profanity.swift

#Preview {
    BlockedUsersView()
} 