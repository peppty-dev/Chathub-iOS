//
//  UserFilterService.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import FirebaseFirestore

/// UserFilterService - Handles user filtering logic and Firebase query building
/// Extracted from OnlineUsersViewModel for better separation of concerns
class UserFilterService {
    static let shared = UserFilterService()
    
    private init() {}
    
    // MARK: - Local Filtering Methods
    
    /// Apply filters to local user array (similar to Android age filtering logic)
    func applyLocalFilters(to users: [Users], filter: OnlineUserFilter) -> [Users] {
        AppLogger.log(tag: "LOG-APP: UserFilterService", message: "applyLocalFilters() - Starting filter with \(users.count) users")
        AppLogger.log(tag: "LOG-APP: UserFilterService", message: "applyLocalFilters() - Filter: male=\(filter.male), female=\(filter.female), country='\(filter.country)', language='\(filter.language)', nearby='\(filter.nearby)'")
        
        let filteredUsers = users.filter { user in
            return matchesGenderFilter(user, filter) &&
                   matchesCountryFilter(user, filter) &&
                   matchesLanguageFilter(user, filter) &&
                   matchesAgeFilter(user, filter) &&
                   matchesNearbyFilter(user, filter)
        }
        
        AppLogger.log(tag: "LOG-APP: UserFilterService", message: "applyLocalFilters() - Filtered \(users.count) users down to \(filteredUsers.count) users")
        return filteredUsers
    }
    
    // MARK: - Individual Filter Methods
    
    /// Check if user matches gender filter
    private func matchesGenderFilter(_ user: Users, _ filter: OnlineUserFilter) -> Bool {
        // Both or neither selected means no gender filter
        if (filter.male && filter.female) || (!filter.male && !filter.female) {
            return true
        }
        
        if filter.male && !filter.female {
            let matches = user.user_gender.lowercased() == "male"
            if !matches {
                AppLogger.log(tag: "LOG-APP: UserFilterService", message: "applyLocalFilters() - Filtered out '\(user.user_name)': male filter active but user is '\(user.user_gender)'")
            }
            return matches
        }
        
        if filter.female && !filter.male {
            let matches = user.user_gender.lowercased() == "female"
            if !matches {
                AppLogger.log(tag: "LOG-APP: UserFilterService", message: "applyLocalFilters() - Filtered out '\(user.user_name)': female filter active but user is '\(user.user_gender)'")
            }
            return matches
        }
        
        return true
    }
    
    /// Check if user matches country filter
    private func matchesCountryFilter(_ user: Users, _ filter: OnlineUserFilter) -> Bool {
        if filter.country.isEmpty {
            return true
        }
        
        let matches = user.user_country == filter.country
        if !matches {
            AppLogger.log(tag: "LOG-APP: UserFilterService", message: "applyLocalFilters() - Filtered out '\(user.user_name)': country filter '\(filter.country)' but user is from '\(user.user_country)'")
        }
        return matches
    }
    
    /// Check if user matches language filter
    private func matchesLanguageFilter(_ user: Users, _ filter: OnlineUserFilter) -> Bool {
        if filter.language.isEmpty {
            return true
        }
        
        // Note: Language field might not be available in current Users structure
        // This is a placeholder for when language field is added
        // let matches = user.user_language == filter.language
        // For now, return true (no filtering by language)
        return true
    }
    
    /// Check if user matches age filter
    private func matchesAgeFilter(_ user: Users, _ filter: OnlineUserFilter) -> Bool {
        // Age filtering logic placeholder
        // Note: Age field might not be available in current Users structure
        // This would need to be implemented when age field is added to Users model
        
        if !filter.minAge.isEmpty, let minAge = Int(filter.minAge) {
            // Placeholder: would need user.user_age field
            // if let userAge = Int(user.user_age), userAge < minAge {
            //     return false
            // }
        }
        
        if !filter.maxAge.isEmpty, let maxAge = Int(filter.maxAge) {
            // Placeholder: would need user.user_age field
            // if let userAge = Int(user.user_age), userAge > maxAge {
            //     return false
            // }
        }
        
        return true
    }
    
    /// Check if user matches nearby filter
    private func matchesNearbyFilter(_ user: Users, _ filter: OnlineUserFilter) -> Bool {
        if filter.nearby.isEmpty {
            return true
        }
        
        let matches = user.user_city == filter.nearby
        if !matches {
            AppLogger.log(tag: "LOG-APP: UserFilterService", message: "applyLocalFilters() - Filtered out '\(user.user_name)': nearby filter '\(filter.nearby)' but user city is '\(user.user_city)'")
        }
        return matches
    }
    
    // MARK: - Firebase Query Building Methods
    
    /// Build Firebase query with filters applied
    func buildFirebaseQuery(with filter: OnlineUserFilter, limit: Int = 10) -> Query {
        AppLogger.log(tag: "LOG-APP: UserFilterService", message: "buildFirebaseQuery() - Building query with limit \(limit)")
        
        var query: Query = Firestore.firestore().collection("Users")
            .order(by: "last_time_seen", descending: true)
            .limit(to: limit)
        
        // Apply gender filters
        query = applyGenderFilter(to: query, filter: filter)
        
        // Apply country filter
        query = applyCountryFilter(to: query, filter: filter)
        
        // Apply language filter
        query = applyLanguageFilter(to: query, filter: filter)
        
        // Note: Age and nearby filters would be applied here when available
        
        AppLogger.log(tag: "LOG-APP: UserFilterService", message: "buildFirebaseQuery() - Query built successfully")
        return query
    }
    
    /// Apply gender filter to Firebase query
    private func applyGenderFilter(to query: Query, filter: OnlineUserFilter) -> Query {
        var modifiedQuery = query
        
        // Normalize gender filter logic
        var maleFilter = filter.male
        var femaleFilter = filter.female
        
        // If both selected, don't apply gender filter
        if filter.male && filter.female {
            maleFilter = false
            femaleFilter = false
        }
        
        if maleFilter {
            modifiedQuery = modifiedQuery.whereField("User_gender", isEqualTo: "Male")
            AppLogger.log(tag: "LOG-APP: UserFilterService", message: "buildFirebaseQuery() - Added male filter")
        } else if femaleFilter {
            modifiedQuery = modifiedQuery.whereField("User_gender", isEqualTo: "Female")
            AppLogger.log(tag: "LOG-APP: UserFilterService", message: "buildFirebaseQuery() - Added female filter")
        }
        
        return modifiedQuery
    }
    
    /// Apply country filter to Firebase query
    private func applyCountryFilter(to query: Query, filter: OnlineUserFilter) -> Query {
        if !filter.country.isEmpty {
            AppLogger.log(tag: "LOG-APP: UserFilterService", message: "buildFirebaseQuery() - Added country filter: \(filter.country)")
            return query.whereField("User_country", isEqualTo: filter.country)
        }
        return query
    }
    
    /// Apply language filter to Firebase query
    private func applyLanguageFilter(to query: Query, filter: OnlineUserFilter) -> Query {
        if !filter.language.isEmpty {
            AppLogger.log(tag: "LOG-APP: UserFilterService", message: "buildFirebaseQuery() - Added language filter: \(filter.language)")
            return query.whereField("user_language", isEqualTo: filter.language)
        }
        return query
    }
    
    // MARK: - Filter Validation Methods
    
    /// Validate filter parameters
    func validateFilter(_ filter: OnlineUserFilter) -> FilterValidationResult {
        var issues: [String] = []
        var warnings: [String] = []
        
        // Check age range validity
        if !filter.minAge.isEmpty && !filter.maxAge.isEmpty {
            if let minAge = Int(filter.minAge), let maxAge = Int(filter.maxAge) {
                if minAge > maxAge {
                    issues.append("Minimum age cannot be greater than maximum age")
                }
                if minAge < 18 {
                    warnings.append("Minimum age below 18 may not return results")
                }
                if maxAge > 100 {
                    warnings.append("Maximum age above 100 may not return results")
                }
            } else {
                issues.append("Age values must be valid numbers")
            }
        }
        
        // Check for conflicting filters
        if filter.male && filter.female {
            warnings.append("Both male and female selected - gender filter will be ignored")
        }
        
        // Check if any filters are applied
        let hasFilters = filter.male || filter.female || 
                        !filter.country.isEmpty || 
                        !filter.language.isEmpty || 
                        !filter.minAge.isEmpty || 
                        !filter.maxAge.isEmpty || 
                        !filter.nearby.isEmpty
        
        if !hasFilters {
            warnings.append("No filters applied - will return all users")
        }
        
        return FilterValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
    
    /// Get filter summary for logging
    func getFilterSummary(_ filter: OnlineUserFilter) -> String {
        var components: [String] = []
        
        if filter.male && !filter.female {
            components.append("Male")
        } else if filter.female && !filter.male {
            components.append("Female")
        } else if filter.male && filter.female {
            components.append("Any Gender")
        }
        
        if !filter.country.isEmpty {
            components.append("Country: \(filter.country)")
        }
        
        if !filter.language.isEmpty {
            components.append("Language: \(filter.language)")
        }
        
        if !filter.minAge.isEmpty || !filter.maxAge.isEmpty {
            let ageRange = "\(filter.minAge.isEmpty ? "?" : filter.minAge)-\(filter.maxAge.isEmpty ? "?" : filter.maxAge)"
            components.append("Age: \(ageRange)")
        }
        
        if !filter.nearby.isEmpty {
            components.append("Near: \(filter.nearby)")
        }
        
        return components.isEmpty ? "No filters" : components.joined(separator: ", ")
    }
    
    // MARK: - Performance Optimization Methods
    
    /// Check if filter requires Firebase query or can use local filtering
    func shouldUseFirebaseQuery(for filter: OnlineUserFilter) -> Bool {
        // Use Firebase query if we have indexed fields (gender, country, language)
        return filter.male || filter.female || 
               !filter.country.isEmpty || 
               !filter.language.isEmpty
    }
    
    /// Get estimated result count for filter
    func getEstimatedResultCount(for filter: OnlineUserFilter, totalUsers: Int) -> Int {
        var estimate = totalUsers
        
        // Rough estimates based on typical demographics
        if filter.male && !filter.female {
            estimate = Int(Double(estimate) * 0.6) // Assume 60% male users
        } else if filter.female && !filter.male {
            estimate = Int(Double(estimate) * 0.4) // Assume 40% female users
        }
        
        if !filter.country.isEmpty {
            estimate = Int(Double(estimate) * 0.1) // Assume 10% from specific country
        }
        
        if !filter.language.isEmpty {
            estimate = Int(Double(estimate) * 0.2) // Assume 20% for specific language
        }
        
        if !filter.nearby.isEmpty {
            estimate = Int(Double(estimate) * 0.05) // Assume 5% from specific city
        }
        
        return max(1, estimate) // Ensure at least 1
    }
}

// MARK: - Supporting Types

struct FilterValidationResult {
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