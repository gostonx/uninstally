import AppKit
import SwiftUI

/// Minimal `NSApplicationDelegate` responsible for process-level concerns that
/// SwiftUI does not express directly: the accessory activation policy (no Dock or
/// menu-bar presence), notification authorisation, and forwarding file-open
/// events from Launch Services to the coordinator.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var coordinator: AppCoordinator?
    private var pendingURLs: [URL] = []

    @MainActor
    func attach(_ coordinator: AppCoordinator) {
        self.coordinator = coordinator
        // Flush any file-open events that arrived before the scene was ready.
        for url in pendingURLs { coordinator.open(url) }
        pendingURLs.removeAll()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply the user's Dock-icon preference (defaults to accessory: no Dock or
        // menu-bar presence).
        DockIconController.applyStoredPreference()
        AppSettings.removeObsoleteDefaults()
        NotificationService.shared.requestAuthorizationIfNeeded()
        // Even as an accessory app, bring our window to the front on a normal
        // launch so it doesn't open hidden behind other windows.
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Handles `.app` bundles opened via "Open With" or dropped on the app.
    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            if let coordinator {
                for url in urls { coordinator.open(url) }
            } else {
                pendingURLs.append(contentsOf: urls)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Keep running when the last window closes only during a normal session; a
    /// dedicated Finder uninstall terminates itself on completion.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
