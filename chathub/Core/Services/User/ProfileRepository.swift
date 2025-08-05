//
//  ProfileRepository.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import SwiftUI

/// ProfileRepository - Handles all profile database operations
/// Provides a clean service layer for profile data access
class ProfileRepository: @unchecked Sendable {
    static let shared = ProfileRepository()
    
    private let profileDB = ProfileDB.shared
    private let backgroundQueue = DispatchQueue(label: "ProfileRepository.background", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Profile Management Methods
    
    /// Save profile to local database
    func saveProfile(_ profile: UserProfile) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let workItem = DispatchWorkItem {
                do {
                    AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "saveProfile() - Deleting existing profile for user: \(profile.id)")
                    
                    // Delete existing profile first
                    ProfileDB.shared.delete(UserId: profile.id)
                    
                    AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "saveProfile() - Inserting new profile for user: \(profile.id)")
                    
                    // Insert new profile data
                    ProfileDB.shared.insert(
                        UserId: profile.id as NSString,
                        Age: profile.age as NSString,
                        Country: profile.country as NSString,
                        Language: profile.language as NSString,
                        Gender: profile.gender as NSString,
                        men: (profile.likeMen ?? "") as NSString,
                        women: (profile.likeWoman ?? "") as NSString,
                        single: (profile.single ?? "") as NSString,
                        married: (profile.married ?? "") as NSString,
                        children: (profile.children ?? "") as NSString,
                        gym: (profile.gym ?? "") as NSString,
                        smoke: (profile.smokes ?? "") as NSString,
                        drink: (profile.drinks ?? "") as NSString,
                        games: (profile.games ?? "") as NSString,
                        decenttalk: (profile.decentChat ?? "") as NSString,
                        pets: (profile.pets ?? "") as NSString,
                        travel: (profile.travel ?? "") as NSString,
                        music: (profile.music ?? "") as NSString,
                        movies: (profile.movies ?? "") as NSString,
                        naughty: (profile.naughty ?? "") as NSString,
                        Foodie: (profile.foodie ?? "") as NSString,
                        dates: (profile.dates ?? "") as NSString,
                        fashion: (profile.fashion ?? "") as NSString,
                        broken: (profile.broken ?? "") as NSString,
                        depressed: (profile.depressed ?? "") as NSString,
                        lonely: (profile.lonely ?? "") as NSString,
                        cheated: (profile.cheated ?? "") as NSString,
                        insomnia: (profile.insomnia ?? "") as NSString,
                        voice: (profile.voiceAllowed ?? "") as NSString,
                        video: (profile.videoAllowed ?? "") as NSString,
                        pics: (profile.picsAllowed ?? "") as NSString,
                        goodexperience: (profile.goodExperience ?? "") as NSString,
                        badexperience: (profile.badExperience ?? "") as NSString,
                        male_accounts: (profile.maleAccounts ?? "") as NSString,
                        female_accounts: (profile.femaleAccounts ?? "") as NSString,
                        male_chats: (profile.maleChats ?? "") as NSString,
                        female_chats: (profile.femaleChats ?? "") as NSString,
                        reports: (profile.reports ?? "") as NSString,
                        blocks: (profile.blocks ?? "") as NSString,
                        voicecalls: (profile.voiceCalls ?? "") as NSString,
                        videocalls: (profile.videoCalls ?? "") as NSString,
                        Time: Date(),
                        Image: profile.profilePhoto as NSString,
                        Named: profile.username as NSString,
                        Height: (profile.height ?? "") as NSString,
                        Occupation: (profile.occupation ?? "") as NSString,
                        Instagram: (profile.insta ?? "") as NSString,
                        Snapchat: (profile.snap ?? "") as NSString,
                        Zodic: (profile.zodiac ?? "") as NSString,
                        Hobbies: (profile.hobbies ?? "") as NSString,
                        EmailVerified: (profile.emailVerified ?? "") as NSString,
                        CreatedTime: (profile.userRegisteredTime ?? "") as NSString,
                        Platform: profile.platform as NSString,
                        Premium: (profile.subscriptionTier ?? "") as NSString,
                        city: (profile.city ?? "") as NSString
                    )
                    
                    AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "saveProfile() - Profile saved successfully")
                    continuation.resume()
                    
                } catch {
                    AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "saveProfile() - Error: \(error.localizedDescription)")
                    continuation.resume(throwing: ProfileRepositoryError.saveFailed(error))
                }
            }
            backgroundQueue.async(execute: workItem)
        }
    }
    
    /// Get profile by user ID
    func getProfile(userId: String) async -> UserProfile? {
        return await withCheckedContinuation { continuation in
            let workItem = DispatchWorkItem {
                AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "getProfile() - Fetching profile for user: \(userId)")
                
                // Note: ProfileDB.query() requires a UserId parameter
                // This would need to be implemented based on the actual ProfileDB interface
                // For now, returning nil as a placeholder
                
                AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "getProfile() - ProfileDB query method needs implementation")
                continuation.resume(returning: nil)
            }
            backgroundQueue.async(execute: workItem)
        }
    }
    
    /// Delete profile
    func deleteProfile(userId: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let workItem = DispatchWorkItem {
                do {
                    AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "deleteProfile() - Deleting profile for user: \(userId)")
                    
                    ProfileDB.shared.delete(UserId: userId)
                    
                    AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "deleteProfile() - Profile deleted successfully")
                    continuation.resume()
                    
                } catch {
                    AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "deleteProfile() - Error: \(error.localizedDescription)")
                    continuation.resume(throwing: ProfileRepositoryError.deleteFailed(error))
                }
            }
            backgroundQueue.async(execute: workItem)
        }
    }
    
    /// Check if profile exists
    func profileExists(userId: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let workItem = DispatchWorkItem {
                AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "profileExists() - Checking profile for user: \(userId)")
                
                // This would need to be implemented based on actual ProfileDB interface
                // For now, returning false as placeholder
                
                AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "profileExists() - Profile check needs implementation")
                continuation.resume(returning: false)
            }
            backgroundQueue.async(execute: workItem)
        }
    }
    
    // MARK: - Bulk Operations
    
    /// Get all profiles (if supported by database)
    func getAllProfiles() async -> [UserProfile] {
        return await withCheckedContinuation { continuation in
            let workItem = DispatchWorkItem {
                AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "getAllProfiles() - Fetching all profiles")
                
                // Note: ProfileDB.query() requires a UserId parameter, so we can't get all profiles this way
                // This would need database schema changes to support
                AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "getAllProfiles() - ProfileDB doesn't support getting all profiles")
                continuation.resume(returning: [])
            }
            backgroundQueue.async(execute: workItem)
        }
    }
    
    /// Clear all profiles (for cleanup/reset)
    func clearAllProfiles() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let workItem = DispatchWorkItem {
                do {
                    AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "clearAllProfiles() - Clearing all profiles")
                    
                    // This would need to be implemented based on database capabilities
                    // For now, just log the attempt
                    
                    AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "clearAllProfiles() - Clear all operation needs implementation")
                    continuation.resume()
                    
                } catch {
                    AppLogger.log(tag: "LOG-APP: ProfileRepository", message: "clearAllProfiles() - Error: \(error.localizedDescription)")
                    continuation.resume(throwing: ProfileRepositoryError.clearFailed(error))
                }
            }
            backgroundQueue.async(execute: workItem)
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validate profile data before saving
    func validateProfile(_ profile: UserProfile) -> ProfileValidationResult {
        var issues: [String] = []
        var warnings: [String] = []
        
        // Required fields validation
        if profile.id.isEmpty {
            issues.append("User ID is required")
        }
        
        if profile.username.isEmpty {
            issues.append("Username is required")
        }
        
        if profile.country.isEmpty {
            issues.append("Country is required")
        }
        
        if profile.language.isEmpty {
            issues.append("Language is required")
        }
        
        if profile.gender.isEmpty {
            issues.append("Gender is required")
        }
        
        // Age validation
        if !profile.age.isEmpty {
            if let ageInt = Int(profile.age) {
                if ageInt < 18 {
                    issues.append("Age must be 18 or older")
                }
                if ageInt > 120 {
                    warnings.append("Age seems unusually high")
                }
            } else {
                issues.append("Age must be a valid number")
            }
        }
        
        // Username validation
        if profile.username.count < 2 {
            issues.append("Username must be at least 2 characters")
        }
        
        if profile.username.count > 50 {
            issues.append("Username must be less than 50 characters")
        }
        
        return ProfileValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
    
    /// Get profile completeness score
    func getProfileCompleteness(_ profile: UserProfile) -> ProfileCompletenessScore {
        var totalFields = 0
        var completedFields = 0
        
        // Required fields
        let requiredFields: [(String, String?)] = [
            ("Username", profile.username.isEmpty ? nil : profile.username),
            ("Country", profile.country.isEmpty ? nil : profile.country),
            ("Language", profile.language.isEmpty ? nil : profile.language),
            ("Gender", profile.gender.isEmpty ? nil : profile.gender)
        ]
        
        for (_, value) in requiredFields {
            totalFields += 1
            if value != nil {
                completedFields += 1
            }
        }
        
        // Optional fields
        let optionalFields: [(String, String?)] = [
            ("Age", profile.age),
            ("City", profile.city),
            ("Height", profile.height),
            ("Occupation", profile.occupation),
            ("Hobbies", profile.hobbies),
            ("Zodiac", profile.zodiac),
            ("Snapchat", profile.snap),
            ("Instagram", profile.insta)
        ]
        
        for (_, value) in optionalFields {
            totalFields += 1
            if let val = value, !val.isEmpty {
                completedFields += 1
            }
        }
        
        let percentage = totalFields > 0 ? Int((Double(completedFields) / Double(totalFields)) * 100) : 0
        
        return ProfileCompletenessScore(
            completedFields: completedFields,
            totalFields: totalFields,
            percentage: percentage
        )
    }
}

// MARK: - Supporting Types

enum ProfileRepositoryError: Error, LocalizedError {
    case serviceUnavailable
    case saveFailed(Error)
    case deleteFailed(Error)
    case clearFailed(Error)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Profile service is unavailable"
        case .saveFailed(let error):
            return "Failed to save profile: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete profile: \(error.localizedDescription)"
        case .clearFailed(let error):
            return "Failed to clear profiles: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid profile data"
        }
    }
}

struct ProfileValidationResult {
    let isValid: Bool
    let issues: [String]
    let warnings: [String]
    
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
    
    var combinedMessage: String {
        var messages: [String] = []
        if !issues.isEmpty {
            messages.append("Issues: " + issues.joined(separator: ", "))
        }
        if !warnings.isEmpty {
            messages.append("Warnings: " + warnings.joined(separator: ", "))
        }
        return messages.joined(separator: "; ")
    }
}

struct ProfileCompletenessScore {
    let completedFields: Int
    let totalFields: Int
    let percentage: Int
    
    var isComplete: Bool {
        return percentage == 100
    }
    
    var description: String {
        return "\(completedFields)/\(totalFields) fields completed (\(percentage)%)"
    }
} 