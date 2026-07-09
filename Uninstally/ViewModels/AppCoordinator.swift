import AppKit
import Foundation
import Observation
import os

/// Top-level navigation coordinator. Owns the current route and knows whether the
/// current launch is a one-shot uninstall from Finder (in which case the app quits
/// on completion) or a normal standalone session.
@MainActor
@Observable
final class AppCoordinator {

    enum Route: Equatable {
        case browser
        case uninstall(UninstallModel)
        case batch(BatchUninstallModel)
        case finderSelection([AppInfo])

        static func == (lhs: Route, rhs: Route) -> Bool {
            switch (lhs, rhs) {
            case (.browser, .browser): return true
            case let (.uninstall(a), .uninstall(b)): return a === b
            case let (.batch(a), .batch(b)): return a === b
            case let (.finderSelection(a), .finderSelection(b)): return a == b
            default: return false
            }
        }
    }

    private(set) var route: Route = .browser

    /// `true` once a Finder-initiated action has been routed. Governs whether we
    /// terminate after completion.
    private(set) var launchedFromFinder = false

    /// Remaining apps to review one-by-one (from a multi-selection Finder action).
    private var individualQueue: [AppInfo] = []

    let browserModel = AppBrowserModel()
    private let scanner = ApplicationScanner()

    // MARK: - Standalone navigation

    func showBrowser() {
        route = .browser
    }

    func startUninstall(for app: AppInfo, dedicated: Bool = false) {
        route = .uninstall(UninstallModel(app: app, isDedicatedSession: dedicated))
    }

    func startBatch(for apps: [AppInfo]) {
        route = .batch(BatchUninstallModel(apps: apps))
    }

    func showInspector(for app: AppInfo) {
        inspectorApp = app
    }

    var inspectorApp: AppInfo?

    /// Returns from a completed single uninstall: optimistically drops the removed
    /// app, then continues an individual-review queue or returns to the browser.
    func finishedUninstall(removed appID: AppInfo.ID?) {
        if let appID { browserModel.remove(id: appID) }
        browserModel.selection.removeAll()

        if !individualQueue.isEmpty {
            let next = individualQueue.removeFirst()
            startUninstall(for: next, dedicated: false)
        } else if launchedFromFinder {
            scheduleTerminate()
        } else {
            showBrowser()
        }
    }

    // MARK: - Finder entry points

    /// Entry point for URLs delivered by SwiftUI's `onOpenURL` or the app delegate.
    func open(_ url: URL) {
        handleFinderSelection(bundleURLs: SelectionReceiver.appBundleURLs(from: url))
    }

    /// Handles one or more `.app` bundles selected in Finder. A single app goes
    /// straight into its simulation; multiple apps present a chooser.
    func handleFinderSelection(bundleURLs: [URL]) {
        let appURLs = bundleURLs.filter { $0.pathExtension == "app" }
        guard !appURLs.isEmpty else {
            Logger.app.error("Ignoring Finder selection with no app bundles.")
            return
        }
        launchedFromFinder = true
        NSApp.activate(ignoringOtherApps: true)

        let apps = appURLs.compactMap { scanner.inspect(bundleURL: $0) }
        guard !apps.isEmpty else { return }

        if apps.count == 1 {
            startUninstall(for: apps[0], dedicated: true)
        } else {
            route = .finderSelection(apps)
        }
    }

    /// Back-compat entry used by tests/URL parsing for a single bundle.
    func handleFinderOpen(bundleURL: URL) {
        handleFinderSelection(bundleURLs: [bundleURL])
    }

    // MARK: - Multi-selection chooser actions

    func uninstallAllSelected(_ apps: [AppInfo]) {
        startBatch(for: apps)
    }

    func reviewIndividually(_ apps: [AppInfo]) {
        guard !apps.isEmpty else { return }
        individualQueue = Array(apps.dropFirst())
        startUninstall(for: apps[0], dedicated: false)
    }

    func cancelFinderSelection() {
        individualQueue.removeAll()
        if launchedFromFinder { scheduleTerminate() } else { showBrowser() }
    }

    // MARK: - Trash monitor

    /// Invoked when the user taps "Scan Leftovers" on the Trash notification. The
    /// bundle already lives in the Trash; we inspect it there and run the normal
    /// (non-destructive) simulation so the user can review and remove leftovers.
    func scanLeftovers(forTrashedAppAt url: URL) {
        NSApp.activate(ignoringOtherApps: true)
        guard let app = scanner.inspect(bundleURL: url) else {
            Logger.app.error("Could not inspect trashed bundle: \(url.path, privacy: .public)")
            return
        }
        startUninstall(for: app, dedicated: false)
    }

    // MARK: - Termination

    /// Called when an uninstall completes for a dedicated Finder session.
    func uninstallDidFinish(dedicated: Bool) {
        guard individualQueue.isEmpty else { return } // queue handled in finishedUninstall
        guard dedicated, launchedFromFinder else { return }
        scheduleTerminate()
    }

    private func scheduleTerminate() {
        Task {
            try? await Task.sleep(for: .seconds(6))
            NSApp.terminate(nil)
        }
    }
}
