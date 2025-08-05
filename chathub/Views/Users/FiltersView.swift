import SwiftUI


struct FiltersView: View {
    @State private var selectedMinAge: String = ""
    @State private var selectedMaxAge: String = ""
    @State private var selectedMale: Bool = false
    @State private var selectedFemale: Bool = false
    @State private var selectedCountry: String = ""
    @State private var selectedLanguage: String = ""
    @State private var showNearbyOnly: Bool = false {
        didSet {
            // Real-time saving like Android
            UserSessionManager.shared.filterNearbyOnly = showNearbyOnly
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "Nearby filter changed to: \(showNearbyOnly)")
        }
    }
    
    // Dropdown data
    @State private var showCountrySuggestions = false
    @State private var showLanguageSuggestions = false
    @State private var allCountries: [String] = []
    @State private var allLanguages: [String] = []
    
    // Computed properties for filtered suggestions
    var filteredCountries: [String] {
        guard !selectedCountry.isEmpty, !allCountries.isEmpty else { return [] }
        let lowercasedQuery = selectedCountry.lowercased()
        return allCountries.lazy
            .filter { $0.lowercased().contains(lowercasedQuery) }
            .prefix(5)
            .map { $0 }
    }
    
    var filteredLanguages: [String] {
        guard !selectedLanguage.isEmpty, !allLanguages.isEmpty else { return [] }
        let lowercasedQuery = selectedLanguage.lowercased()
        return allLanguages.lazy
            .filter { $0.lowercased().contains(lowercasedQuery) }
            .prefix(5)
            .map { $0 }
    }
    
    // UI States
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var showFilterLimitPopup: Bool = false  // New filter limit system
    @State private var filterLimitResult: FeatureLimitResult?
    @State private var ageErrorMessage: String? = nil
    @State private var countryErrorMessage: String? = nil
    @State private var languageErrorMessage: String? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    // Subscription status
    let isLiteSubscriber: Bool
    
    // Callbacks
    var onFiltersApplied: (([String: Any]) -> Void)?
    var onFiltersCleared: (() -> Void)?
    
    // Initialize with default values
    init(isLiteSubscriber: Bool = false, onFiltersApplied: (([String: Any]) -> Void)? = nil, onFiltersCleared: (() -> Void)? = nil) {
        self.isLiteSubscriber = isLiteSubscriber
        self.onFiltersApplied = onFiltersApplied
        self.onFiltersCleared = onFiltersCleared
    }
    
    var body: some View {
        ZStack {
            Color("Background Color")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) { // UI Guide: Consistent spacing between related sections
                        genderSection
                        countrySection
                        languageSection
                        nearbySection
                        ageSection
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 16) // UI Guide: Consistent horizontal padding
                    .padding(.bottom, 120) // Extra bottom padding to prevent button overlap
                }
                
                bottomButtons
            }
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere outside text fields
                hideKeyboard()
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadFilters()
                loadGenderFilters() // Android parity: Load gender separately like onResume()
                loadDropdownData()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { 
                    triggerHapticFeedback()
                    errorMessage = nil 
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Success", isPresented: .constant(successMessage != nil)) {
                Button("OK") { 
                    triggerHapticFeedback()
                    successMessage = nil 
                }
            } message: {
                Text(successMessage ?? "")
            }
            .alert("Age Validation", isPresented: .constant(ageErrorMessage != nil)) {
                Button("OK") { 
                    triggerHapticFeedback()
                    ageErrorMessage = nil 
                }
            } message: {
                Text(ageErrorMessage ?? "")
            }
            .alert("Country Validation", isPresented: .constant(countryErrorMessage != nil)) {
                Button("OK") { 
                    triggerHapticFeedback()
                    countryErrorMessage = nil 
                }
            } message: {
                Text(countryErrorMessage ?? "")
            }
            .alert("Language Validation", isPresented: .constant(languageErrorMessage != nil)) {
                Button("OK") { 
                    triggerHapticFeedback()
                    languageErrorMessage = nil 
                }
            } message: {
                Text(languageErrorMessage ?? "")
            }
            
            // --- Filter Limit Popup Overlay (New System) ---
            if showFilterLimitPopup, let result = filterLimitResult {
                FilterLimitPopupView(
                    isPresented: $showFilterLimitPopup,
                    remainingCooldown: result.remainingCooldown,
                    isLimitReached: result.isLimitReached,
                    currentUsage: result.currentUsage,
                    limit: result.limit,
                    onApplyFilter: {
                        AppLogger.log(tag: "LOG-APP: FiltersView", message: "User chose to apply filter from popup.")
                        handleFilterAction()
                    },
                    onUpgradeToPremium: {
                        AppLogger.log(tag: "LOG-APP: FiltersView", message: "User chose to upgrade from filter popup.")
                        navigateToSubscriptionView()
                    }
                )
            }
        }
    }
    
    // MARK: - View Components
    
    private var hasActiveFilters: Bool {
        return !selectedMinAge.isEmpty || !selectedMaxAge.isEmpty || 
               selectedMale || selectedFemale || 
               !selectedCountry.isEmpty || !selectedLanguage.isEmpty || 
               showNearbyOnly
    }
    
    private var genderSection: some View {
        FilterSection(title: "Gender", icon: "person.2.fill") {
            VStack(spacing: 12) { // UI Guide: Consistent spacing between related elements
                GenderCheckbox(title: "Male", isSelected: selectedMale, icon: "person.crop.circle") {
                    triggerHapticFeedback()
                    selectedMale.toggle()
                    handleGenderSelection(isMale: true, isSelected: selectedMale)
                }
                GenderCheckbox(title: "Female", isSelected: selectedFemale, icon: "person.crop.circle.fill") {
                    triggerHapticFeedback()
                    selectedFemale.toggle()
                    handleGenderSelection(isMale: false, isSelected: selectedFemale)
                }
            }
        }
    }
    
    private var countrySection: some View {
        FilterSection(title: "Country", icon: "globe") {
            VStack(spacing: 0) {
                // Show dropdown above the text field
                if showCountrySuggestions && !selectedCountry.isEmpty {
                    countrySuggestionsList
                }
                
                FilterTextField(
                    placeholder: "Choose Country",
                    text: $selectedCountry,
                    icon: "flag.fill"
                )
                .onChange(of: selectedCountry) { newValue in
                    // Only show suggestions if input is not empty AND not an exact match
                    showCountrySuggestions = !newValue.isEmpty && !allCountries.contains(newValue)
                    validateCountryInput(newValue)
                }
            }
        }
    }
    
    private var countrySuggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Show matches in normal order since dropdown is now above the text field
                let countries = Array(filteredCountries.prefix(5))
                ForEach(Array(countries.enumerated()), id: \.offset) { index, country in
                    SuggestionRow(text: country, icon: "flag.fill") {
                        triggerHapticFeedback()
                        selectedCountry = country
                        showCountrySuggestions = false
                        hideKeyboard()
                    }
                    
                    // Add dividers between items (but not after the last item)
                    if index < countries.count - 1 {
                        Divider()
                            .background(Color("shade3"))
                    }
                }
            }
            .background(Color("Background Color"))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color("shade3"), lineWidth: 1)
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2) // Add subtle shadow for better visual separation
        }
        .padding(.bottom, 8) // Add small gap between dropdown and text field
        .zIndex(1) // Ensure dropdown appears above other elements
    }
    
    private var languageSection: some View {
        FilterSection(title: "Language", icon: "textformat.abc") {
            VStack(spacing: 0) {
                // Show dropdown above the text field
                if showLanguageSuggestions && !selectedLanguage.isEmpty {
                    languageSuggestionsList
                }
                
                FilterTextField(
                    placeholder: "Enter language",
                    text: $selectedLanguage,
                    icon: "globe.americas.fill"
                )
                .onChange(of: selectedLanguage) { newValue in
                    // Only show suggestions if input is not empty AND not an exact match
                    showLanguageSuggestions = !newValue.isEmpty && !allLanguages.contains(newValue)
                    validateLanguageInput(newValue)
                }
            }
        }
    }
    
    private var languageSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Show matches in normal order since dropdown is now above the text field
                let languages = Array(filteredLanguages.prefix(5))
                ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                    SuggestionRow(text: language, icon: "globe.americas.fill") {
                        triggerHapticFeedback()
                        selectedLanguage = language
                        showLanguageSuggestions = false
                        hideKeyboard()
                    }
                    
                    // Add dividers between items (but not after the last item)
                    if index < languages.count - 1 {
                        Divider()
                            .background(Color("shade3"))
                    }
                }
            }
            .background(Color("Background Color"))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color("shade3"), lineWidth: 1)
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2) // Add subtle shadow for better visual separation
        }
        .padding(.bottom, 8) // Add small gap between dropdown and text field
        .zIndex(1) // Ensure dropdown appears above other elements
    }
    
    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Custom header with toggle button inline
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .foregroundColor(Color("ColorAccent"))
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24, height: 24)
                
                Text("Nearby")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color("dark"))
                
                Spacer()
                
                Toggle("", isOn: $showNearbyOnly)
                    .toggleStyle(SwitchToggleStyle())
                    .scaleEffect(1.1) // UI Guide: Ensure sufficient target size
                    .onChange(of: showNearbyOnly) { _ in
                        triggerHapticFeedback()
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("shade1"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("shade3"), lineWidth: 1)
                )
        )
    }
    
    private var ageSection: some View {
        FilterSection(title: "Age Range", icon: "calendar") {
            VStack(spacing: 16) { // UI Guide: Consistent spacing between related elements
                // Minimum Age Section
                HStack(alignment: .center, spacing: 16) {
                    Label("Minimum", systemImage: "calendar.badge.minus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                        .frame(width: 120, alignment: .leading)
                    
                    FilterTextField(
                        placeholder: "Min age",
                        text: $selectedMinAge,
                        keyboardType: .numberPad,
                        icon: "person.badge.minus"
                    )
                    .onChange(of: selectedMinAge) { newValue in
                        // Only limit to 2 characters, no validation during typing
                        let filtered = String(newValue.prefix(2))
                        if filtered != newValue {
                            selectedMinAge = filtered
                        }
                    }
                }
                
                // Maximum Age Section
                HStack(alignment: .center, spacing: 16) {
                    Label("Maximum", systemImage: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("dark"))
                        .frame(width: 120, alignment: .leading)
                    
                    FilterTextField(
                        placeholder: "Max age",
                        text: $selectedMaxAge,
                        keyboardType: .numberPad,
                        icon: "person.badge.plus"
                    )
                    .onChange(of: selectedMaxAge) { newValue in
                        // Only limit to 2 characters, no validation during typing
                        let filtered = String(newValue.prefix(2))
                        if filtered != newValue {
                            selectedMaxAge = filtered
                        }
                    }
                }
            }
        }
    }
    
    private var bottomButtons: some View {
        VStack(spacing: 0) {
            // UI Guide: Clear visual separation
            Divider()
                .background(Color("shade3"))
            
            HStack(spacing: 16) { // UI Guide: Consistent spacing between buttons
                // Secondary Button (Reset)
                Button(action: {
                    triggerHapticFeedback()
                    clearFilters()
                }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("dark"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52) // UI Guide: Minimum 44pt touch target
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("shade2"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color("shade4"), lineWidth: 1.5)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle()) // Prevent default button styling
                
                // Primary Button (Apply) - UI Guide: Single primary button for most important action
                Button(action: {
                    triggerHapticFeedback()
                    hideKeyboard()
                    applyFilters()
                }) {
                    Label("Apply Filters", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52) // UI Guide: Minimum 44pt touch target
                        .background(
                            LinearGradient(
                                colors: [Color("ColorAccent"), Color("ColorAccent").opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color("ColorAccent").opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle()) // Prevent default button styling
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color("Background Color"))
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadDropdownData() {
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "loadDropdownData() Loading countries and languages in background")
        
        // Load countries and languages in background to prevent UI blocking
        Task.detached(priority: .userInitiated) {
            // Countries and Languages: Use shared global functions for 100% Android parity with LoginView
            let countries = await getAllCountries()
            let languages = await getAllLanguages()
            
            await MainActor.run {
                self.allCountries = countries
                self.allLanguages = languages
                AppLogger.log(tag: "LOG-APP: FiltersView", message: "loadDropdownData() Loaded \(countries.count) countries and \(languages.count) languages using shared Android-matching helper")
            }
        }
    }
    
    private func loadFilters() {
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "loadFilters() Loading saved filter preferences")
        
        let sessionManager = UserSessionManager.shared
        
        if let savedMinAge = sessionManager.filterMinAge, !savedMinAge.isEmpty {
            selectedMinAge = savedMinAge
        }
        if let savedMaxAge = sessionManager.filterMaxAge, !savedMaxAge.isEmpty {
            selectedMaxAge = savedMaxAge
        }
        
        selectedCountry = sessionManager.filterCountry ?? ""
        selectedLanguage = sessionManager.filterLanguage ?? ""
        showNearbyOnly = sessionManager.filterNearbyOnly
        
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "loadFilters() Filters loaded - Age: \(selectedMinAge)-\(selectedMaxAge), Country: \(selectedCountry), Language: \(selectedLanguage), Nearby: \(showNearbyOnly)")
    }
    
    private func loadGenderFilters() {
        // Android parity: Match onResume() gender loading logic exactly
        let sessionManager = UserSessionManager.shared
        
        if let savedGender = sessionManager.filterGender, !savedGender.isEmpty {
            let gender = savedGender.lowercased()
            if gender == "female" {
                selectedFemale = true
                selectedMale = false
            } else if gender == "male" {
                selectedMale = true
                selectedFemale = false
            } else if gender == "both" {
                selectedMale = true
                selectedFemale = true
            } else {
                selectedMale = false
                selectedFemale = false
            }
        } else {
            selectedMale = false
            selectedFemale = false
        }
        
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "loadGenderFilters() Gender loaded: \(sessionManager.filterGender ?? ""), Male: \(selectedMale), Female: \(selectedFemale)")
    }
    
    private func clearFilters() {
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "clearFilters() Clearing all filter preferences")
        
        // Android parity: Use SessionManager.clearAllFilters() first, then manually reset UI
        let sessionManager = UserSessionManager.shared
        if sessionManager.clearAllFilters() {
            // Manually reset UI state matching Android behavior
            showNearbyOnly = false
            selectedFemale = false
            selectedMale = false
            selectedMaxAge = ""
            selectedMinAge = ""
            selectedCountry = ""
            selectedLanguage = ""
            
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "clearFilters() All filters cleared successfully")
            
            // Call the clear callback
            onFiltersCleared?()
            
            successMessage = "Filters reset successfully!"
        } else {
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "clearFilters() Failed to clear filters")
            errorMessage = "Failed to reset filters. Please try again."
        }
    }
    
    private func validateCountryInput(_ input: String) {
        countryErrorMessage = nil
        
        // Android-style validation: only validate if input is not empty
        if !input.isEmpty && !allCountries.contains(input) {
            // Don't show error immediately while typing, only on apply
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "validateCountryInput() Invalid country entered: \(input)")
        }
    }
    
    private func validateLanguageInput(_ input: String) {
        languageErrorMessage = nil
        
        // Android-style validation: only validate if input is not empty
        if !input.isEmpty && !allLanguages.contains(input) {
            // Don't show error immediately while typing, only on apply
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "validateLanguageInput() Invalid language entered: \(input)")
        }
    }
    
    // Gender selection handler - save current gender selection state to SessionManager
    private func handleGenderSelection(isMale: Bool, isSelected: Bool) {
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "handleGenderSelection() isMale: \(isMale), isSelected: \(isSelected)")
        
        // Save the complete gender selection state based on current UI state
        if selectedMale && selectedFemale {
            UserSessionManager.shared.filterGender = "Both"
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "handleGenderSelection() Saved: Both")
        } else if selectedMale {
            UserSessionManager.shared.filterGender = "Male"
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "handleGenderSelection() Saved: Male")
        } else if selectedFemale {
            UserSessionManager.shared.filterGender = "Female"
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "handleGenderSelection() Saved: Female")
        } else {
            UserSessionManager.shared.filterGender = ""
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "handleGenderSelection() Saved: None")
        }
    }
    
    private func validateAges() -> Bool {
        ageErrorMessage = nil
        
        // Validate minimum age
        if !selectedMinAge.isEmpty {
            guard let minAge = Int(selectedMinAge), minAge >= 18 else {
                ageErrorMessage = "More then 18 years only"
                return false
            }
            
            // Check if max age exists and is valid
            if !selectedMaxAge.isEmpty {
                guard let maxAge = Int(selectedMaxAge) else {
                    ageErrorMessage = "Please enter valid age numbers"
                    return false
                }
                
                if minAge >= maxAge {
                    ageErrorMessage = "Min age should be smaller then max"
                    return false
                }
            }
        }
        
        // Validate maximum age
        if !selectedMaxAge.isEmpty {
            guard let maxAge = Int(selectedMaxAge), maxAge >= 18 else {
                ageErrorMessage = "More then 18 years only"
                return false
            }
            
            // Check if min age exists and is valid
            if !selectedMinAge.isEmpty {
                guard let minAge = Int(selectedMinAge) else {
                    ageErrorMessage = "Please enter valid age numbers"
                    return false
                }
                
                if maxAge <= minAge {
                    ageErrorMessage = "Max age should be greater then min"
                    return false
                }
            }
        }
        
        return true
    }
    
    private func applyFilters() {
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "applyFilters() Apply filters button tapped")
        hideKeyboard()
        
        // Android parity: Save country and language immediately before validation
        let currentCountryInput = selectedCountry.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if currentCountryInput.count > 0 && !getAllCountries().contains(currentCountryInput) {
            countryErrorMessage = "Please select a valid country from the list"
            return
        } else if currentCountryInput.count > 0 {
            UserSessionManager.shared.filterCountry = currentCountryInput
        } else {
            UserSessionManager.shared.filterCountry = ""
        }
        
        let currentLanguageInput = selectedLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if currentLanguageInput.count > 0 && !getAllLanguages().contains(currentLanguageInput) {
            languageErrorMessage = "Please select a valid language from the list"
            return
        } else if currentLanguageInput.count > 0 {
            UserSessionManager.shared.filterLanguage = currentLanguageInput
        } else {
            UserSessionManager.shared.filterLanguage = ""
        }
        
        // Reset online users refresh time (matching Android)
        UserSessionManager.shared.onlineUsersRefreshTime = 0
        
        // Validate ages and save them if valid
        if !validateAges() {
            return
        }
        
        // Save age values to SessionManager after validation passes
        if !selectedMinAge.isEmpty {
            UserSessionManager.shared.filterMinAge = selectedMinAge
        } else {
            UserSessionManager.shared.filterMinAge = ""
        }
        
        if !selectedMaxAge.isEmpty {
            UserSessionManager.shared.filterMaxAge = selectedMaxAge
        } else {
            UserSessionManager.shared.filterMaxAge = ""
        }
        
        // Check filter limits using new system
        performFilterWithLimits()
    }
    
    // MARK: - New Filter System
    
    private func performFilterWithLimits() {
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "performFilterWithLimits() Checking filter limits")
        
        let result = FilterLimitManager.shared.checkFilterLimit()
        
        if result.showPopup {
            // Always show popup for non-Lite subscribers and non-new users
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "performFilterWithLimits() Showing filter limit popup")
            
            // Track popup shown
            FilterAnalytics.shared.trackFilterPopupShown(
                currentUsage: result.currentUsage,
                limit: result.limit,
                remainingCooldown: result.remainingCooldown,
                triggerReason: result.isLimitReached ? "limit_reached" : "always_show_strategy"
            )
            
            filterLimitResult = result
            showFilterLimitPopup = true
        } else {
            // Lite subscribers and new users bypass popup entirely
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "performFilterWithLimits() User bypassing popup - applying filters directly")
            
            // Track bypass analytics
            let userType = FilterAnalytics.shared.getUserType()
            if userType == "lite_subscriber" {
                FilterAnalytics.shared.trackLiteSubscriberBypass()
            } else if userType == "new_user" {
                let firstAccountTime = UserSessionManager.shared.firstAccountCreatedTime
                let newUserPeriod = SessionManager.shared.newUserFreePeriodSeconds
                let remainingTime = TimeInterval(newUserPeriod) - (Date().timeIntervalSince1970 - firstAccountTime)
                FilterAnalytics.shared.trackNewUserBypass(timeRemaining: max(0, remainingTime))
            }
            
            performActualFilter()
        }
    }
    
    private func handleFilterAction() {
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "handleFilterAction() Free filter button tapped")
        
        // User clicked filter from popup - they were already verified to proceed
        // No need to check limits again, just apply the filter
        performActualFilter()
    }
    
    private func performActualFilter() {
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "performActualFilter() Applying filters")
        
        FilterLimitManager.shared.performFilter { success in
            if success {
                DispatchQueue.main.async {
                    self.proceedWithFilterApplication()
                }
            } else {
                AppLogger.log(tag: "LOG-APP: FiltersView", message: "performActualFilter() Filter blocked")
            }
        }
    }
    
    private func proceedWithFilterApplication() {
        // Android parity: Don't save age/gender filters here, they're already saved by individual handlers
        // Only save remaining filters that aren't saved elsewhere
        
        // Delete all online users (matching Android AsyncTask)
        deleteAllOnlineUsers()
        
        // CRITICAL FIX: Call the onFiltersApplied callback to update the OnlineUsersViewModel
        if let callback = onFiltersApplied {
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "proceedWithFilterApplication() Calling onFiltersApplied callback")
            
            // Create filter dictionary that matches OnlineUsersView expectations
            var appliedFilters: [String: Any] = [:]
            
            // Set gender based on current selections - matching Android logic
            if selectedMale && selectedFemale {
                appliedFilters["gender"] = "Both"  // Both selected
            } else if selectedMale {
                appliedFilters["gender"] = "Male"
            } else if selectedFemale {
                appliedFilters["gender"] = "Female"
            } else {
                appliedFilters["gender"] = ""  // None selected
            }
            
            appliedFilters["country"] = selectedCountry.trimmingCharacters(in: .whitespacesAndNewlines)
            appliedFilters["language"] = selectedLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Convert age strings to integers if they exist
            if !selectedMinAge.isEmpty, let minAge = Int(selectedMinAge) {
                appliedFilters["min_age"] = minAge
            }
            if !selectedMaxAge.isEmpty, let maxAge = Int(selectedMaxAge) {
                appliedFilters["max_age"] = maxAge
            }
            
            appliedFilters["online_only"] = showNearbyOnly
            
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "proceedWithFilterApplication() Filter data: \(appliedFilters)")
            
            callback(appliedFilters)
        } else {
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "proceedWithFilterApplication() No onFiltersApplied callback provided")
        }
        
        // Navigate back to main screen (matching Android behavior)
        navigateToMainScreen()
    }
    
    private func deleteAllOnlineUsers() {
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "deleteAllOnlineUsers() Starting online users deletion")
        
        // Use background queue like Android AsyncTask - matching Android's DeleteOnlineUsersAsyncTask
        Task.detached(priority: .background) {
            // Delete all online users from SQLite database (Android parity: CHLD.getCHLDInstance(context).Online_Users_Dao().deleteAllOnlineUsers())
            let onlineUsersDB = OnlineUsersDB.shared
            onlineUsersDB.deleteAllOnlineUsers()
            
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "deleteAllOnlineUsers() Online users deletion completed")
        }
    }
    
    private func navigateToMainScreen() {
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "navigateToMainScreen() Attempting to navigate to main screen")
        
        // Get the key window's root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "navigateToMainScreen() Could not find rootViewController")
            self.dismiss()
            return
        }
        
        // Navigate to main screen matching Android's Intent.FLAG_ACTIVITY_CLEAR_TASK | Intent.FLAG_ACTIVITY_NEW_TASK
        if let tabController = rootVC as? UITabBarController {
            // Reset to main tab (index 0 usually)
            tabController.selectedIndex = 0
            
            // If there's a navigation controller, pop to root
            if let navController = tabController.selectedViewController as? UINavigationController {
                navController.popToRootViewController(animated: false)
            }
        }
        
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "navigateToMainScreen() Navigated to main screen successfully")
        self.dismiss()
    }
    
    private func triggerHapticFeedback() {
        // Matching Android's AdMonetizationHelper.triggerHapticFeedback()
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func navigateToSubscriptionView() {
        AppLogger.log(tag: "LOG-APP: FiltersView", message: "navigateToSubscriptionView() Attempting to navigate to SubscriptionView")
        
        // Get the key window's root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "navigateToSubscriptionView() Could not find rootViewController")
            return
        }

        // Create the destination view
        let subscriptionView = SubscriptionView()
        let hostingController = UIHostingController(rootView: subscriptionView)

        // Find the most appropriate navigation controller to push from
        if let tabController = rootVC as? UITabBarController,
           let navController = tabController.selectedViewController as? UINavigationController {
            navController.pushViewController(hostingController, animated: true)
        } else if let navController = rootVC as? UINavigationController {
            navController.pushViewController(hostingController, animated: true)
        } else if let presentedVC = rootVC.presentedViewController {
            // Handle cases where a modal might be on top
            if let navController = presentedVC as? UINavigationController {
                navController.pushViewController(hostingController, animated: true)
            } else {
                rootVC.present(hostingController, animated: true) // Fallback to modal presentation
            }
        } else {
            // Fallback for unexpected view hierarchies
            AppLogger.log(tag: "LOG-APP: FiltersView", message: "navigateToSubscriptionView() No suitable UINavigationController found. Presenting modally as a fallback")
            rootVC.present(hostingController, animated: true)
        }
    }
    

    
    // Add helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Android Parity Methods
    // Note: Country and language lists now use shared CountryLanguageHelper for consistency
    
    /// ANDROID PARITY: Helper functions matching Android getAllCountries() and getAllLanguages()
    private func getAllCountries() -> [String] {
        return CountryLanguageHelper.shared.getAllCountries()
    }
    
    private func getAllLanguages() -> [String] {
        return CountryLanguageHelper.shared.getAllLanguages()
    }
}

struct GenderCheckbox: View {
    let title: String
    let isSelected: Bool
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) { // UI Guide: Consistent spacing
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? Color("ColorAccent") : Color("shade6")) // UI Guide: Use theme colors with proper contrast
                    .font(.system(size: 20, weight: .medium))
                
                Text(title)
                    .font(.system(size: 16, weight: .medium)) // UI Guide: Regular and bold font weights only
                    .foregroundColor(Color("dark"))
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14) // UI Guide: Sufficient target size (minimum 44pt)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color("ColorAccent").opacity(0.1) : Color("shade1"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color("ColorAccent") : Color("shade3"), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle()) // Prevent default button styling
    }
}

// UI Guide: Reusable section component for consistent layout
struct FilterSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { // UI Guide: Consistent spacing based on relationship
            // Section title
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(Color("ColorAccent"))
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold)) // UI Guide: Clear hierarchy with font weights
                    .foregroundColor(Color("dark"))
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading) // UI Guide: Single alignment (left)
            
            // Section content
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("shade1"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("shade3"), lineWidth: 1)
                )
        )
    }
}

// UI Guide: Reusable text field component with consistent styling
struct FilterTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var icon: String = "textfield"
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 16, weight: .regular)) // UI Guide: Regular font weight
            .foregroundColor(Color("dark"))
        .padding(.horizontal, 16)
        .padding(.vertical, 14) // UI Guide: Sufficient target size
        .background(Color("Background Color"))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("shade3"), lineWidth: 1.5) // UI Guide: Ensure 3:1 contrast ratio for interface elements
        )
        .cornerRadius(16)
        .keyboardType(keyboardType)
    }
}

// UI Guide: Reusable suggestion row component
struct SuggestionRow: View {
    let text: String
    var icon: String = "circle"
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(text)
                    .font(.system(size: 16, weight: .regular)) // UI Guide: Regular font weight
                    .foregroundColor(Color("dark"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12) // UI Guide: Sufficient target size
            .background(Color("Background Color"))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Updated CardSection for backward compatibility (deprecated - use FilterSection instead)
struct CardSection<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(Color("shade1"))  // Using shade1 to match Android's shade_100
            .cornerRadius(16)
            .padding(.horizontal, 15)
    }
}

#Preview {
    NavigationView {
        FiltersView()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    NavigationView {
        FiltersView()
    }
    .preferredColorScheme(.dark)
}

 
