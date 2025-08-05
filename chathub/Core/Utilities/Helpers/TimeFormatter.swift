import Foundation

/// TimeFormatter utility class - iOS equivalent of Android's GetTimeAgo.java
/// Provides consistent timestamp formatting across platforms
class TimeFormatter {
    
    // Time constants matching Android implementation
    private static let SECOND_MILLIS: Int64 = 1000
    private static let MINUTE_MILLIS: Int64 = 60 * SECOND_MILLIS
    private static let HOUR_MILLIS: Int64 = 60 * MINUTE_MILLIS
    private static let DAY_MILLIS: Int64 = 24 * HOUR_MILLIS
    private static let WEEK_MILLIS: Int64 = 7 * DAY_MILLIS
    private static let MONTH_MILLIS: Int64 = 30 * DAY_MILLIS
    private static let YEAR_MILLIS: Int64 = 365 * DAY_MILLIS
    
    /// Get time ago string in short format (matching Android's primary getTimeAgo method)
    /// Returns: "now", "1m", "2h", "3d", "1w", "1mo", "1y", etc.
    static func getTimeAgo(_ timestamp: Int64) -> String {
        AppLogger.log(tag: "LOG-APP: TimeFormatter", message: "getTimeAgo() calculating time ago for timestamp: \(timestamp)")
        
        var time = timestamp
        
        // Android Pattern: Convert seconds to milliseconds if needed
        if time < 1000000000000 {
            time *= 1000
        }
        
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        
        // Android Pattern: Return empty string for invalid timestamps
        if time > now || time <= 0 {
            AppLogger.log(tag: "LOG-APP: TimeFormatter", message: "getTimeAgo() invalid timestamp, returning empty string")
            return " "
        }
        
        let diff = now - time
        
        // Less than 5 seconds
        if diff < 5 * SECOND_MILLIS {
            return "now"
        }
        
        // Less than a minute
        if diff < MINUTE_MILLIS {
            let seconds = Int(diff / SECOND_MILLIS)
            return "\(seconds)s"
        }
        
        // Less than an hour
        if diff < HOUR_MILLIS {
            let minutes = Int(diff / MINUTE_MILLIS)
            return minutes == 1 ? "1m" : "\(minutes)m"
        }
        
        // Less than a day
        if diff < DAY_MILLIS {
            let hours = Int(diff / HOUR_MILLIS)
            return hours == 1 ? "1h" : "\(hours)h"
        }
        
        // Less than a week
        if diff < WEEK_MILLIS {
            let days = Int(diff / DAY_MILLIS)
            return days == 1 ? "1d" : "\(days)d"
        }
        
        // Less than a month
        if diff < MONTH_MILLIS {
            let weeks = Int(diff / WEEK_MILLIS)
            return weeks == 1 ? "1w" : "\(weeks)w"
        }
        
        // Less than a year
        if diff < YEAR_MILLIS {
            let months = Int(diff / MONTH_MILLIS)
            return months == 1 ? "1mo" : "\(months)mo"
        }
        
        // More than a year
        let years = Int(diff / YEAR_MILLIS)
        return years == 1 ? "1y" : "\(years)y"
    }
    
    /// Get time ago string from Date object
    static func getTimeAgo(_ date: Date) -> String {
        let timestamp = Int64(date.timeIntervalSince1970)
        return getTimeAgo(timestamp)
    }
    
    /// Get time ago string in long format (matching Android's secondary getTimeAgo method)
    /// Returns: "just now", "a minute ago", "2 minutes ago", etc.
    static func getTimeAgoLong(_ timestamp: Int64) -> String {
        AppLogger.log(tag: "LOG-APP: TimeFormatter", message: "getTimeAgoLong() calculating long time ago for timestamp: \(timestamp)")
        
        var time = timestamp
        
        // Android Pattern: Convert seconds to milliseconds if needed
        if time < 1000000000000 {
            time *= 1000
        }
        
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        
        // Android Pattern: Return empty string for invalid timestamps
        if time > now || time <= 0 {
            return " "
        }
        
        let diff = now - time
        
        // Less than 5 seconds
        if diff < 5 * SECOND_MILLIS {
            return "just now"
        }
        
        // Less than a minute
        if diff < MINUTE_MILLIS {
            let seconds = Int(diff / SECOND_MILLIS)
            return seconds == 1 ? "a second ago" : "\(seconds) seconds ago"
        }
        
        // Less than an hour
        if diff < HOUR_MILLIS {
            let minutes = Int(diff / MINUTE_MILLIS)
            return minutes == 1 ? "a minute ago" : "\(minutes) minutes ago"
        }
        
        // Less than a day
        if diff < DAY_MILLIS {
            let hours = Int(diff / HOUR_MILLIS)
            return hours == 1 ? "an hour ago" : "\(hours) hours ago"
        }
        
        // Less than a week
        if diff < WEEK_MILLIS {
            let days = Int(diff / DAY_MILLIS)
            return days == 1 ? "yesterday" : "\(days) days ago"
        }
        
        // Less than a month
        if diff < MONTH_MILLIS {
            let weeks = Int(diff / WEEK_MILLIS)
            return weeks == 1 ? "a week ago" : "\(weeks) weeks ago"
        }
        
        // Less than a year
        if diff < YEAR_MILLIS {
            let months = Int(diff / MONTH_MILLIS)
            return months == 1 ? "a month ago" : "\(months) months ago"
        }
        
        // More than a year
        let years = Int(diff / YEAR_MILLIS)
        return years == 1 ? "a year ago" : "\(years) years ago"
    }
    
    /// Get time ago string in long format from Date object
    static func getTimeAgoLong(_ date: Date) -> String {
        let timestamp = Int64(date.timeIntervalSince1970)
        return getTimeAgoLong(timestamp)
    }
} 