//
//  LocationManager.swift
//  ChatHub
//
//  Created by Claude on 2024-12-19.
//  Copyright © 2024 ChatHub. All rights reserved.
//

import Foundation
import FirebaseFirestore

/// LocationManager - Enhanced IP-based geolocation service
/// Builds upon existing IPAddressService to implement comprehensive location tracking
/// Implements User Profile Categories document Location category specification
class LocationManager {
    
    // MARK: - Singleton
    static let shared = LocationManager()
    private init() {}
    
    // MARK: - Properties
    private let defaults = UserDefaults.standard
    private let existingIPService = IPAddressService()
    
    // MARK: - Location Data Model
    struct LocationData {
        let ipAddress: String
        let country: String
        let city: String
        let state: String
        let timezone: String
        let currentTimeDisplay: String
        let timestamp: TimeInterval
        
        // Convert to Firebase document format
        func toFirebaseData() -> [String: Any] {
            return [
                "ip_address": ipAddress,
                "country": country,
                "city": city,
                "state": state,
                "timezone": timezone,
                "current_time_display": currentTimeDisplay,
                "updated_at": timestamp
            ]
        }
    }
    
    // MARK: - Public API
    
    /// Capture and store location data during signup (original location)
    func captureOriginalLocation(completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: LocationManager", message: "captureOriginalLocation() - Starting original location capture")
        
        captureLocationData { [weak self] locationData in
            guard let self = self, let locationData = locationData else {
                AppLogger.log(tag: "LOG-APP: LocationManager", message: "captureOriginalLocation() - Failed to capture location data")
                completion(false)
                return
            }
            
            self.saveOriginalLocation(locationData, completion: completion)
        }
    }
    
    /// Update current location during app sessions
    func updateCurrentLocation(completion: @escaping (Bool) -> Void) {
        AppLogger.log(tag: "LOG-APP: LocationManager", message: "updateCurrentLocation() - Starting current location update")
        
        captureLocationData { [weak self] locationData in
            guard let self = self, let locationData = locationData else {
                AppLogger.log(tag: "LOG-APP: LocationManager", message: "updateCurrentLocation() - Failed to capture location data")
                completion(false)
                return
            }
            
            self.saveCurrentLocation(locationData, completion: completion)
        }
    }
    
    /// Get stored location data for user
    func getLocationData(for userId: String, completion: @escaping ([String: Any]?) -> Void) {
        let locationRef = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("location")
        
        locationRef.getDocument { document, error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: LocationManager", message: "getLocationData() - Firebase error: \(error)")
                completion(nil)
                return
            }
            
            completion(document?.data())
        }
    }
    
    // MARK: - Private Implementation
    
    /// Capture comprehensive location data using enhanced IP geolocation
    private func captureLocationData(completion: @escaping (LocationData?) -> Void) {
        // First get IP address
        getIPAddress { [weak self] ipAddress in
            guard let self = self, let ipAddress = ipAddress else {
                completion(nil)
                return
            }
            
            // Then get detailed geolocation
            self.getEnhancedGeolocation(for: ipAddress, completion: completion)
        }
    }
    
    /// Get IP address using multiple fallback services
    private func getIPAddress(completion: @escaping (String?) -> Void) {
        let ipServices = [
            "https://api.ipify.org",
            "https://ipv4.icanhazip.com",
            "https://ipinfo.io/ip"
        ]
        
        tryIPService(services: ipServices, index: 0, completion: completion)
    }
    
    /// Try IP services with fallback
    private func tryIPService(services: [String], index: Int, completion: @escaping (String?) -> Void) {
        guard index < services.count else {
            AppLogger.log(tag: "LOG-APP: LocationManager", message: "All IP services failed")
            completion(nil)
            return
        }
        
        guard let url = URL(string: services[index]) else {
            tryIPService(services: services, index: index + 1, completion: completion)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, 
               let ipAddress = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !ipAddress.isEmpty {
                AppLogger.log(tag: "LOG-APP: LocationManager", message: "IP service success: \(services[index]) -> \(ipAddress)")
                completion(ipAddress)
            } else {
                AppLogger.log(tag: "LOG-APP: LocationManager", message: "IP service failed: \(services[index])")
                self.tryIPService(services: services, index: index + 1, completion: completion)
            }
        }.resume()
    }
    
    /// Get enhanced geolocation data with timezone
    private func getEnhancedGeolocation(for ipAddress: String, completion: @escaping (LocationData?) -> Void) {
        // Use multiple geolocation services for redundancy
        let geoServices = [
            "https://ipapi.co/\(ipAddress)/json/",
            "https://www.geoplugin.net/json.gp?ip=\(ipAddress)",
            "https://ipwhois.app/json/\(ipAddress)"
        ]
        
        tryGeolocationService(services: geoServices, ipAddress: ipAddress, index: 0, completion: completion)
    }
    
    /// Try geolocation services with fallback
    private func tryGeolocationService(services: [String], ipAddress: String, index: Int, completion: @escaping (LocationData?) -> Void) {
        guard index < services.count else {
            AppLogger.log(tag: "LOG-APP: LocationManager", message: "All geolocation services failed")
            completion(nil)
            return
        }
        
        guard let url = URL(string: services[index]) else {
            tryGeolocationService(services: services, ipAddress: ipAddress, index: index + 1, completion: completion)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let locationData = self.parseGeolocationResponse(data: data, ipAddress: ipAddress, serviceIndex: index) {
                    AppLogger.log(tag: "LOG-APP: LocationManager", message: "Geolocation service success: \(services[index])")
                    completion(locationData)
                    return
                }
            }
            
            AppLogger.log(tag: "LOG-APP: LocationManager", message: "Geolocation service failed: \(services[index])")
            self.tryGeolocationService(services: services, ipAddress: ipAddress, index: index + 1, completion: completion)
        }.resume()
    }
    
    /// Parse geolocation response from different services
    private func parseGeolocationResponse(data: Data, ipAddress: String, serviceIndex: Int) -> LocationData? {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            var country = ""
            var city = ""
            var state = ""
            var timezone = ""
            
            // Parse based on service format
            switch serviceIndex {
            case 0: // ipapi.co
                country = json["country_name"] as? String ?? ""
                city = json["city"] as? String ?? ""
                state = json["region"] as? String ?? ""
                timezone = json["timezone"] as? String ?? ""
                
            case 1: // geoplugin.net (existing format)
                country = json["geoplugin_countryName"] as? String ?? ""
                city = json["geoplugin_city"] as? String ?? ""
                state = json["geoplugin_region"] as? String ?? ""
                timezone = json["geoplugin_timezone"] as? String ?? ""
                
            case 2: // ipwhois.app
                country = json["country"] as? String ?? ""
                city = json["city"] as? String ?? ""
                state = json["region"] as? String ?? ""
                timezone = json["timezone"] as? String ?? ""
                
            default:
                return nil
            }
            
            // Generate current time display
            let currentTimeDisplay = generateCurrentTimeDisplay(timezone: timezone)
            
            return LocationData(
                ipAddress: ipAddress,
                country: country,
                city: city,
                state: state,
                timezone: timezone,
                currentTimeDisplay: currentTimeDisplay,
                timestamp: Date().timeIntervalSince1970
            )
            
        } catch {
            AppLogger.log(tag: "LOG-APP: LocationManager", message: "JSON parsing error: \(error)")
            return nil
        }
    }
    
    /// Generate human-readable current time in user's timezone
    private func generateCurrentTimeDisplay(timezone: String) -> String {
        guard !timezone.isEmpty,
              let timeZone = TimeZone(identifier: timezone) else {
            return "Time unavailable"
        }
        
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        let currentTime = formatter.string(from: Date())
        return "Local time: \(currentTime)"
    }
    
    /// Save original location data (signup time)
    private func saveOriginalLocation(_ locationData: LocationData, completion: @escaping (Bool) -> Void) {
        guard let userId = UserSessionManager.shared.userId else {
            AppLogger.log(tag: "LOG-APP: LocationManager", message: "saveOriginalLocation() - No user ID available")
            completion(false)
            return
        }
        
        let locationRef = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("location")
        
        var data = locationData.toFirebaseData()
        data["original_country"] = locationData.country
        data["original_city"] = locationData.city
        data["original_state"] = locationData.state
        data["original_ip"] = locationData.ipAddress
        data["signup_timezone"] = locationData.timezone
        
        // Also set current location fields for first time
        data["current_country"] = locationData.country
        data["current_city"] = locationData.city
        data["current_state"] = locationData.state
        data["current_ip"] = locationData.ipAddress
        
        locationRef.setData(data, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: LocationManager", message: "saveOriginalLocation() - Firebase error: \(error)")
                completion(false)
            } else {
                AppLogger.log(tag: "LOG-APP: LocationManager", message: "saveOriginalLocation() - Success")
                completion(true)
            }
        }
        
        // Also update legacy fields for backward compatibility
        self.updateLegacyLocationFields(locationData)
    }
    
    /// Save current location data (session updates)
    private func saveCurrentLocation(_ locationData: LocationData, completion: @escaping (Bool) -> Void) {
        guard let userId = UserSessionManager.shared.userId else {
            AppLogger.log(tag: "LOG-APP: LocationManager", message: "saveCurrentLocation() - No user ID available")
            completion(false)
            return
        }
        
        let locationRef = Firestore.firestore()
            .collection("Users")
            .document(userId)
            .collection("Profile")
            .document("location")
        
        let currentData: [String: Any] = [
            "current_country": locationData.country,
            "current_city": locationData.city,
            "current_state": locationData.state,
            "current_ip": locationData.ipAddress,
            "timezone": locationData.timezone,
            "current_time_display": locationData.currentTimeDisplay,
            "last_location_update": locationData.timestamp
        ]
        
        locationRef.setData(currentData, merge: true) { error in
            if let error = error {
                AppLogger.log(tag: "LOG-APP: LocationManager", message: "saveCurrentLocation() - Firebase error: \(error)")
                completion(false)
            } else {
                AppLogger.log(tag: "LOG-APP: LocationManager", message: "saveCurrentLocation() - Success")
                completion(true)
            }
        }
        
        // Also update legacy fields for backward compatibility
        self.updateLegacyLocationFields(locationData)
    }
    
    /// Update legacy location fields for backward compatibility
    private func updateLegacyLocationFields(_ locationData: LocationData) {
        // Update SessionManager for immediate access
        SessionManager.shared.userRetrievedIp = locationData.ipAddress
        SessionManager.shared.userRetrievedCity = locationData.city
        SessionManager.shared.userRetrievedState = locationData.state
        SessionManager.shared.userRetrievedCountry = locationData.country
        
        // Update root document fields for compatibility
        guard let userId = UserSessionManager.shared.userId else { return }
        
        let legacyData: [String: Any] = [
            "userRetrievedIp": locationData.ipAddress,
            "userRetrievedCity": locationData.city,
            "userRetrievedState": locationData.state,
            "userRetrievedCountry": locationData.country,
            "city": locationData.city
        ]
        
        Firestore.firestore()
            .collection("Users")
            .document(userId)
            .setData(legacyData, merge: true) { error in
                if let error = error {
                    AppLogger.log(tag: "LOG-APP: LocationManager", message: "updateLegacyLocationFields() - Error: \(error)")
                } else {
                    AppLogger.log(tag: "LOG-APP: LocationManager", message: "updateLegacyLocationFields() - Success")
                }
            }
    }
    
    // MARK: - Public Convenience Methods
    
    /// Get display-friendly location string
    func getLocationDisplayString(for userId: String, completion: @escaping (String?) -> Void) {
        getLocationData(for: userId) { data in
            guard let data = data else {
                completion(nil)
                return
            }
            
            let city = data["current_city"] as? String ?? ""
            let country = data["current_country"] as? String ?? ""
            
            if !city.isEmpty && !country.isEmpty {
                completion("\(city), \(country)")
            } else if !country.isEmpty {
                completion(country)
            } else {
                completion(nil)
            }
        }
    }
    
    /// Get current time display for user
    func getCurrentTimeDisplay(for userId: String, completion: @escaping (String?) -> Void) {
        getLocationData(for: userId) { data in
            completion(data?["current_time_display"] as? String)
        }
    }
    
    /// Check if user is in same country as another user
    func areUsersInSameCountry(user1: String, user2: String, completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var country1: String?
        var country2: String?
        
        group.enter()
        getLocationData(for: user1) { data in
            country1 = data?["current_country"] as? String
            group.leave()
        }
        
        group.enter()
        getLocationData(for: user2) { data in
            country2 = data?["current_country"] as? String
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(country1 == country2 && country1 != nil)
        }
    }
}
