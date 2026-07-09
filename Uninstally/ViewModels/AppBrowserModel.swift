import Foundation
import Observation

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
    /// Incremented on every manual refresh request; only the newest value is used,
    /// so rapid consecutive taps are coalesced.
    private var refreshGeneration = 0
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
        let generation = refreshGeneration
        isScanning = true
        defer {
            if refreshGeneration == generation { isScanning = false }
        }
        var discovered = await scanner.scan()
        // Track size changes from previous scan
        let oldSizes = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0.sizeBytes) })
        for i in discovered.indices {
            let id = discovered[i].id
            if let old = oldSizes[id], old != discovered[i].sizeBytes {
                discovered[i].previousSizeBytes = old
            }
        }
        apps = AppSortOption.name.sorted(discovered)
        computeDuplicates()
        // Leftover detection and source detection run in the background.
        Task { await self.refreshLeftoverIndex() }
        Task { await self.detectInstallationSources() }
    }

    private func detectInstallationSources() async {
        let detector = InstallationSourceDetector()
        for i in apps.indices {
            if apps[i].installationSource != .unknown { continue }
            let source = await detector.detect(
                for: apps[i].url,
                bundleIdentifier: apps[i].bundleIdentifier
            )
            apps[i].installationSource = source
        }
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
    /// When the scope already has an intrinsic ordering (e.g. `.largest` is
    /// always size-descending), the global `sort` control is ignored.
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
        // Smart filters that produce their own ordering should not be re-sorted
        // by the global sort picker — that would defeat the filter's purpose.
        let effectiveSort: AppSortOption = {
            if case .filter(.largest) = scope            { return .size }
            if case .filter(.recentlyInstalled) = scope  { return .installDate }
            if case .filter(.recentlyOpened) = scope     { return .recentlyUsed }
            return sort
        }()
        return effectiveSort.sorted(result)
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
            return AppSortOption.installDate.sorted(
                apps.filter { ($0.installDate ?? .distantPast) > cutoff }
            )
        case .recentlyOpened:
            let cutoff = Date().addingTimeInterval(-60 * 60 * 24 * 14)
            return AppSortOption.recentlyUsed.sorted(
                apps.filter { ($0.lastUsedDate ?? .distantPast) > cutoff }
            )
        case .withLeftovers:
            return apps.filter { leftoverIdentifiers.contains($0.bundleIdentifier.lowercased()) }
        case .brokenInstalls:
            return apps.filter(\.isBrokenInstall)
        case .duplicated:
            return apps.filter { duplicatedIdentifiers.contains($0.bundleIdentifier) }
        case .homebrewApps:
            return apps.filter { $0.installationSource == .homebrewCask }
        case .appStoreApps:
            return apps.filter { $0.installationSource == .macAppStore }
        case .dmgApps:
            return apps.filter { $0.installationSource == .dmgInstaller }
        case .pkgApps:
            return apps.filter { $0.installationSource == .pkgInstaller }
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

    // MARK: - Optimistic removal

    /// Removes apps from the in-memory model immediately after a successful
    /// uninstall, without triggering a full filesystem rescan. Every derived value
    /// (visible list, sidebar counts, Collection counts, sizes) updates instantly
    /// because they are computed from `apps`.
    func remove(ids: Set<AppInfo.ID>) {
        guard !ids.isEmpty else { return }
        apps.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        duplicatedIdentifiers = duplicatedIdentifiers.filter { key in
            apps.contains { $0.bundleIdentifier == key }
        }
    }

    func remove(id: AppInfo.ID) {
        remove(ids: [id])
    }
}
