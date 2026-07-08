import AppKit
import Foundation

/// Keys for user-facing preferences persisted in `UserDefaults`.
enum AppSettings {
    /// Whether Uninstally shows an icon in the Dock. Defaults to `false`, keeping
    /// the app as a lightweight accessory unless the user opts in.
    static let showDockIconKey = "showDockIcon"
}

/// Applies the Dock-icon preference by switching the process activation policy.
///
/// An app built with `LSUIElement` starts as an accessory (no Dock icon, no menu
/// bar). Calling `setActivationPolicy(.regular)` at runtime promotes it to a
/// standard app with a Dock icon and menu bar; `.accessory` hides both again.
@MainActor
enum DockIconController {
    /// Reads the stored preference and applies it.
    static func applyStoredPreference() {
        apply(showDockIcon: UserDefaults.standard.bool(forKey: AppSettings.showDockIconKey))
    }

    /// Applies an explicit value.
    static func apply(showDockIcon: Bool) {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        if showDockIcon {
            // Bring the app forward so the newly shown Dock icon reflects an active app.
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
