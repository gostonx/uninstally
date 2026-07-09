import AppKit
import SwiftUI

/// Minimal `NSApplicationDelegate` responsible for process-level concerns that
/// SwiftUI does not express directly: the accessory activation policy (no Dock or
/// menu-bar presence), notification authorisation, and forwarding file-open
/// events from Launch Services to the coordinator.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var coordinator: AppCoordinator?
    private var pendingURLs: [URL] = []
    private let trashMonitor = TrashMonitor()

    func attach(_ coordinator: AppCoordinator) {
        self.coordinator = coordinator
        // Flush any file-open events that arrived before the scene was ready.
        if !pendingURLs.isEmpty {
            FinderActionHandler.route(urls: pendingURLs, to: coordinator)
            pendingURLs.removeAll()
        }
        // Route Trash-notification "Scan Leftovers" taps back into the coordinator.
        NotificationService.shared.onScanLeftovers = { [weak coordinator] url in
            coordinator?.scanLeftovers(forTrashedAppAt: url)
        }
    }

    /// Apply the saved language before any SwiftUI views are rendered.
    /// Foundation reads `AppleLanguages` during initialisation, but calling this
    /// here guarantees the correct `Bundle.preferredLocalizations` is set.
    func applicationWillFinishLaunching(_ notification: Notification) {
        LanguageManager.applySavedLanguage()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIconController.applyStoredPreference()
        AppSettings.removeObsoleteDefaults()
        NotificationService.shared.requestAuthorizationIfNeeded()
        trashMonitor.start()
        NotificationCenter.default.addObserver(
            forName: .trashMonitorPreferenceChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.trashMonitor.refresh() }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Handles `.app` bundles opened via "Open With" or dropped on the app.
    /// Multiple files selected at once in Finder arrive as a single call — we batch
    /// them to present the multi‑app chooser.
    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            if let coordinator {
                FinderActionHandler.route(urls: urls, to: coordinator)
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
