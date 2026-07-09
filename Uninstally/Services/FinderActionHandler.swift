import Foundation

/// Bridges inbound Finder actions to the app's coordinator, keeping Finder
/// integration decoupled from navigation and the uninstall engine. The
/// `AppDelegate` and the app's `onOpenURL` handler route through here.
@MainActor
enum FinderActionHandler {
    /// Routes a single inbound URL (custom scheme or file) to the coordinator.
    static func route(url: URL, to coordinator: AppCoordinator) {
        let bundles = SelectionReceiver.appBundleURLs(from: url)
        guard !bundles.isEmpty else { return }
        coordinator.handleFinderSelection(bundleURLs: bundles)
    }

    /// Routes a batch of file URLs (e.g. multi-select "Open With") as one selection.
    static func route(urls: [URL], to coordinator: AppCoordinator) {
        let bundles = SelectionReceiver.appBundleURLs(from: urls)
        guard !bundles.isEmpty else { return }
        coordinator.handleFinderSelection(bundleURLs: bundles)
    }
}
