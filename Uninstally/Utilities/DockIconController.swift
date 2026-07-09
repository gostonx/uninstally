import AppKit
import Foundation

/// Keys for user-facing preferences persisted in `UserDefaults`.
enum AppSettings {
    /// Whether Uninstally shows an icon in the Dock. Defaults to `false`, keeping
    /// the app as a lightweight accessory unless the user opts in.
    static let showDockIconKey = "showDockIcon"

    // MARK: Uninstall

    /// How removed files are disposed of: `trash` or `permanent` (see `DeletionMode`).
    static let deletionModeKey = "deletionMode"
    /// Quit automatically after a Finder-initiated uninstall completes.
    static let quitAfterFinderKey = "quitAfterFinderUninstall"

    // MARK: History

    /// Whether uninstall history is recorded. Defaults to `true`.
    static let keepHistoryKey = "keepUninstallHistory"
    /// How long history is retained (see `HistoryRetention`).
    static let historyRetentionKey = "historyRetention"
    /// Whether the Recently Uninstalled item appears in the sidebar. Defaults `true`.
    static let showRecentlyUninstalledKey = "showRecentlyUninstalled"
    /// Whether the Storage Insights item appears in the sidebar. Defaults `true`.
    static let showStorageInsightsKey = "showStorageInsights"
    /// Whether Uninstally watches the Trash for deleted apps. Defaults `true`.
    static let monitorTrashKey = "monitorTrash"

    // MARK: Scanning

    /// Include system-level `/Library` locations when scanning (needs admin to remove).
    static let scanSystemLevelKey = "scanIncludeSystemLevel"
    /// Automatically scan for leftover files in the background.
    static let autoScanLeftoversKey = "autoScanLeftovers"

    // MARK: Security

    /// Always require an explicit confirmation before deleting.
    static let requireConfirmationKey = "requireDeleteConfirmation"

    // MARK: Applications sidebar

    /// JSON-encoded array of `AppSidebarItemConfig` describing the main
    /// Applications sidebar order, visibility and pinned state.
    static let appSidebarKey = "appSidebarConfiguration"
    /// Whether the main Applications sidebar is collapsed.
    static let appSidebarCollapsedKey = "appSidebarCollapsed"
    /// JSON-encoded array of `CustomTab` (user-created Collections).
    static let customTabsKey = "customCollections"

    // MARK: Updates

    /// Selected update channel (`stable`, `beta`, `nightly`).
    static let updateChannelKey = "updateChannel"
    /// Whether pre-release (beta/nightly) updates are offered.
    static let receiveBetaUpdatesKey = "receiveBetaUpdates"

    /// Removes obsolete preferences left over from removed features (e.g. the
    /// former haptic-feedback toggle), keeping existing installs tidy.
    static func removeObsoleteDefaults() {
        UserDefaults.standard.removeObject(forKey: "hapticsEnabled")
    }
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
