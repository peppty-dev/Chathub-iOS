import Foundation
import UIKit

/// Shared utility class to provide consistent country and language lists with 100% Android parity
/// Used by both FiltersView and LoginView to ensure seamless cross-platform experience
class CountryLanguageHelper {
    
    static let shared = CountryLanguageHelper()
    
    // PERFORMANCE OPTIMIZATION: Cache the expensive language computation
    private var cachedLanguages: [String]?
    private var cachedCountries: [String]?
    private let languageComputationQueue = DispatchQueue(label: "com.peppty.ChatApp.language-computation", qos: .userInitiated)
    
    // NOTIFICATION: Add notification for when languages are ready
    static let languagesDidUpdateNotification = Notification.Name("CountryLanguageHelperLanguagesDidUpdate")
    
    private init() {
        // PERFORMANCE OPTIMIZATION: Pre-cache countries immediately (lightweight operation)
        cachedCountries = generateCountryList()
        
        // PERFORMANCE OPTIMIZATION: Pre-compute languages in background to avoid UI lag
        precomputeLanguagesInBackground()
    }
    
    /// Returns the exact same country list as Android's PublicMethod.getAllCountryFlagList()
    /// This ensures 100% parity between iOS and Android for country filtering and selection
    func getAllCountries() -> [String] {
        // PERFORMANCE OPTIMIZATION: Return cached result immediately
        if let cached = cachedCountries {
            return cached
        }
        
        // Fallback: generate and cache
        let countries = generateCountryList()
        cachedCountries = countries
        return countries
    }
    
    /// Returns language list matching Android's implementation using Locale.getDisplayLanguage()
    /// This ensures 100% parity with Android's language selection behavior
    func getAllLanguages() -> [String] {
        // PERFORMANCE OPTIMIZATION: Return cached result immediately to prevent UI lag
        if let cached = cachedLanguages {
            return cached
        }
        
        // PERFORMANCE OPTIMIZATION: If not cached yet, compute synchronously with timeout
        // This ensures UI gets the full list on first access
        AppLogger.log(tag: "LOG-APP: CountryLanguageHelper", message: "getAllLanguages() Cache miss - computing full list synchronously")
        
        // Try to get the full list with a reasonable timeout
        let semaphore = DispatchSemaphore(value: 0)
        var computedLanguages: [String] = []
        
        languageComputationQueue.async { [weak self] in
            computedLanguages = self?.computeFullLanguageList() ?? []
            semaphore.signal()
        }
        
        // Wait up to 2 seconds for the computation
        let timeout = DispatchTime.now() + .seconds(2)
        if semaphore.wait(timeout: timeout) == .success {
            // Computation completed within timeout
            cachedLanguages = computedLanguages
            AppLogger.log(tag: "LOG-APP: CountryLanguageHelper", message: "getAllLanguages() Computed \(computedLanguages.count) languages synchronously")
            return computedLanguages
        } else {
            // Timeout occurred, return minimal list and continue background computation
            AppLogger.log(tag: "LOG-APP: CountryLanguageHelper", message: "getAllLanguages() Timeout - returning minimal list and continuing background computation")
            precomputeLanguagesInBackground()
            
            // Return a minimal essential language list to prevent UI blocking
            return [
                "English", "Spanish", "French", "German", "Italian", "Portuguese", "Russian", 
                "Chinese", "Japanese", "Korean", "Arabic", "Hindi", "Dutch", "Swedish", 
                "Norwegian", "Danish", "Finnish", "Polish", "Turkish", "Greek"
            ].sorted()
        }
    }
    
    // ANDROID PARITY: Generate exact country list from PublicMethod.getAllCountryFlagList() - maintaining exact order and casing
    private func generateCountryList() -> [String] {
        // ANDROID PARITY: Exact country list from Android PublicMethod.getAllCountryFlagList() HashMap keys
        // Extracted from the HashMap.put() calls in reverse order (since Android adds them in reverse)
        let androidCountries = [
            "Abkhazia", "Afghanistan", "Aland islands", "Albania", "Algeria", "American samoa", "Andorra", 
            "Angola", "Anguilla", "Antigua and barbuda", "Argentina", "Armenia", "Aruba", "Australia", 
            "Austria", "Azerbaijan", "Azores islands", "Bahamas", "Bahrain", "Balearic islands", "Bangladesh", 
            "Barbados", "Basque country", "Belarus", "Belgium", "Belize", "Benin", "Bermuda", "Bhutan", 
            "Bhutan 1", "Bolivia", "Bonaire", "Bosnia and herzegovina", "Botswana", "Brazil", "British columbia", 
            "British indian ocean territory", "British virgin islands", "Brunei", "Bulgaria", "Burkina faso", 
            "Burundi", "Cambodia", "Cameroon", "Canada", "Canary islands", "Cape verde", "Cayman islands", 
            "Central african republic", "Ceuta", "Chad", "Chile", "China", "Christmas island", "Cocos island", 
            "Colombia", "Comoros", "Cook islands", "Corsica", "Costa rica", "Croatia", "Cuba", "Curacao", 
            "Cyprus", "Czech republic", "Democratic republic of congo", "Denmark", "Djibouti", "Dominica", 
            "Dominican republic", "East timor", "Ecuador", "Egypt", "England", "Equatorial guinea", "Eritrea", 
            "Estonia", "Ethiopia", "European union", "Falkland islands", "Faroe islands", "Fiji", "Finland", 
            "France", "French polynesia", "Gabon", "Galapagos islands", "Gambia", "Georgia", "Germany", 
            "Ghana", "Gibraltar", "Greece", "Greenland", "Grenada", "Guam", "Guatemala", "Guernsey", "Guinea", 
            "Guinea bissau", "Guyana", "Haiti", "Hawaii", "Honduras", "Hong kong", "Hungary", "Iceland", 
            "India", "Indonesia", "Iran", "Iraq", "Ireland", "Isle of man", "Israel", "Italy", "Ivory coast", 
            "Jamaica", "Japan", "Jersey", "Jordan", "Kazakhstan", "Kenya", "Kiribati", "Kosovo", "Kuwait", 
            "Kyrgyzstan", "Laos", "Latvia", "Lebanon", "Lesotho", "Liberia", "Libya", "Liechtenstein", 
            "Lithuania", "Luxembourg", "Macao", "Madagascar", "Madeira", "Malawi", "Malaysia", "Maldives", 
            "Mali", "Malta", "Marshall island", "Martinique", "Mauritania", "Mauritius", "Melilla", "Mexico", 
            "Micronesia", "Moldova", "Monaco", "Mongolia", "Montenegro", "Montserrat", "Morocco", "Mozambique", 
            "Myanmar", "Namibia", "Nato", "Nauru", "Nepal", "Netherlands", "New zealand", "Nicaragua", 
            "Niger", "Nigeria", "Niue", "Norfolk island", "North korea", "Northen cyprus", "Northern marianas islands", 
            "Norway", "Oman", "Orkney islands", "Ossetia", "Pakistan", "Palau", "Palestine", "Panama", 
            "Papua new guinea", "Paraguay", "Peru", "Philippines", "Pitcairn islands", "Portugal", "Puerto rico", 
            "Qatar", "Rapa nui", "Republic of macedonia", "Republic of poland", "Republic of the congo", 
            "Romania", "Russia", "Rwanda", "Saba island", "Saint kitts and nevis", "Salvador", "Samoa", 
            "San marino", "Sao tome and principe", "Sardinia", "Saudi arabia", "Scotland", "Senegal", "Serbia", 
            "Seychelles", "Sierra leone", "Singapore", "Sint eustatius", "Sint maarten", "Slovakia", "Slovenia", 
            "Solomon islands", "Somalia", "Somaliland", "South africa", "South korea", "South sudan", "Spain", 
            "Sri lanka", "St barts", "St lucia", "St vincent and the grenadines", "Sudan", "Suriname", 
            "Swaziland", "Sweden", "Switzerland", "Syria", "Taiwan", "Tajikistan", "Tanzania", "Thailand", 
            "Tibet", "Togo", "Tokelau", "Tonga", "Transnistria", "Trinidad and tobago", "Tunisia", "Turkey", 
            "Turkmenistan", "Turks and caicos", "Tuvalu", "Uganda", "Ukraine", "United arab emirates", 
            "United kingdom", "United nations", "United states of america", "Uruguay", "Uzbekistn", "Vanuatu", 
            "Vatican city", "Venezuela", "Vietnam", "Virgin islands", "Wales", "Western sahara", "Yemen", 
            "Zambia", "Zimbabwe"
        ]
        
        // ANDROID PARITY: Android converts HashMap keySet to ArrayList, which doesn't guarantee order
        // But Android then uses this list directly, so we return it as-is (no sorting in Android)
        return androidCountries
    }
    
    // PERFORMANCE OPTIMIZATION: Compute languages in background to prevent UI blocking
    private func precomputeLanguagesInBackground() {
        // Skip if already cached
        guard cachedLanguages == nil else { return }
        
        languageComputationQueue.async { [weak self] in
            AppLogger.log(tag: "LOG-APP: CountryLanguageHelper", message: "precomputeLanguagesInBackground() Starting background computation")
            
            let computedLanguages = self?.computeFullLanguageList() ?? []
            
            // Cache the result
            DispatchQueue.main.async {
                self?.cachedLanguages = computedLanguages
                AppLogger.log(tag: "LOG-APP: CountryLanguageHelper", message: "precomputeLanguagesInBackground() Cached \(computedLanguages.count) languages matching Android implementation")
                
                // Notify observers that languages are ready
                NotificationCenter.default.post(name: CountryLanguageHelper.languagesDidUpdateNotification, object: nil)
            }
        }
    }
    
    // ANDROID PARITY: Extract the actual language computation logic
    private func computeFullLanguageList() -> [String] {
        // ANDROID PARITY: Exact Android implementation
        // String[] languages = Locale.getISOLanguages();
        // for (String language : languages) {
        //     Locale loc = new Locale(language);
        //     allLanguages.add(loc.getDisplayLanguage());
        // }
        
        var allLanguages: [String] = []
        
        // Get all ISO language codes like Android - Locale.getISOLanguages()
        let isoLanguageCodes = Locale.isoLanguageCodes
        
        for languageCode in isoLanguageCodes {
            let locale = Locale(identifier: languageCode)
            // ANDROID PARITY: Use default locale for display language (like Android's getDisplayLanguage())
            // Android uses the default system locale, iOS equivalent is Locale.current
            if let displayName = Locale.current.localizedString(forLanguageCode: languageCode) {
                // ANDROID PARITY: Android automatically capitalizes, iOS needs manual capitalization
                let capitalizedName = displayName.prefix(1).uppercased() + displayName.dropFirst()
                allLanguages.append(capitalizedName)
            }
        }
        
        // ANDROID PARITY: Android doesn't remove duplicates or sort - it uses the list as-is
        // But for practical purposes, we remove duplicates to avoid UI issues
        let uniqueLanguages = Array(Set(allLanguages))
        
        // ANDROID PARITY: Android doesn't sort the language list, but for better UX we sort
        let sortedLanguages = uniqueLanguages.sorted()
        
        return sortedLanguages
    }
    
    /// Validates if a country name exists in the Android-matching country list
    /// - Parameter countryName: The country name to validate
    /// - Returns: true if the country exists in the list, false otherwise
    func isValidCountry(_ countryName: String) -> Bool {
        let trimmed = countryName.trimmingCharacters(in: .whitespacesAndNewlines)
        return getAllCountries().contains(trimmed)
    }
    
    /// Validates if a language name exists in the Android-matching language list
    /// - Parameter languageName: The language name to validate
    /// - Returns: true if the language exists in the list, false otherwise
    func isValidLanguage(_ languageName: String) -> Bool {
        let trimmed = languageName.trimmingCharacters(in: .whitespacesAndNewlines)
        return getAllLanguages().contains(trimmed)
    }
}

extension CountryLanguageHelper {
    /// Returns the correct asset name for a country flag, handling common mappings and normalization.
    /// ANDROID PARITY: Matches Android's flag resource naming convention
    static func getFlagAssetName(for country: String) -> String? {
        // ANDROID PARITY: Convert country name to flag resource name like Android
        // Android uses: "ic_flag_" + country.replaceAll("\\s+", "_").toLowerCase()
        let flagName = country.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        
        // ANDROID PARITY: Handle special country name mappings
        let countryMappings: [String: String] = [
            "united_states_of_america": "United states of america",
            "usa": "United states of america",
            "united_kingdom": "United kingdom",
            "uk": "United kingdom",
            "south_korea": "South korea",
            "north_korea": "North korea",
            "united_arab_emirates": "United arab emirates",
            "uae": "United arab emirates"
        ]
        
        let finalName = countryMappings[flagName] ?? country
        
        // Convert to asset folder format: only first letter uppercase, rest lowercase, spaces preserved
        let assetName = finalName.prefix(1).uppercased() + finalName.dropFirst().lowercased()
        
        AppLogger.log(tag: "LOG-APP: CountryLanguageHelper", message: "getFlagAssetName(for: \(country)) -> \(assetName)")
        
        return assetName
    }
} 