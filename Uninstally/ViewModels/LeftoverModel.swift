import Foundation
import Observation

/// Backs the Leftover Scanner screen: scans for orphaned artefacts, tracks
/// selection, and removes the chosen items via the shared uninstall engine.
@MainActor
@Observable
final class LeftoverModel {
    private(set) var items: [LeftoverItem] = []
    private(set) var isScanning = false
    private(set) var isRemoving = false
    private(set) var lastReclaimed: Int64?

    var searchText = ""

    private let scanner = LeftoverScanner()
    private let appScanner = ApplicationScanner()

    var filteredItems: [LeftoverItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.associatedIdentifier.localizedCaseInsensitiveContains(searchText)
                || $0.displayPath.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedItems: [LeftoverItem] { items.filter(\.isSelected) }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.sizeBytes } }
    var totalBytes: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }

    var groupedItems: [(category: RemovalCategory, items: [LeftoverItem])] {
        Dictionary(grouping: filteredItems, by: \.category)
            .map { (category: $0.key, items: $0.value.sorted { $0.sizeBytes > $1.sizeBytes }) }
            .sorted { $0.category.order < $1.category.order }
    }

    func scan() async {
        isScanning = true
        defer { isScanning = false }
        let apps = await appScanner.scan()
        items = await scanner.scan(installedApps: apps)
    }

    func setSelection(_ id: LeftoverItem.ID, isSelected: Bool) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isSelected = isSelected
        }
    }

    func selectAll(_ selected: Bool) {
        for index in items.indices { items[index].isSelected = selected }
    }

    func removeSelected() async {
        let selected = selectedItems
        guard !selected.isEmpty else { return }
        isRemoving = true
        defer { isRemoving = false }

        // Reuse the engine by wrapping leftovers in a synthetic plan.
        let removable = selected.map {
            RemovableItem(
                category: $0.category,
                url: $0.url,
                sizeBytes: $0.sizeBytes,
                requiresAdmin: $0.requiresAdmin,
                matchReason: "Orphaned file"
            )
        }
        let syntheticApp = AppInfo(
            url: URL(fileURLWithPath: "/"), name: "Leftover Files", bundleIdentifier: "",
            version: "", buildVersion: "", developer: "", sizeBytes: 0,
            installDate: nil, lastUsedDate: nil, volumeName: nil,
            isBrokenInstall: false, extraBundleIdentifiers: []
        )
        let plan = UninstallPlan(app: syntheticApp, items: removable)
        let engine = UninstallEngine()
        var reclaimed: Int64 = 0
        for await event in engine.run(plan: plan, mode: DeletionMode.stored) {
            if case .finished(let result) = event { reclaimed = result.reclaimedBytes }
        }
        lastReclaimed = reclaimed
        let removedIDs = Set(selected.map(\.url.standardizedFileURL.path))
        items.removeAll { removedIDs.contains($0.url.standardizedFileURL.path) }
    }
}
