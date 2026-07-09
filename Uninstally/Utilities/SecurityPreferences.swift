import Foundation

/// Centralised access to the security-relevant user preferences, so every scanner
/// and workflow reads them consistently (and safe defaults apply).
enum SecurityPreferences {
    /// Whether a confirmation must be accepted before any deletion. Default `true`.
    static var requireConfirmation: Bool {
        UserDefaults.standard.object(forKey: AppSettings.requireConfirmationKey) as? Bool ?? true
    }

    /// Whether scanners may look in system-level (`/Library`) locations. Default `true`.
    static var scanSystemLevel: Bool {
        UserDefaults.standard.object(forKey: AppSettings.scanSystemLevelKey) as? Bool ?? true
    }
}
