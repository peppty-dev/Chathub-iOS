import Foundation
import OSLog

public struct AppLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.peppty.ChatApp" // Using your app's bundle identifier
    private static let osLog = OSLog(subsystem: subsystem, category: "AppLog") // Single category

    // Background queue for logging, similar to Android's HandlerThread
    private static let loggingQueue = DispatchQueue(label: "com.peppty.ChatApp.loggingQueue", qos: .utility)

    // Flag to control logging, similar to isWorkMode. True for DEBUG builds.
    // In Swift, #if DEBUG is the standard way.
    private static var isLoggingEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private static var didPrintBuildType = false // Track if we've printed the build type

    private init() {
        // Private initializer to prevent instantiation, as all methods are static.
        // The Android version has an instance, but for a Swift struct with static methods,
        // an instance is not idiomatic or required.
    }

    /**
     Logs a message with a tag.
     This is designed to be similar to the Android LoggingClass.log(tag, message) method.
     All messages are logged at the .error level to emulate Android's Log.e usage.
     Logging only occurs in DEBUG builds.

     - Parameters:
       - tag: The tag for the log message.
       - message: The message to log.
     */
    public static func log(tag: String, message: String) {
        if isLoggingEnabled {
            loggingQueue.async {
                // Logging using OSLog at .error level without "L" prefix and square brackets
                // The %{public}@ format specifier ensures the message is visible.
                os_log(.error, log: osLog, "%{public}@: %{public}@", tag, message)
            }
        }
    }

    /**
     Initializes the logger and logs the current build configuration.
     Should be called once, early in the app lifecycle (e.g., AppDelegate).
     */
    public static func initialize() {
        if isLoggingEnabled {
            #if DEBUG
            let buildMode = "DEBUG"
            #else
            let buildMode = "RELEASE" // Or any other custom flags you might have
            #endif
            if !didPrintBuildType {
                print("AppLogger initialized. Build Mode: \(buildMode). Logging enabled: \(isLoggingEnabled).")
                didPrintBuildType = true
            }
            // The Android version also logged BuildConfig.WORK.
            // We are treating isLoggingEnabled (DEBUG mode) as the equivalent of WORK mode.
            self.log(tag: "AppLogger", message: "LoggingClass initialized. Build Mode: \(buildMode). Logging enabled: \(isLoggingEnabled).")
        }
    }
} 