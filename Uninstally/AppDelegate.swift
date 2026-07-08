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
        // No Dock icon, no menu-bar item — appears only via windows we present.
        NSApp.setActivationPolicy(.accessory)
        NotificationService.shared.requestAuthorizationIfNeeded()
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
