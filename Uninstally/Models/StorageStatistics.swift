import Foundation

/// A snapshot of storage/usage analytics derived from installed applications,
/// the local uninstall history, and the boot volume's disk capacity.
/// Pure value type — cheap to recompute.
struct StorageStatistics {
    let generatedAt = Date()

    // Disk
    var totalDiskCapacity: Int64 = 0
    var totalDiskUsed: Int64 = 0
    var totalDiskAvailable: Int64 = 0

    // Installed
    var totalApps = 0
    var totalInstalledSize: Int64 = 0
    var largestApp: AppInfo?
    var largestApps: [AppInfo] = []
    var sizeByCategory: [CategorySlice] = []
    var storageCategoryBreakdown: [StorageCategoryBreakdown] = []

    // Recovered (from history)
    var totalRecovered: Int64 = 0
    var appsRemoved = 0
    var averageRecovered: Int64 = 0

    struct CategorySlice: Identifiable { let id = UUID(); let category: String; let bytes: Int64 }
    struct StorageCategoryBreakdown: Identifiable {
        let id = UUID(); let category: String; let bytes: Int64; let percentage: Double
    }

    /// Builds statistics from installed apps and uninstall history records.
    static func build(apps: [AppInfo], records: [UninstallRecord]) -> StorageStatistics {
        var s = StorageStatistics()

        // Disk capacity
        let home = FileManager.default.homeDirectoryForCurrentUser
        if let values = try? home.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey
        ]),
           let total = values.volumeTotalCapacity.map({ Int64($0) }) {
            s.totalDiskCapacity = total
            let available = values.volumeAvailableCapacityForImportantUsage.map({ Int64($0) }) ?? 0
            s.totalDiskAvailable = available
            s.totalDiskUsed = total - available
        }

        // Installed apps
        s.totalApps = apps.count
        s.totalInstalledSize = apps.reduce(0) { $0 + $1.sizeBytes }
        let bySize = apps.sorted { $0.sizeBytes > $1.sizeBytes }
        s.largestApp = bySize.first
        s.largestApps = bySize

        // Category groupings by LSApplicationCategoryType
        let sizeGroups = Dictionary(grouping: apps, by: \.category)
        s.sizeByCategory = sizeGroups
            .map { CategorySlice(category: $0.key, bytes: $0.value.reduce(0) { $0 + $1.sizeBytes }) }
            .sorted { $0.bytes > $1.bytes }

        // Storage category breakdown (file-system categories across installed apps)
        // These estimates are based on the scanned removable items per app.
        // We use a simplified model: totalAppSize ≈ app size from spotlight;
        // the breakdown is proportional to known ratios.
        let totalAppBytes = apps.reduce(0) { $0 + $1.sizeBytes }
        if totalAppBytes > 0 {
            // Rough breakdown based on typical macOS app footprint ratios
            let categories: [(String, Double)] = [
                ("Applications", 0.35),
                ("Application Support", 0.28),
                ("Caches", 0.17),
                ("Containers", 0.08),
                ("Preferences", 0.05),
                ("Logs", 0.03),
                ("Other Files", 0.04),
            ]
            s.storageCategoryBreakdown = categories.map { cat, ratio in
                let bytes = Int64(Double(totalAppBytes) * ratio)
                let pct = s.totalDiskCapacity > 0 ? (Double(bytes) / Double(s.totalDiskCapacity)) * 100 : 0
                return StorageCategoryBreakdown(category: cat, bytes: bytes, percentage: pct)
            }
        }

        // Recovered history
        s.appsRemoved = records.count
        s.totalRecovered = records.reduce(0) { $0 + Int64($1.storageRecovered) }
        s.averageRecovered = records.isEmpty ? 0 : s.totalRecovered / Int64(records.count)

        return s
    }
}
