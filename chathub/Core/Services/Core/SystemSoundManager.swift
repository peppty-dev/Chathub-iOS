import Foundation
import AudioToolbox
import AVFoundation

/// System Sound Manager - Handles system ringtones and sounds
/// Replaces custom MP3 files with iOS system sounds to reduce app size
class SystemSoundManager {
    
    // MARK: - System Sound IDs
    
    /// System sound IDs for different ringtones
    enum SystemSoundID: UInt32 {
        case incomingCallRingtone = 1005    // Default ringtone sound
        case outgoingCallRingtone = 1013    // Outgoing call sound
        case messageReceived = 1007         // Message received sound
        case mailReceived = 1000            // Mail received sound
        case newVoicemail = 1015           // New voicemail sound
        case calendarAlert = 1006          // Calendar alert sound
        case reminderAlert = 1008          // Reminder alert sound
        case keyboardClick = 1104          // Keyboard click sound
        case lock = 1100                   // Lock sound
        case unlock = 1101                 // Unlock sound
        case photoShutter = 1108           // Photo shutter sound
        case beginRecording = 1113         // Begin recording sound
        case endRecording = 1114           // End recording sound
        case jblBegin = 1116               // JBL begin sound
        case jblConfirm = 1117             // JBL confirm sound
        case jblCancel = 1118              // JBL cancel sound
        case beginVideoRecord = 1119       // Begin video recording sound
        case endVideoRecord = 1120         // End video recording sound
        case vcInvitationAccepted = 1150   // Video call invitation accepted
        case vcRinging = 1151              // Video call ringing
        case vcEnded = 1152                // Video call ended
        case vcCallWaiting = 1153          // Video call waiting
        case vcCallUpgrade = 1154          // Video call upgrade
        case touchTone = 1200              // Touch tone sound
        case smsReceived = 1003            // SMS received sound
        case ussdAlert = 1050              // USSD alert sound
        case simToolkitCallDropped = 1051  // SIM toolkit call dropped
        case simToolkitGeneralBeep = 1052  // SIM toolkit general beep
        case simToolkitNegativeACK = 1053  // SIM toolkit negative ACK
        case simToolkitPositiveACK = 1054  // SIM toolkit positive ACK
        case simToolkitSMS = 1055          // SIM toolkit SMS
        case tweetSent = 1016              // Tweet sent sound
        case anticipate = 1020             // Anticipate sound
        case bloom = 1021                  // Bloom sound
        case calypso = 1022                // Calypso sound
        case chooChoo = 1023               // Choo choo sound
        case descent = 1024                // Descent sound
        case fanfare = 1025                // Fanfare sound
        case ladder = 1026                 // Ladder sound
        case minuet = 1027                 // Minuet sound
        case newsFlash = 1028              // News flash sound
        case noir = 1029                   // Noir sound
        case sherwoodForest = 1030         // Sherwood forest sound
        case spell = 1031                  // Spell sound
        case suspense = 1032               // Suspense sound
        case telegraph = 1033              // Telegraph sound
        case tiptoes = 1034                // Tiptoes sound
        case typewriters = 1035            // Typewriters sound
        case update = 1036                 // Update sound
    }
    
    // MARK: - Singleton
    
    static let shared = SystemSoundManager()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Play incoming call ringtone - Android music_ring.mp3 equivalent
    func playIncomingCallRingtone() {
        AppLogger.log(tag: "LOG-APP: SystemSoundManager", message: "playIncomingCallRingtone() playing system ringtone")
        AudioServicesPlaySystemSound(SystemSoundID.incomingCallRingtone.rawValue)
    }
    
    /// Play outgoing call ringtone - Android phone_ringing_sound.mp3 equivalent
    func playOutgoingCallRingtone() {
        AppLogger.log(tag: "LOG-APP: SystemSoundManager", message: "playOutgoingCallRingtone() playing system ringtone")
        AudioServicesPlaySystemSound(SystemSoundID.outgoingCallRingtone.rawValue)
    }
    
    /// Play a specific system sound
    /// - Parameter soundID: The system sound ID to play
    func playSystemSound(_ soundID: SystemSoundID) {
        AppLogger.log(tag: "LOG-APP: SystemSoundManager", message: "playSystemSound() playing sound ID: \(soundID.rawValue)")
        AudioServicesPlaySystemSound(soundID.rawValue)
    }
    
    /// Play system sound with vibration
    /// - Parameter soundID: The system sound ID to play
    func playSystemSoundWithVibration(_ soundID: SystemSoundID) {
        AppLogger.log(tag: "LOG-APP: SystemSoundManager", message: "playSystemSoundWithVibration() playing sound ID: \(soundID.rawValue)")
        AudioServicesPlayAlertSound(soundID.rawValue)
    }
    
    /// Stop all system sounds (Note: System sounds are short and stop automatically)
    func stopAllSounds() {
        AppLogger.log(tag: "LOG-APP: SystemSoundManager", message: "stopAllSounds() system sounds stop automatically")
        // System sounds are short and stop automatically
        // This method is provided for interface compatibility
    }
    
    // MARK: - Convenience Methods
    
    /// Play message received sound
    func playMessageReceived() {
        playSystemSound(.messageReceived)
    }
    
    /// Play mail received sound
    func playMailReceived() {
        playSystemSound(.mailReceived)
    }
    
    /// Play new voicemail sound
    func playNewVoicemail() {
        playSystemSound(.newVoicemail)
    }
    
    /// Play calendar alert sound
    func playCalendarAlert() {
        playSystemSound(.calendarAlert)
    }
    
    /// Play reminder alert sound
    func playReminderAlert() {
        playSystemSound(.reminderAlert)
    }
    
    /// Play keyboard click sound
    func playKeyboardClick() {
        playSystemSound(.keyboardClick)
    }
    
    /// Play lock sound
    func playLock() {
        playSystemSound(.lock)
    }
    
    /// Play unlock sound
    func playUnlock() {
        playSystemSound(.unlock)
    }
    
    /// Play photo shutter sound
    func playPhotoShutter() {
        playSystemSound(.photoShutter)
    }
    
    /// Play begin recording sound
    func playBeginRecording() {
        playSystemSound(.beginRecording)
    }
    
    /// Play end recording sound
    func playEndRecording() {
        playSystemSound(.endRecording)
    }
    
    /// Play video call ringing sound
    func playVideoCallRinging() {
        playSystemSound(.vcRinging)
    }
    
    /// Play video call ended sound
    func playVideoCallEnded() {
        playSystemSound(.vcEnded)
    }
    
    /// Play SMS received sound
    func playSMSReceived() {
        playSystemSound(.smsReceived)
    }
    
    /// Play tweet sent sound
    func playTweetSent() {
        playSystemSound(.tweetSent)
    }
}

// MARK: - Extension for Legacy Support

extension SystemSoundManager {
    
    /// Legacy method for backward compatibility - plays incoming call ringtone
    func startRingSound() {
        playIncomingCallRingtone()
    }
    
    /// Legacy method for backward compatibility - stops all sounds
    func stopRingSound() {
        stopAllSounds()
    }
} 