import Foundation
import FirebaseFirestore

/// ReportPhotoService - iOS equivalent of Android ReportPhotoWorker
/// Provides photo reporting functionality with 100% Android parity
class ReportPhotoService {
    
    // MARK: - Singleton
    static let shared = ReportPhotoService()
    private init() {}
    
    // MARK: - Properties (Android Parity)
    private let sessionManager = SessionManager.shared
    private let database = Firestore.firestore()
    
    // MARK: - Public Methods (Android Parity)
    
    /// Reports a photo - Android doWork() equivalent
    /// - Parameters:
    ///   - imageUrl: URL of the image to report
    ///   - otherUserId: ID of the user whose photo is being reported
    ///   - reason: Reason for reporting
    ///   - completion: Completion handler with success status
    func reportPhoto(
        imageUrl: String,
        otherUserId: String,
        reason: String = "Inappropriate content",
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "reportPhoto() imageUrl: \(imageUrl), otherUserId: \(otherUserId)")
        
        // Validate parameters - Android parity
        guard !imageUrl.isEmpty && !otherUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "reportPhoto() missing required parameters")
            completion(false)
            return
        }
        
        guard let currentUserId = sessionManager.userId, !currentUserId.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "reportPhoto() no current user ID")
            completion(false)
            return
        }
        
        // Execute on background queue - Android parity
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            
            self.submitPhotoReport(
                imageUrl: imageUrl,
                reportedUserId: otherUserId,
                reporterUserId: currentUserId,
                reason: reason,
                completion: completion
            )
        }
    }
    
    /// Reports multiple photos - Android parity extension
    /// - Parameters:
    ///   - imageUrls: Array of image URLs to report
    ///   - otherUserId: ID of the user whose photos are being reported
    ///   - reason: Reason for reporting
    ///   - completion: Completion handler with success status
    func reportMultiplePhotos(
        imageUrls: [String],
        otherUserId: String,
        reason: String = "Inappropriate content",
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "reportMultiplePhotos() reporting \(imageUrls.count) photos from user: \(otherUserId)")
        
        guard !imageUrls.isEmpty else {
            AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "reportMultiplePhotos() no images to report")
            completion(false)
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var successCount = 0
        var totalCount = imageUrls.count
        
        for imageUrl in imageUrls {
            dispatchGroup.enter()
            
            reportPhoto(imageUrl: imageUrl, otherUserId: otherUserId, reason: reason) { success in
                if success {
                    successCount += 1
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let allSuccessful = successCount == totalCount
            AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "reportMultiplePhotos() completed: \(successCount)/\(totalCount) successful")
            completion(allSuccessful)
        }
    }
    
    /// Gets report status for a photo
    func getReportStatus(imageUrl: String, completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "getReportStatus() checking status for: \(imageUrl)")
        
        guard let currentUserId = sessionManager.userId else {
            completion(false)
            return
        }
        
        let reportId = generateReportId(imageUrl: imageUrl, reporterUserId: currentUserId)
        
        database.collection("PhotoReports")
            .document(reportId)
            .getDocument { documentSnapshot, error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "getReportStatus() error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                let exists = documentSnapshot?.exists ?? false
                AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "getReportStatus() report exists: \(exists)")
                completion(exists)
            }
    }
    
    // MARK: - Private Methods (Android Parity)
    
    /// Submits photo report to Firebase - Android parity
    private func submitPhotoReport(
        imageUrl: String,
        reportedUserId: String,
        reporterUserId: String,
        reason: String,
        completion: @escaping (Bool) -> Void
    ) {
        AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "submitPhotoReport() submitting report to Firebase")
        
        let reportId = generateReportId(imageUrl: imageUrl, reporterUserId: reporterUserId)
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        
        let reportData: [String: Any] = [
            "reportId": reportId,
            "imageUrl": imageUrl,
            "reportedUserId": reportedUserId,
            "reporterUserId": reporterUserId,
            "reason": reason,
            "timestamp": timestamp,
            "status": "pending",
            "deviceId": sessionManager.deviceId ?? "",
            "reporterName": sessionManager.userName ?? "",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        ]
        
        database.collection("PhotoReports")
            .document(reportId)
            .setData(reportData) { [weak self] error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "submitPhotoReport() error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "submitPhotoReport() report submitted successfully")
                
                // Update user's report statistics
                self?.updateReportStatistics(reporterUserId: reporterUserId)
                
                completion(true)
            }
    }
    
    /// Updates user's report statistics - Android parity
    private func updateReportStatistics(reporterUserId: String) {
        AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "updateReportStatistics() updating stats for user: \(reporterUserId)")
        
        guard let deviceId = sessionManager.deviceId else {
            AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "updateReportStatistics() no device ID available")
            return
        }
        
        let statsData: [String: Any] = [
            "photo_reports_made": FieldValue.increment(Int64(1)),
            "last_report_time": FieldValue.serverTimestamp()
        ]
        
        database.collection("UserDevData")
            .document(deviceId)
            .setData(statsData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "updateReportStatistics() error: \(error.localizedDescription)")
                } else {
                    AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "updateReportStatistics() statistics updated successfully")
                }
            }
    }
    
    /// Generates unique report ID - Android parity
    private func generateReportId(imageUrl: String, reporterUserId: String) -> String {
        let combinedString = "\(imageUrl)_\(reporterUserId)"
        let hash = combinedString.hash
        let reportId = "photo_report_\(abs(hash))"
        
        AppLogger.log(tag: "LOG-APP: ReportPhotoService", message: "generateReportId() generated ID: \(reportId)")
        return reportId
    }
}

// MARK: - ReportReason Enum (Android Parity)
enum PhotoReportReason: String, CaseIterable {
    case inappropriateContent = "Inappropriate content"
    case nudity = "Nudity or sexual content"
    case violence = "Violence or harmful content"
    case spam = "Spam or misleading"
    case harassment = "Harassment or bullying"
    case copyright = "Copyright infringement"
    case other = "Other"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Global Helper Functions (Android Parity)

/// Global photo report function - Android parity
func reportUserPhoto(imageUrl: String, userId: String, reason: String = "Inappropriate content", completion: @escaping (Bool) -> Void = { _ in }) {
    ReportPhotoService.shared.reportPhoto(imageUrl: imageUrl, otherUserId: userId, reason: reason, completion: completion)
}

/// Global multiple photos report function - Android parity
func reportUserPhotos(imageUrls: [String], userId: String, reason: String = "Inappropriate content", completion: @escaping (Bool) -> Void = { _ in }) {
    ReportPhotoService.shared.reportMultiplePhotos(imageUrls: imageUrls, otherUserId: userId, reason: reason, completion: completion)
} 