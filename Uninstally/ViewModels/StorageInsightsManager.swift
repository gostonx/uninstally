import Foundation
import Observation

/// Backs the Storage Insights dashboard. Builds `StorageStatistics` from the
/// installed apps and uninstall history (synchronously — it's cheap), and scans
/// for the largest orphaned leftovers asynchronously so the UI stays responsive.
///
/// Statistics update automatically after every uninstall because their inputs
/// (the in-memory app list and the SwiftData history) update.
@MainActor
@Observable
final class StorageInsightsManager {
    private(set) var statistics = StorageStatistics()
    private(set) var largestLeftovers: [LeftoverItem] = []
    private(set) var isScanningLeftovers = false

    private let leftoverScanner = LeftoverScanner()
    private var lastLeftoverScan: Date?

    /// Recomputes statistics for the given inputs. Leftovers are only rescanned
    /// occasionally (they're expensive) unless `forceLeftovers` is set.
    func rebuild(apps: [AppInfo], records: [UninstallRecord], forceLeftovers: Bool = false) {
        statistics = StorageStatistics.build(apps: apps, records: records)

        let stale = lastLeftoverScan.map { Date().timeIntervalSince($0) > 300 } ?? true
        if (forceLeftovers || stale), !isScanningLeftovers, !apps.isEmpty {
            scanLeftovers(installedApps: apps)
        }
    }

    private func scanLeftovers(installedApps: [AppInfo]) {
        isScanningLeftovers = true
        Task {
            let found = await leftoverScanner.scan(installedApps: installedApps)
            self.largestLeftovers = Array(found.sorted { $0.sizeBytes > $1.sizeBytes }.prefix(25))
            self.lastLeftoverScan = Date()
            self.isScanningLeftovers = false
        }
    }
}
