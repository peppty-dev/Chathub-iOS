import Foundation
import FirebaseFirestore
import UIKit

/// ModerationService - iOS equivalent of Android ModerationWorker
/// Handles text, image, and ad policy moderation with 100% Android parity
class ModerationService {
    
    // MARK: - Singleton
    static let shared = ModerationService()
    private init() {}
    
    // MARK: - Properties (Android Parity)
    private let sessionManager = SessionManager.shared
    
    // MARK: - Text Moderation Methods
    
    func incrementTextModerationScore() {
        AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementTextModerationScore() starting")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementTextModerationScore() no userId found")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.updateData([
            "textModerationScore": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementTextModerationScore() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementTextModerationScore() success")
            }
        }
    }
    
    func checkAndSetTextModerationWarningIfNeeded() {
        AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetTextModerationWarningIfNeeded() starting")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetTextModerationWarningIfNeeded() no userId found")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.getDocument { [weak self] (document, error) in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetTextModerationWarningIfNeeded() error: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data() else {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetTextModerationWarningIfNeeded() no document data")
                return
            }
            
            let textModerationScore = data["textModerationScore"] as? Int ?? 0
            let textModerationWarningShown = data["textModerationWarningShown"] as? Bool ?? false
            
            if textModerationScore >= 3 && !textModerationWarningShown {
                self?.setTextModerationWarningShown()
                self?.showTextModerationWarning()
            }
        }
    }
    
    private func setTextModerationWarningShown() {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else { return }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.updateData([
            "textModerationWarningShown": true
        ]) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "setTextModerationWarningShown() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "setTextModerationWarningShown() success")
            }
        }
    }
    
    private func showTextModerationWarning() {
        DispatchQueue.main.async {
            // TODO: Implement text moderation warning UI
            AppLogger.log(tag: "LOG-APP: ModerationService", message: "showTextModerationWarning() - UI implementation needed")
        }
    }
    
    // MARK: - Image Moderation Methods
    
    func incrementImageModerationScore() {
        AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementImageModerationScore() starting")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementImageModerationScore() no userId found")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.updateData([
            "imageModerationScore": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementImageModerationScore() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementImageModerationScore() success")
            }
        }
    }
    
    func checkAndSetImageModerationWarningIfNeeded() {
        AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetImageModerationWarningIfNeeded() starting")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetImageModerationWarningIfNeeded() no userId found")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.getDocument { [weak self] (document, error) in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetImageModerationWarningIfNeeded() error: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data() else {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetImageModerationWarningIfNeeded() no document data")
                return
            }
            
            let imageModerationScore = data["imageModerationScore"] as? Int ?? 0
            let imageModerationWarningShown = data["imageModerationWarningShown"] as? Bool ?? false
            
            if imageModerationScore >= 2 && !imageModerationWarningShown {
                self?.setImageModerationWarningShown()
                self?.showImageModerationWarning()
            }
        }
    }
    
    private func setImageModerationWarningShown() {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else { return }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.updateData([
            "imageModerationWarningShown": true
        ]) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "setImageModerationWarningShown() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "setImageModerationWarningShown() success")
            }
        }
    }
    
    private func showImageModerationWarning() {
        DispatchQueue.main.async {
            // TODO: Implement image moderation warning UI
            AppLogger.log(tag: "LOG-APP: ModerationService", message: "showImageModerationWarning() - UI implementation needed")
        }
    }
    
    // MARK: - Ad Policy Moderation Methods
    
    func incrementAdPolicyModerationScore() {
        AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementAdPolicyModerationScore() starting")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementAdPolicyModerationScore() no userId found")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.updateData([
            "adPolicyModerationScore": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementAdPolicyModerationScore() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "incrementAdPolicyModerationScore() success")
            }
        }
    }
    
    func checkAndSetAdPolicyModerationWarningIfNeeded() {
        AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetAdPolicyModerationWarningIfNeeded() starting")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetAdPolicyModerationWarningIfNeeded() no userId found")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.getDocument { [weak self] (document, error) in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetAdPolicyModerationWarningIfNeeded() error: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data() else {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAndSetAdPolicyModerationWarningIfNeeded() no document data")
                return
            }
            
            let adPolicyModerationScore = data["adPolicyModerationScore"] as? Int ?? 0
            let adPolicyModerationWarningShown = data["adPolicyModerationWarningShown"] as? Bool ?? false
            
            if adPolicyModerationScore >= 1 && !adPolicyModerationWarningShown {
                self?.setAdPolicyModerationWarningShown()
                self?.showAdPolicyModerationWarning()
            }
        }
    }
    
    private func setAdPolicyModerationWarningShown() {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else { return }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.updateData([
            "adPolicyModerationWarningShown": true
        ]) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "setAdPolicyModerationWarningShown() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "setAdPolicyModerationWarningShown() success")
            }
        }
    }
    
    private func showAdPolicyModerationWarning() {
        DispatchQueue.main.async {
            // TODO: Implement ad policy moderation warning UI
            AppLogger.log(tag: "LOG-APP: ModerationService", message: "showAdPolicyModerationWarning() - UI implementation needed")
        }
    }
    
    // MARK: - General Policy Methods
    
    func checkAllModerationPolicies() {
        AppLogger.log(tag: "LOG-APP: ModerationService", message: "checkAllModerationPolicies() starting")
        
        checkAndSetTextModerationWarningIfNeeded()
        checkAndSetImageModerationWarningIfNeeded()
        checkAndSetAdPolicyModerationWarningIfNeeded()
    }
    
    func resetModerationScores() {
        AppLogger.log(tag: "LOG-APP: ModerationService", message: "resetModerationScores() starting")
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        guard !userId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ModerationService", message: "resetModerationScores() no userId found")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("Users").document(userId)
        
        userRef.updateData([
            "textModerationScore": 0,
            "imageModerationScore": 0,
            "adPolicyModerationScore": 0,
            "textModerationWarningShown": false,
            "imageModerationWarningShown": false,
            "adPolicyModerationWarningShown": false
        ]) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "resetModerationScores() error: \(error.localizedDescription)")
            } else {
                AppLogger.log(tag: "LOG-APP: ModerationService", message: "resetModerationScores() success")
            }
        }
    }
} 