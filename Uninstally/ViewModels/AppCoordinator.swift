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

        static func == (lhs: Route, rhs: Route) -> Bool {
            switch (lhs, rhs) {
            case (.browser, .browser): return true
            case let (.uninstall(a), .uninstall(b)): return a === b
            case let (.batch(a), .batch(b)): return a === b
            default: return false
            }
        }
    }

    private(set) var route: Route = .browser

    /// `true` once a Finder-initiated uninstall has been routed. Governs whether we
    /// terminate after completion.
    private(set) var launchedFromFinder = false

    let browserModel = AppBrowserModel()
    private let scanner = ApplicationScanner()

    // MARK: - Standalone navigation

    func showBrowser() {
        route = .browser
    }

    func startUninstall(for app: AppInfo) {
        let model = UninstallModel(app: app, isDedicatedSession: false)
        route = .uninstall(model)
    }

    func startBatch(for apps: [AppInfo]) {
        route = .batch(BatchUninstallModel(apps: apps))
    }

    // MARK: - Finder entry point

    /// Entry point for URLs delivered by SwiftUI's `onOpenURL` or the app delegate.
    /// Accepts either a `file://…/Foo.app` URL or the custom
    /// `uninstally://uninstall?path=<percent-encoded path>` scheme used by the
    /// Finder extension.
    func open(_ url: URL) {
        if url.isFileURL {
            handleFinderOpen(bundleURL: url)
            return
        }
        guard url.scheme == "uninstally" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let path = components?.queryItems?.first(where: { $0.name == "path" })?.value {
            handleFinderOpen(bundleURL: URL(fileURLWithPath: path))
        }
    }

    /// Handles a bundle URL passed by Finder (via the Finder extension or "Open
    /// With"). Inspects the bundle and routes directly into a dedicated uninstall.
    func handleFinderOpen(bundleURL: URL) {
        guard bundleURL.pathExtension == "app" else {
            Logger.app.error("Ignoring non-app URL from Finder: \(bundleURL.path, privacy: .public)")
            return
        }
        launchedFromFinder = true
        NSApp.activate(ignoringOtherApps: true)
        guard let app = scanner.inspect(bundleURL: bundleURL) else {
            Logger.app.error("Could not inspect bundle: \(bundleURL.path, privacy: .public)")
            return
        }
        let model = UninstallModel(app: app, isDedicatedSession: true)
        route = .uninstall(model)
    }

    /// Called when an uninstall completes. Terminates the app if this was a
    /// dedicated Finder session and nothing else is going on.
    func uninstallDidFinish(dedicated: Bool) {
        guard dedicated, launchedFromFinder else { return }
        // Leave the completion screen up briefly, then quit.
        Task {
            try? await Task.sleep(for: .seconds(6))
            NSApp.terminate(nil)
        }
    }
}
