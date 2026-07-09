import AppKit
import Foundation
import Observation
import OSLog

/// A supported localisation whose display name is always shown in its own language
/// (e.g. "日本語", "Français"). The backing string catalog column matches `code`.
struct AppLanguage: Identifiable, Hashable, Sendable {
    let code: String
    let nativeName: String
    var id: String { code }
}

/// Manages the user's chosen language override for Uninstally, the set of
/// supported languages, and the restart required to apply a switch. Backed by the
/// `AppleLanguages` UserDefaults key — Apple's own mechanism for per‑app language
/// overrides — so behaviour matches what users expect from macOS.
///
/// When the chosen language lacks a translation, the standard Apple localisation
/// fallback chain (region → development language → base → English) applies.
///
/// After changing the language, a restart is required because macOS Foundation
/// reads `AppleLanguages` during app initialisation, before any SwiftUI views
/// are created. The selected language persists between launches.
@MainActor
@Observable
final class LanguageManager {
    /// Shared instance — injected by the app; also accessible statically for
    /// view-level convenience.
    static let shared = LanguageManager()

    static let supportedLanguages: [AppLanguage] = [
        AppLanguage(code: "en",      nativeName: "English"),
        AppLanguage(code: "it",      nativeName: "Italiano"),
        AppLanguage(code: "es",      nativeName: "Español"),
        AppLanguage(code: "fr",      nativeName: "Français"),
        AppLanguage(code: "de",      nativeName: "Deutsch"),
        AppLanguage(code: "pt",      nativeName: "Português"),
        AppLanguage(code: "ja",      nativeName: "日本語"),
        AppLanguage(code: "ko",      nativeName: "한국어"),
        AppLanguage(code: "zh-Hans", nativeName: "简体中文"),
        AppLanguage(code: "zh-Hant", nativeName: "繁體中文"),
    ]

    /// The currently active app language. Setting it saves immediately but
    /// requires a restart to take visual effect.
    var current: AppLanguage {
        get {
            let code = UserDefaults.standard.array(forKey: "AppleLanguages")?.first as? String ?? "en"
            return Self.supportedLanguages.first { $0.code == code }
                ?? Self.supportedLanguages.first(where: { code.hasPrefix($0.code) })
                ?? Self.supportedLanguages[0]
        }
        set {
            UserDefaults.standard.set([newValue.code], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            Logger.language.debug("Language changed to: \(newValue.code) (\(newValue.nativeName))")
        }
    }

    /// Set to `true` when the restart dialog is shown.
    var showRestartAlert = false

    /// Called once during app startup, before any SwiftUI views are rendered.
    /// Logs diagnostic information about the active localisation.
    static func applySavedLanguage() {
        let code = UserDefaults.standard.array(forKey: "AppleLanguages")?.first as? String ?? "en"
        let language = Self.supportedLanguages.first { $0.code == code }
            ?? Self.supportedLanguages.first(where: { code.hasPrefix($0.code) })
            ?? Self.supportedLanguages[0]

        Logger.language.debug("""
            LanguageManager.applySavedLanguage() —
              Selected code: \(language.code)
              Native name: \(language.nativeName)
              Bundle preferred localizations: \(Bundle.main.preferredLocalizations)
              Bundle development localization: \(Bundle.main.developmentLocalization ?? "(nil)")
              Available localizations: \(Bundle.main.localizations.joined(separator: ", "))
              Fallback: en
            """)
    }

    /// Switches the language and asks the user to restart.
    func selectLanguage(_ language: AppLanguage) {
        guard language.code != current.code else { return }
        current = language
        showRestartAlert = true
    }

    /// Persists the language change, terminates the current process, and relaunches
    /// the app so the new language takes effect on next launch.
    func restartNow() {
        UserDefaults.standard.synchronize()
        Logger.language.debug("Restarting app with language: \(self.current.code) (\(self.current.nativeName))")

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
