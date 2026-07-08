import Cocoa
import FinderSync
import os

/// Finder Sync extension providing the **"Uninstall with Uninstally"** contextual
/// menu item for `.app` bundles anywhere on the system.
///
/// The extension does no scanning itself. When invoked it hands the selected
/// bundle to the main application through the private `uninstally://` URL scheme,
/// which launches Uninstally straight into its uninstall confirmation flow. This
/// keeps the (sandboxed) extension tiny and lets all privileged work happen in the
/// main app.
final class FinderSync: FIFinderSync {

    private let logger = Logger(subsystem: "com.codenta.uninstally.finder", category: "extension")

    override init() {
        super.init()
        // Observe the whole file system so the menu is available wherever a user
        // right-clicks an application bundle (Applications, ~/Applications,
        // external drives, arbitrary folders).
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else { return nil }
        let appBundles = selectedAppBundles()
        guard !appBundles.isEmpty else { return nil }

        let menu = NSMenu(title: "")
        let title = appBundles.count == 1
            ? "Uninstall with Uninstally"
            : "Uninstall \(appBundles.count) Apps with Uninstally"
        let item = NSMenuItem(title: title, action: #selector(uninstallSelected(_:)), keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Uninstall")
        item.target = self
        menu.addItem(item)
        return menu
    }

    // MARK: - Action

    @objc private func uninstallSelected(_ sender: AnyObject?) {
        for bundle in selectedAppBundles() {
            guard var components = URLComponents(string: "uninstally://uninstall") else { continue }
            components.queryItems = [URLQueryItem(name: "path", value: bundle.path)]
            guard let url = components.url else { continue }
            NSWorkspace.shared.open(url)
            logger.log("Requested uninstall for \(bundle.path, privacy: .public)")
        }
    }

    // MARK: - Helpers

    /// Returns the currently selected items that are `.app` bundles.
    private func selectedAppBundles() -> [URL] {
        let selected = FIFinderSyncController.default().selectedItemURLs() ?? []
        return selected.filter { $0.pathExtension == "app" }
    }
}
