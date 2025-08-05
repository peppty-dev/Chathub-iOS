import SwiftUI

/// Centralised color palette to keep the app visually consistent across Light & Dark modes.
///
/// Use these static properties instead of hard-coding `Color("Background Color")` or `Color("background")` directly.
/// This brings a single source of truth which makes it trivial to adjust the theme in the future.
public enum AppTheme {
    
    // MARK: - Background Colors
    /// Primary surface / view background colour.
    /// Internally this maps to the asset catalogue colour named "Background Color".
    public static let background = Color("Background Color")
    
    /// Card / popover background (if you need a slightly translucent overlay).
    public static let secondaryBackground = Color("background")
    
    // MARK: - Text Colors
    /// Primary text colour. Defaults to the automatic system label colour which adapts to light/dark mode.
    public static let primaryText = Color.primary
    
    /// Secondary text colour.
    public static let secondaryText = Color.secondary
    
    /// Dark text color for light backgrounds
    public static let darkText = Color("dark")
    
    /// Bright text color
    public static let brightText = Color("bright")
    
    // MARK: - UI Element Colors  
    /// Accent colour used throughout the app.
    public static let accent = Color.accentColor
    
    /// Color accent from assets
    public static let colorAccent = Color("ColorAccent")
    
    /// Primary blue color for buttons and accents
    public static let blue = Color("blue")
    
    /// Dark blue color for male gender text
    public static let darkBlue = Color("dark_blue")
    
    /// Tab color for navigation elements
    public static let tabColor = Color("TabColor")
    
    /// Button color for interactive elements
    public static let buttonColor = Color("ButtonColor")
    
    /// View color for general UI elements
    public static let viewColor = Color("ViewColor")
    
    // MARK: - Shade Colors
    public static let shade1 = Color("shade1")
    public static let shade2 = Color("shade2") 
    public static let shade3 = Color("shade3")
    public static let shade4 = Color("shade4")
    public static let shade5 = Color("shade5")
    public static let shade6 = Color("shade6")
    public static let shade7 = Color("shade7")
    public static let shade8 = Color("shade8")
    public static let shade9 = Color("shade9")
    public static let shade200 = Color("shade_200")
    
    // MARK: - Gender Colors
    public static let maleColor = Color("maleColor")
    public static let femaleColor = Color("femaleColor")
    
    // MARK: - Feature-Specific Colors

    // Removed excluded feature colors: roomsBackground, channelsBackground, postBackground, roleplayBackground
    
    // MARK: - Status Colors
    public static let online = Color("Online")
    public static let here = Color("Here")
    public static let warningOrange = Color("warningOrange")
    public static let orange50 = Color("orange_50")
    public static let orange900 = Color("orange_900")
    
    // MARK: - Profile Colors
    public static let maleAccount = Color("MaleAccountBackground")
    public static let femaleAccount = Color("FemaleAccountBackground")
    public static let profileCallColor = Color("profileCallColor")
    public static let profileMaleAccount = Color("profileMaleAccount")
    public static let profileFemaleAccount = Color("profileFemaleAccount")
    
    // MARK: - White/Black
    public static let white = Color("white")
    public static let black = Color("black")
    public static let halfWhite = Color("half_white")
} 