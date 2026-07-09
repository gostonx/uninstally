import Foundation
import Observation
import os

/// What the application browser is currently showing: a built-in smart filter or
/// a user-created Collection.
enum BrowserScope: Hashable {
    case filter(SmartFilter)
    case collection(CustomTab)

    var title: String {
        switch self {
        case .filter(let f): return f.rawValue
        case .collection(let tab): return tab.displayName
        }
    }

    var systemImage: String {
        switch self {
        case .filter(let f): return f.systemImage
        case .collection(let tab): return tab.symbol
        }
    }
}

/// Drives the standalone application browser: scanning, searching, sorting and
/// smart filtering. Marked `@MainActor` because it feeds SwiftUI directly; the
/// heavy scanning work is delegated to the `ApplicationScanner` actor-safe struct.
@MainActor
@Observable
final class AppBrowserModel {
    private(set) var apps: [AppInfo] = []
    private(set) var isScanning = false
    private(set) var leftoverIdentifiers: Set<String> = []

    var searchText = ""
    var sort: AppSortOption = .name
    var layout: BrowserLayout = .grid
    var scope: BrowserScope = .filter(.all)
    var selection: Set<AppInfo.ID> = []

    /// Bundle ids that appear on more than one volume.
    private var duplicatedIdentifiers: Set<String> = []

    private let scanner = ApplicationScanner()
    private let leftoverScanner = LeftoverScanner()

    /// Performs the initial (or a refreshed) scan of installed applications.
    func load() async {
        isScanning = true
        defer { isScanning = false }
        let discovered = await scanner.scan()
        apps = AppSortOption.name.sorted(discovered)
        computeDuplicates()
        // Leftover detection runs opportunistically in the background.
        Task { await self.refreshLeftoverIndex() }
    }

    /// Rebuilds the index of which installed apps still have detectable leftovers.
    private func refreshLeftoverIndex() async {
        let leftovers = await leftoverScanner.scan(installedApps: apps)
        leftoverIdentifiers = Set(leftovers.map { $0.associatedIdentifier.lowercased() })
    }

    private func computeDuplicates() {
        var counts: [String: Int] = [:]
        for app in apps where !app.bundleIdentifier.isEmpty {
            counts[app.bundleIdentifier, default: 0] += 1
        }
        duplicatedIdentifiers = Set(counts.filter { $0.value > 1 }.keys)
    }

    /// The apps that survive the active scope, then search, then sort.
    var visibleApps: [AppInfo] {
        var result: [AppInfo]
        switch scope {
        case .filter(let filter):
            result = applyFilter(filter, to: apps)
        case .collection(let tab):
            let keys = Set(tab.appKeys)
            result = apps.filter { keys.contains($0.collectionKey) }
        }
        if !searchText.isEmpty {
            let query = searchText
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.developer.localizedCaseInsensitiveContains(query)
                    || $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
            }
        }
        return sort.sorted(result)
    }

    /// Pure smart-filter application, free of side effects so it can be reused for
    /// sidebar badge counts without mutating observable state.
    private func applyFilter(_ filter: SmartFilter, to apps: [AppInfo]) -> [AppInfo] {
        switch filter {
        case .all:
            return apps
        case .largest:
            return Array(AppSortOption.size.sorted(apps).prefix(25))
        case .recentlyInstalled:
            let cutoff = Date().addingTimeInterval(-60 * 60 * 24 * 30)
            return apps.filter { ($0.installDate ?? .distantPast) > cutoff }
        case .recentlyOpened:
            let cutoff = Date().addingTimeInterval(-60 * 60 * 24 * 14)
            return apps.filter { ($0.lastUsedDate ?? .distantPast) > cutoff }
        case .neverOpened:
            return apps.filter { app in
                guard let used = app.lastUsedDate, let installed = app.installDate else {
                    return app.lastUsedDate == nil
                }
                // "Never opened" ≈ last-used within a minute of install.
                return used.timeIntervalSince(installed) < 60
            }
        case .withLeftovers:
            return apps.filter { leftoverIdentifiers.contains($0.bundleIdentifier.lowercased()) }
        case .brokenInstalls:
            return apps.filter(\.isBrokenInstall)
        case .duplicated:
            return apps.filter { duplicatedIdentifiers.contains($0.bundleIdentifier) }
        }
    }

    /// Total size of the current selection, for the batch-uninstall summary.
    var selectedSizeBytes: Int64 {
        apps.filter { selection.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedApps: [AppInfo] {
        apps.filter { selection.contains($0.id) }
    }

    func count(for filter: SmartFilter) -> Int {
        applyFilter(filter, to: apps).count
    }

    /// Number of installed apps currently filed in a Collection.
    func count(inCollection tab: CustomTab) -> Int {
        let keys = Set(tab.appKeys)
        return apps.filter { keys.contains($0.collectionKey) }.count
    }

    /// The set of collection keys for every installed app, used to prune
    /// Collections after uninstalls.
    var installedKeys: Set<String> {
        Set(apps.map(\.collectionKey))
    }
}
