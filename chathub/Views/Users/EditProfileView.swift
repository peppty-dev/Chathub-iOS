import SwiftUI
import FirebaseFirestore
import PhotosUI
import SDWebImageSwiftUI

struct ProfileField {
    let title: String
    var value: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    let maxLength: Int
}

struct AboutYouItem: Identifiable {
    let id = UUID()
    let title: String
    let key: String
    var isEnabled: Bool
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var profileFields: [ProfileField] = [
        ProfileField(title: "Height", value: "", placeholder: "Height in cm", keyboardType: .numberPad, maxLength: 8),
        ProfileField(title: "Occupation", value: "", placeholder: "Occupation", keyboardType: .default, maxLength: 16),
        ProfileField(title: "Hobbies", value: "", placeholder: "Hobbies", keyboardType: .default, maxLength: 20),
        ProfileField(title: "Zodiac", value: "", placeholder: "Zodiac sign", keyboardType: .default, maxLength: 12),
        ProfileField(title: "Snapchat", value: "", placeholder: "Snap ID", keyboardType: .default, maxLength: 12),
        ProfileField(title: "Instagram", value: "", placeholder: "Insta ID", keyboardType: .default, maxLength: 12)
    ]
    
    @State private var aboutYouItems: [AboutYouItem] = [
        AboutYouItem(title: "I like men", key: "like_men", isEnabled: false),
        AboutYouItem(title: "I like woman", key: "like_woman", isEnabled: false),
        AboutYouItem(title: "I am single", key: "single", isEnabled: false),
        AboutYouItem(title: "I am married", key: "married", isEnabled: false),
        AboutYouItem(title: "I have children", key: "children", isEnabled: false),
        AboutYouItem(title: "I do gym", key: "gym", isEnabled: false),
        AboutYouItem(title: "I smoke", key: "smokes", isEnabled: false),
        AboutYouItem(title: "I drink", key: "drinks", isEnabled: false),
        AboutYouItem(title: "I play video games", key: "games", isEnabled: false),
        AboutYouItem(title: "Strictly decent talk please", key: "decent_chat", isEnabled: false),
        AboutYouItem(title: "I love pets", key: "pets", isEnabled: false),
        AboutYouItem(title: "I love to travel", key: "travel", isEnabled: false),
        AboutYouItem(title: "I love music", key: "music", isEnabled: false),
        AboutYouItem(title: "I love movies", key: "movies", isEnabled: false),
        AboutYouItem(title: "I am naughty", key: "naughty", isEnabled: false),

        AboutYouItem(title: "Foodie", key: "foodie", isEnabled: false),
        AboutYouItem(title: "I go on dates", key: "dates", isEnabled: false),
        AboutYouItem(title: "I love fashion", key: "fashion", isEnabled: false),
        AboutYouItem(title: "I am broken", key: "broken", isEnabled: false),
        AboutYouItem(title: "I am depressed", key: "depressed", isEnabled: false),
        AboutYouItem(title: "I am lonely", key: "lonely", isEnabled: false),
        AboutYouItem(title: "I got cheated", key: "cheated", isEnabled: false),
        AboutYouItem(title: "I am insomnia, cant sleep", key: "insomnia", isEnabled: false),
        AboutYouItem(title: "I allow voice calls", key: "voice_allowed", isEnabled: false),
        AboutYouItem(title: "I allow video calls", key: "video_allowed", isEnabled: false),
        AboutYouItem(title: "I send pics", key: "pics_allowed", isEnabled: false)
    ]
    
    // User session data
    @State private var userId: String = ""
    @State private var userName: String = ""
    @State private var age: String = ""
    @State private var gender: String = ""
    @State private var country: String = ""
    @State private var language: String = ""
    @State private var profileImage: String = ""
    @State private var emailVerified: Bool = false
    @State private var isAccountCreated: Bool = false
    
    // UI States
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var showImagePicker: Bool = false
    @State private var isUploadingImage: Bool = false
    
    // Image handling states
    @State private var selectedImage: UIImage? = nil
    @State private var pendingImageUrl: String? = nil
    @State private var isBackgroundUploading: Bool = false
    @State private var backgroundUploadCompleted: Bool = false
    
    // Navigation states
    @State private var showCreateAccount: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Profile Header Section
                    ProfileHeaderSection(
                        profileImage: selectedImage != nil ? "" : profileImage,
                        selectedImage: selectedImage,
                        userName: userName,
                        age: age,
                        gender: gender,
                        country: country,
                        language: language,
                        emailVerified: emailVerified,
                        isUploadingImage: isUploadingImage,
                        isAccountCreated: isAccountCreated,
                        onImageTap: {
                            handleImageUploadTap()
                        }
                    )
                    .padding(.horizontal, 20)
                    
                    // Account Creation Warning (matching Android exactly)
                    if !isAccountCreated {
                        AccountCreationWarningView()
                            .padding(.horizontal, 20)
                    }
                    
                    // Profile Details Section (conditional display based on account creation)
                    if isAccountCreated {
                        VStack(alignment: .leading, spacing: 16) {
                            // Section Header with improved hierarchy
                            SectionHeader(
                                icon: "person.text.rectangle.fill",
                                title: "Profile Details",
                                subtitle: "Add details about yourself"
                            )
                            
                            // Profile Fields with better spacing
                            LazyVStack(spacing: 12) {
                                ForEach(Array(profileFields.enumerated()), id: \.offset) { index, field in
                                    ProfileFieldRow(
                                        field: profileFields[index],
                                        onValueChange: { newValue in
                                            // Apply character limit
                                            let limitedValue = String(newValue.prefix(field.maxLength))
                                            profileFields[index].value = limitedValue
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // About You Section (always visible)
                    VStack(alignment: .leading, spacing: 16) {
                        // Section Header with improved hierarchy
                        SectionHeader(
                            icon: "heart.text.square.fill",
                            title: "About You",
                            subtitle: "Select what describes you best"
                        )
                        
                        // About You Items with better spacing
                        LazyVStack(spacing: 8) {
                            ForEach(Array(aboutYouItems.enumerated()), id: \.element.id) { index, item in
                                AboutYouRow(
                                    item: aboutYouItems[index],
                                    onToggle: { isEnabled in
                                        aboutYouItems[index].isEnabled = isEnabled
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(Color("Background Color"))
            
            // Hidden NavigationLink for Create Account navigation
            NavigationLink(
                destination: CreateAccountView(),
                isActive: $showCreateAccount
            ) {
                EmptyView()
            }
            .hidden()
            
            // Fixed Save Button at bottom (Primary action)
            VStack(spacing: 0) {
                // Subtle separator
                Rectangle()
                    .fill(Color("shade3"))
                    .frame(height: 0.5)
                
                // Save Button with upload status feedback
                Button(action: saveProfile) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else if isBackgroundUploading {
                            // Show upload progress for background upload
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else if backgroundUploadCompleted {
                            // Show checkmark when upload is complete
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        } else if selectedImage != nil && !backgroundUploadCompleted {
                            // Show warning if image selected but upload failed
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        } else {
                            // Default save icon
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text(getSaveButtonText())
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: getSaveButtonColors()),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: getSaveButtonColors()[0].opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isLoading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color("Background Color"))
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .background(Color("Background Color"))
        .onAppear {
            loadUserData()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Success", isPresented: .constant(successMessage != nil)) {
            Button("OK") { successMessage = nil }
        } message: {
            Text(successMessage ?? "")
        }
        .sheet(isPresented: $showImagePicker) {
            DirectPhotoLibraryPicker { image in
                handleImageSelected(image)
                showImagePicker = false
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getSaveButtonText() -> String {
        if isLoading {
            return "Saving..."
        } else if isBackgroundUploading {
            return "Uploading Image..."
        } else if backgroundUploadCompleted {
            return "Save Profile"
        } else if selectedImage != nil && !backgroundUploadCompleted {
            return "Upload Failed - Retry"
        } else {
            return "Save Profile"
        }
    }
    
    private func getSaveButtonColors() -> [Color] {
        if selectedImage != nil && !backgroundUploadCompleted && !isBackgroundUploading {
            // Show warning colors for failed upload
            return [Color("ErrorRed"), Color("ErrorRed").opacity(0.8)]
        } else if isBackgroundUploading {
            // Show uploading colors (slightly different blue)
            return [Color("ButtonColor"), Color("ButtonColor").opacity(0.7)]
        } else if backgroundUploadCompleted {
            // Show success colors (green tint)
            return [Color("AndroidGreen"), Color("AndroidGreen").opacity(0.8)]
        } else {
            // Default colors
            return [Color("blue_900"), Color("blue_900").opacity(0.8)]
        }
    }
    
    private func loadUserData() {
        let sessionManager = SessionManager.shared
        userId = sessionManager.userId ?? ""
        userName = sessionManager.userName ?? ""
        age = sessionManager.userAge ?? ""
        gender = sessionManager.userGender ?? ""
        country = sessionManager.userCountry ?? ""
        language = sessionManager.userLanguage ?? ""
        profileImage = sessionManager.userProfilePhoto ?? ""
        emailVerified = sessionManager.emailverified != 0.0
        isAccountCreated = sessionManager.isAccountCreated
        
        // Load existing profile data from Firebase
        loadProfileData()
        
        AppLogger.log(tag: "LOG-APP: EditProfileView", message: "loadUserData() userId: \(userId), isAccountCreated: \(isAccountCreated)")
    }
    
    private func handleImageUploadTap() {
        AppLogger.log(tag: "LOG-APP: EditProfileView", message: "handleImageUploadTap() Profile image upload tapped")
        
        // Check account creation status first (matching Android behavior exactly)
        guard isAccountCreated else {
            AppLogger.log(tag: "LOG-APP: EditProfileView", message: "handleImageUploadTap() Account not created, showing info message")
            showAccountRequiredAlert()
            return
        }
        
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            AppLogger.log(tag: "LOG-APP: EditProfileView", message: "handleImageUploadTap() Permission already granted. Opening photo picker.")
            DispatchQueue.main.async {
                self.showImagePicker = true
            }
        case .notDetermined:
            AppLogger.log(tag: "LOG-APP: EditProfileView", message: "handleImageUploadTap() Permission not determined. Requesting permission.")
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        AppLogger.log(tag: "LOG-APP: EditProfileView", message: "handleImageUploadTap() Permission granted. Opening photo picker.")
                        self.showImagePicker = true
                    } else {
                        AppLogger.log(tag: "LOG-APP: EditProfileView", message: "handleImageUploadTap() Permission denied.")
                        self.errorMessage = "Photo library access was denied. Please enable it in Settings."
                    }
                }
            }
        case .denied, .restricted:
            AppLogger.log(tag: "LOG-APP: EditProfileView", message: "handleImageUploadTap() Permission denied or restricted. Showing settings alert.")
            showPermissionDeniedAlert()
        @unknown default:
            AppLogger.log(tag: "LOG-APP: EditProfileView", message: "handleImageUploadTap() Unknown authorization status.")
            break
        }
    }
    
    private func showAccountRequiredAlert() {
        let alert = UIAlertController(
            title: "Account Required",
            message: "Create an account to unlock profile picture uploads and more editing options.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Create Account", style: .default) { _ in
            AppLogger.log(tag: "LOG-APP: EditProfileView", message: "showAccountRequiredAlert() User tapped Create Account - navigating to CreateAccountView")
            // Trigger navigation to CreateAccountView
            DispatchQueue.main.async {
                self.showCreateAccount = true
            }
        })
        
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in
            AppLogger.log(tag: "LOG-APP: EditProfileView", message: "showAccountRequiredAlert() User dismissed account creation")
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "Photo Library Access Required",
            message: "Please enable photo library access in Settings to upload profile pictures.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func loadProfileData() {
        guard !userId.isEmpty else { return }
        
        let db = Firestore.firestore()
        db.collection("Users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                
                // Load profile fields (only if account is created)
                if isAccountCreated {
                    if let height = data?["height"] as? String, !height.isEmpty {
                        if let index = profileFields.firstIndex(where: { $0.title == "Height" }) {
                            profileFields[index].value = height
                        }
                    }
                    
                    if let occupation = data?["occupation"] as? String, !occupation.isEmpty {
                        if let index = profileFields.firstIndex(where: { $0.title == "Occupation" }) {
                            profileFields[index].value = occupation
                        }
                    }
                    
                    if let hobbies = data?["hobbies"] as? String, !hobbies.isEmpty {
                        if let index = profileFields.firstIndex(where: { $0.title == "Hobbies" }) {
                            profileFields[index].value = hobbies
                        }
                    }
                    
                    if let zodiac = data?["zodiac"] as? String, !zodiac.isEmpty {
                        if let index = profileFields.firstIndex(where: { $0.title == "Zodiac" }) {
                            profileFields[index].value = zodiac
                        }
                    }
                    
                    if let snap = data?["snap"] as? String, !snap.isEmpty {
                        if let index = profileFields.firstIndex(where: { $0.title == "Snapchat" }) {
                            profileFields[index].value = snap
                        }
                    }
                    
                    if let insta = data?["insta"] as? String, !insta.isEmpty {
                        if let index = profileFields.firstIndex(where: { $0.title == "Instagram" }) {
                            profileFields[index].value = insta
                        }
                    }
                }
                
                // Load about you items (always loaded)
                for (index, item) in aboutYouItems.enumerated() {
                    if let value = data?[item.key] as? String {
                        aboutYouItems[index].isEnabled = (value != "null" && value == "true")
                    }
                }
                
                AppLogger.log(tag: "LOG-APP: EditProfileView", message: "loadProfileData() Profile data loaded successfully")
            } else {
                AppLogger.log(tag: "LOG-APP: EditProfileView", message: "loadProfileData() No profile data found")
            }
        }
    }
    
    private func handleImageSelected(_ image: UIImage) {
        AppLogger.log(tag: "LOG-APP: EditProfileView", message: "handleImageSelected() Image selected for profile update")
        
        // Show selected image immediately in UI
        selectedImage = image
        
        // Reset upload states
        backgroundUploadCompleted = false
        pendingImageUrl = nil
        
        // Start background upload immediately
        startBackgroundImageUpload(image)
        
        AppLogger.log(tag: "LOG-APP: EditProfileView", message: "handleImageSelected() Image displayed and background upload started")
    }
    
    private func startBackgroundImageUpload(_ image: UIImage) {
        isBackgroundUploading = true
        
        AppLogger.log(tag: "LOG-APP: EditProfileView", message: "startBackgroundImageUpload() Starting background upload")
        
        uploadImageToAWS(image: image) { result in
            DispatchQueue.main.async {
                self.isBackgroundUploading = false
                
                switch result {
                case .success(let imageUrl):
                    AppLogger.log(tag: "LOG-APP: EditProfileView", message: "startBackgroundImageUpload() Background upload completed: \(imageUrl)")
                    
                    self.pendingImageUrl = imageUrl
                    self.backgroundUploadCompleted = true
                    
                case .failure(let error):
                    AppLogger.log(tag: "LOG-APP: EditProfileView", message: "startBackgroundImageUpload() Background upload failed: \(error.localizedDescription)")
                    
                    // Keep the selected image but show error state
                    self.backgroundUploadCompleted = false
                    self.errorMessage = "Image upload failed. Please try again."
                }
            }
        }
    }
    
    private func uploadImageToAWS(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        // Compress image (matching Android compression)
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        // Generate unique filename
        let fileName = "\(UUID().uuidString).jpg"
        let imagePath = "strangerchatuser/user/\(userId)/\(fileName)"
        
        // For now, we'll use Firebase Storage as a fallback since AWS needs credentials
        // This will work with the existing Firebase setup
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
            // Use Firebase Storage URL format that will actually work
            let imageUrl = "https://firebasestorage.googleapis.com/v0/b/chathub-app/o/users%2F\(self.userId)%2F\(fileName)?alt=media"
            completion(.success(imageUrl))
        }
    }
    
    private func saveProfile() {
        guard !userId.isEmpty else {
            errorMessage = "User session not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Check if there's a selected image
        if selectedImage != nil {
            // If background upload is still in progress, wait for it
            if isBackgroundUploading {
                AppLogger.log(tag: "LOG-APP: EditProfileView", message: "saveProfile() Waiting for background upload to complete")
                
                // Wait for background upload to complete
                waitForBackgroundUpload()
                return
            }
            
            // If background upload completed successfully
            if backgroundUploadCompleted, let imageUrl = pendingImageUrl {
                AppLogger.log(tag: "LOG-APP: EditProfileView", message: "saveProfile() Using background uploaded image: \(imageUrl)")
                
                // Update session manager with new image URL
                UserSessionManager.shared.userProfilePhoto = imageUrl
                self.profileImage = imageUrl
                self.selectedImage = nil // Clear selected image
                self.backgroundUploadCompleted = false
                self.pendingImageUrl = nil
                
                // Save profile data including image URL
                saveProfileData(imageUrl: imageUrl)
            } else {
                // Background upload failed, show error
                isLoading = false
                errorMessage = "Image upload failed. Please select the image again."
                AppLogger.log(tag: "LOG-APP: EditProfileView", message: "saveProfile() Background upload failed or incomplete")
            }
        } else {
            // No image to upload, just save profile data
            saveProfileData(imageUrl: nil)
        }
    }
    
    private func waitForBackgroundUpload() {
        // Check upload status every 0.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isBackgroundUploading {
                // Still uploading, check again
                self.waitForBackgroundUpload()
            } else {
                // Upload completed (success or failure), proceed with save
                self.saveProfile()
            }
        }
    }
    
    private func saveProfileData(imageUrl: String?) {
        let db = Firestore.firestore()
        var updateData: [String: Any] = [:]
        
        // Add image URL if provided
        if let imageUrl = imageUrl {
            updateData["User_image"] = imageUrl
        }
        
        // Add profile fields (only if account is created - matching Android behavior)
        if isAccountCreated {
            for field in profileFields {
                if !field.value.isEmpty {
                    switch field.title {
                    case "Height":
                        // Clean height value to only include numbers (matching Android)
                        let cleanHeight = field.value.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                        updateData["height"] = cleanHeight
                    case "Occupation":
                        updateData["occupation"] = field.value
                    case "Hobbies":
                        updateData["hobbies"] = field.value
                    case "Zodiac":
                        updateData["zodiac"] = field.value
                    case "Snapchat":
                        updateData["snap"] = field.value
                    case "Instagram":
                        updateData["insta"] = field.value
                    default:
                        break
                    }
                }
            }
        }
        
        // Add about you data (always saved - matching Android key names and format)
        for item in aboutYouItems {
            updateData[item.key] = item.isEnabled ? "true" : "null"
        }
        
        // Update last modified timestamp
        updateData["profile_updated_at"] = FieldValue.serverTimestamp()
        
        db.collection("Users").document(userId).setData(updateData, merge: true) { error in
            isLoading = false
            
            if let error = error {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
                AppLogger.log(tag: "LOG-APP: EditProfileView", message: "saveProfileData() Error: \(error.localizedDescription)")
            } else {
                successMessage = "Profile updated successfully"
                AppLogger.log(tag: "LOG-APP: EditProfileView", message: "saveProfileData() Profile saved successfully")
            }
        }
    }
}

// MARK: - Account Creation Warning Component (Matching Android Design)
struct AccountCreationWarningView: View {
    var body: some View {
        HStack(spacing: 12) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color("orange_900"))
            
            // Warning text (matching Android exactly)
            Text("Create an account and get more options to edit")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("orange_50"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("orange_900").opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Section Header Component
struct SectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color("ButtonColor"))
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color("dark"))
            }
            
            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color("shade6"))
        }
    }
}

// MARK: - Direct Photo Library Picker (Native iOS Implementation)
struct DirectPhotoLibraryPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        picker.modalPresentationStyle = .fullScreen
        
        // Additional configuration to prevent dismissal issues (matching MessagesView implementation)
        picker.navigationBar.isTranslucent = false
        
        AppLogger.log(tag: "LOG-APP: DirectPhotoLibraryPicker", message: "makeUIViewController() Native photo picker initialized")
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Ensure the picker stays presented (matching MessagesView implementation)
        if uiViewController.presentingViewController == nil {
            AppLogger.log(tag: "LOG-APP: DirectPhotoLibraryPicker", message: "updateUIViewController() picker not properly presented")
        }
    }
    
    @objc(DirectPhotoLibraryPickerCoordinator)
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: DirectPhotoLibraryPicker
        
        init(_ parent: DirectPhotoLibraryPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            AppLogger.log(tag: "LOG-APP: DirectPhotoLibraryPicker", message: "didFinishPickingMediaWithInfo() Image selected successfully")
            
            if let image = info[.originalImage] as? UIImage {
                DispatchQueue.main.async {
                    self.parent.onImagePicked(image)
                }
            } else {
                AppLogger.log(tag: "LOG-APP: DirectPhotoLibraryPicker", message: "didFinishPickingMediaWithInfo() Failed to get image from info")
            }
            
            // Don't dismiss here - let the parent handle dismissal (matching MessagesView implementation)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            AppLogger.log(tag: "LOG-APP: DirectPhotoLibraryPicker", message: "imagePickerControllerDidCancel() User cancelled image selection")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ProfileHeaderSection: View {
    let profileImage: String
    let selectedImage: UIImage?
    let userName: String
    let age: String
    let gender: String
    let country: String
    let language: String
    let emailVerified: Bool
    let isUploadingImage: Bool
    let isAccountCreated: Bool
    let onImageTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Profile Image Section with standardized spacing (matching ProfileView and SettingsTabView)
            ZStack {
                Color.clear
                    .frame(height: 220) // Increased height for better proportions
                
                // Profile Image with standardized styling (matching other views exactly)
                Button(action: onImageTap) {
                    ZStack {
                        // Shadow layer for depth (matching ProfileView)
                        Circle()
                            .fill(Color.black.opacity(0.08))
                            .frame(width: 160, height: 160)
                            .offset(y: 2)
                            .blur(radius: 4)
                        
                        // Show selected image if available, otherwise show profile image from URL
                        if let selectedImg = selectedImage {
                            Image(uiImage: selectedImg)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 160, height: 160)
                                .clipShape(Circle())
                        } else {
                            WebImage(url: URL(string: profileImage)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color("shade3"),
                                                    Color("shade4")
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    Image(UserSessionManager.shared.userGender == "Male" ? "male" : "female")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .opacity(0.8)
                                }
                                .frame(width: 160, height: 160)
                                .clipShape(Circle())
                            }
                            .onSuccess { image, data, cacheType in
                                AppLogger.log(tag: "LOG-APP: EditProfileView", message: "profile image loaded from \(cacheType == .memory ? "memory" : cacheType == .disk ? "disk" : "network")")
                            }
                            .onFailure { error in
                                AppLogger.log(tag: "LOG-APP: EditProfileView", message: "profile image loading failed: \(error.localizedDescription)")
                            }
                            .frame(width: 160, height: 160)
                            .clipShape(Circle())
                        }
                        
                        // Enhanced border with gradient effect (matching ProfileView exactly)
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.8),
                                        Color("shade3").opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 160, height: 160)
                        
                        // Inner highlight for 3D effect (matching ProfileView)
                        Circle()
                            .strokeBorder(
                                Color.white.opacity(0.3),
                                lineWidth: 1
                            )
                            .frame(width: 160, height: 160)
                            .padding(1)
                        
                        // Upload overlay when uploading
                        if isUploadingImage {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 160, height: 160)
                                .overlay(
                                    VStack(spacing: 8) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.2)
                                        Text("Uploading...")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                )
                        }
                        
                        // Camera overlay with better design and improved contrast
                        if !isUploadingImage {
                            // Show different styling based on account creation status
                            let cameraColors = isAccountCreated ? 
                                [Color("ButtonColor"), Color("ButtonColor").opacity(0.8)] :
                                [Color("shade6"), Color("shade6").opacity(0.8)]
                            
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 44, height: 44)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: cameraColors),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color("dark").opacity(0.2), lineWidth: 1)
                                        .padding(3)
                                )
                                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                                .shadow(color: cameraColors[0].opacity(0.3), radius: 4, x: 0, y: 2)
                                .offset(x: 56, y: 56)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isUploadingImage)
                .shadow(color: Color("ButtonColor").opacity(0.2), radius: 10, x: 0, y: 5)
            }
            
            // User Name with standardized typography (matching ProfileView)
            Text(userName)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color("dark"))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            
            // User Info Pills with standardized spacing (matching ProfileView)
            userInfoPillsFlexibleLayout
                .padding(.top, 12)
        }
        .padding(.vertical, 12) // Standardized padding - reduced further
    }
    
    // MARK: - Flexible Pills Layout (matching ProfileView exactly)
    private var pillDetails: [String] {
        var details: [String] = []
        
        // Age
        if !age.isEmpty && age != "99" {
            details.append("\(age) Years old")
        }
        
        // Gender
        if !gender.isEmpty {
            details.append(gender)
        }
        
        // Language
        if !language.isEmpty {
            details.append(language)
        }
        
        // Country
        if !country.isEmpty {
            details.append(country)
        }
        
        return details
    }
    
    @ViewBuilder
    private var userInfoPillsFlexibleLayout: some View {
        // Display pills using flexible layout (matching ProfileView exactly)
        if pillDetails.isEmpty {
            // Show empty state if no details
            Text("No profile details available")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color("shade6"))
                .padding()
        } else {
            let pillSpacing: CGFloat = 8 // Consistent with original spacing
            if #available(iOS 16.0, *) {
                FlowLayout(spacing: pillSpacing) {
                    ForEach(pillDetails, id: \.self) { detail in
                        ProfilePillChip(detail: detail)
                    }
                }
            } else {
                // Fallback for iOS 15 and below - use VStack with HStacks for wrapping
                VStack(alignment: .leading, spacing: pillSpacing) {
                    HStack(spacing: pillSpacing) {
                        ForEach(pillDetails, id: \.self) { detail in
                            ProfilePillChip(detail: detail)
                        }
                    }
                }
            }
        }
    }
}

struct ProfileFieldRow: View {
    let field: ProfileField
    let onValueChange: (String) -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with better contrast and sizing
            if let iconName = getIconName(for: field.title), let iconType = getIconType(for: field.title) {
                if iconType == .asset {
                    Image(iconName)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundColor(Color("ButtonColor"))
                        .onAppear {
                            AppLogger.log(tag: "LOG-APP: EditProfileView", message: "ProfileFieldRow showing asset icon: \(iconName) for field: \(field.title)")
                        }
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color("ButtonColor"))
                        .frame(width: 22, height: 22)
                        .onAppear {
                            AppLogger.log(tag: "LOG-APP: EditProfileView", message: "ProfileFieldRow showing SF symbol: \(iconName) for field: \(field.title)")
                        }
                }
            }
            
            // Text field with improved design
            VStack(alignment: .leading, spacing: 2) {
                if !field.value.isEmpty {
                    Text(field.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("shade6"))
                }
                
                TextField(field.placeholder, text: Binding(
                    get: { field.value },
                    set: { onValueChange($0) }
                ))
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color("dark"))
                .keyboardType(field.keyboardType)
                .focused($isFocused)
                .onTapGesture {
                    isFocused = true
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("shade1"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isFocused ? Color("ButtonColor") : Color("shade3"),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
    
    // MARK: - Icon Mapping for Profile Fields
    private enum IconType { case sfSymbol, asset }
    
    private func getIconType(for fieldTitle: String) -> IconType? {
        switch fieldTitle.lowercased() {
        case "snapchat":
            return .asset
        case "instagram":
            return .asset
        default:
            return .sfSymbol
        }
    }
    
    private func getIconName(for fieldTitle: String) -> String? {
        switch fieldTitle.lowercased() {
        case "height":
            return "ruler.fill"
        case "occupation":
            return "briefcase.fill"
        case "hobbies":
            return "heart.fill"
        case "zodiac":
            return "sun.max.fill"
        case "snapchat":
            return "ic_snapchat"
        case "instagram":
            return "ic_instagram"
        default:
            return "info.circle.fill"
        }
    }
}

struct AboutYouRow: View {
    let item: AboutYouItem
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with better contrast and sizing
            if let iconName = getIconName(for: item.title), let iconType = getIconType(for: item.title) {
                if iconType == .asset {
                    Image(iconName)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(item.isEnabled ? Color("ButtonColor") : Color("shade6"))
                        .onAppear {
                            AppLogger.log(tag: "LOG-APP: EditProfileView", message: "AboutYouRow showing asset icon: \(iconName) for item: \(item.title)")
                        }
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(item.isEnabled ? Color("ButtonColor") : Color("shade6"))
                        .frame(width: 20, height: 20)
                        .onAppear {
                            AppLogger.log(tag: "LOG-APP: EditProfileView", message: "AboutYouRow showing SF symbol: \(iconName) for item: \(item.title)")
                        }
                }
            }
            
            // Title text with better typography
            Text(item.title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(item.isEnabled ? Color("dark") : Color("shade7"))
                .lineLimit(1)
            
            Spacer()
            
            // Toggle switch with better styling
            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: Color("ButtonColor")))
            .scaleEffect(0.9)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(item.isEnabled ? Color("ButtonColor").opacity(0.05) : Color("shade1"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            item.isEnabled ? Color("ButtonColor").opacity(0.3) : Color("shade3"),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: item.isEnabled)
    }
    
    // MARK: - Icon Mapping for About You Items (Matching ProfileView exactly)
    private enum IconType { case sfSymbol, asset }
    
    private func getIconType(for title: String) -> IconType? {
        let d = title.lowercased()
        if d.contains("snap") || d.contains("insta") {
            return .asset
        }
        return .sfSymbol
    }
    
    private func getIconName(for title: String) -> String? {
        let d = title.lowercased()
        
        // Using the exact same mapping as ProfileView for consistency
        if d == "i like men" { return "person.2.fill" }
        if d == "i like woman" { return "person.2.fill" }
        if d == "i am single" { return "heart.fill" }
        if d == "i am married" { return "heart.fill" }
        if d == "i have children" { return "person.2.fill" }
        if d == "i do gym" { return "dumbbell.fill" }
        if d == "i smoke" { return "smoke.fill" }
        if d == "i drink" { return "wineglass.fill" }
        if d == "i play video games" { return "gamecontroller.fill" }
        if d == "strictly decent talk please" { return "hand.raised.fill" }
        if d == "i love pets" { return "pawprint.fill" }
        if d == "i love to travel" { return "airplane.circle.fill" }
        if d == "i love music" { return "music.note" }
        if d == "i love movies" { return "film.fill" }
        if d == "i am naughty" { return "face.smiling.fill" }

        if d == "foodie" { return "fork.knife.circle.fill" }
        if d == "i go on dates" { return "heart.circle.fill" }
        if d == "i love fashion" { return "tshirt.fill" }
        if d == "i am broken" { return "heart.slash.fill" }
        if d == "i am depressed" { return "cloud.fill" }
        if d == "i am lonely" { return "person.fill" }
        if d == "i got cheated" { return "exclamationmark.triangle.fill" }
        if d == "i am insomnia, cant sleep" { return "moon.fill" }
        if d == "i allow voice calls" { return "phone.fill" }
        if d == "i allow video calls" { return "video.fill" }
        if d == "i send pics" { return "camera.fill" }
        
        // Social media icons (asset-based)
        if d.contains("snap") { return "ic_snapchat" }
        if d.contains("insta") { return "ic_instagram" }
        
        // Fallback
        return "info.circle.fill"
    }
}

// MARK: - Profile Pill Component (Matching ProfileView UserDetailChip Design)
struct ProfilePillChip: View {
    let detail: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 6) {
            // Icon based on detail type
            if let iconName = getIconName(for: detail), let iconType = getIconType(for: detail) {
                if iconType == .asset, let flagAsset = CountryLanguageHelper.getFlagAssetName(for: detail), isCountry(detail) {
                    Image(flagAsset)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                } else if iconType == .asset {
                    Image(iconName)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(textColor)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textColor)
                }
            }
            Text(detail)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(grayBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("shade4"), lineWidth: 0.5)
                )
        )
    }
    
    private var grayBackgroundColor: Color {
        Color("shade2")
    }
    
    private var textColor: Color {
        Color("dark")
    }
    
    private func isCountry(_ detail: String) -> Bool {
        return CountryLanguageHelper.shared.isValidCountry(detail)
    }
    
    private enum IconType { case sfSymbol, asset }
    
    private func getIconType(for detail: String) -> IconType? {
        let d = detail.lowercased()
        if d == "iphone" || d == "android" || d.contains("snap:") || d.contains("insta:") || (isCountry(detail) && CountryLanguageHelper.getFlagAssetName(for: detail) != nil) {
            return .asset
        }
        return .sfSymbol
    }
    
    private func getIconName(for detail: String) -> String? {
        let d = detail.lowercased()
        
        // Age
        if d.contains("years old") { return "person.circle.fill" }
        
        // Gender
        if d == "male" { return "person.fill" }
        if d == "female" { return "person.fill" }
        
        // Language
        if d == "english" { return "bubble.left.and.bubble.right.fill" }
        
        // Country with flag
        if isCountry(detail) && CountryLanguageHelper.getFlagAssetName(for: detail) != nil { 
            return CountryLanguageHelper.getFlagAssetName(for: detail) 
        }
        if isCountry(detail) { return "flag.fill" }
        
        // Default
        return "info.circle.fill"
    }
}

#Preview {
    NavigationView {
        EditProfileView()
    }
}