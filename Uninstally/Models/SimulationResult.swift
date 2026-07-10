import Foundation
import Observation

/// The complete output of an uninstall simulation: categorised artefacts, storage
/// breakdown, risk indicators, per-file metadata and a bridge back to
/// `RemovableItem`/`UninstallPlan` so the engine can execute without rescanning.
@Observable
final class SimulationResult {
    let app: AppInfo
    /// Categories ordered by `RemovalCategory.order`.
    let categories: [SimulationCategory]
    /// Every file across every category, kept as a flat list for search.
    let allFiles: [SimulationFile]
    /// How many discovered artefacts were excluded because they failed validation.
    let rejectedCount: Int
    /// Computed after the deletion plan is validated.
    var safetyScore: SafetyScore?

    init(app: AppInfo, items: [RemovableItem], rejectedCount: Int = 0) {
        self.app = app
        self.rejectedCount = rejectedCount
        let grouped = Dictionary(grouping: items.map(SimulationFile.init), by: \.category)
        self.categories = grouped
            .map { SimulationCategory(removalCategory: $0.key, files: $0.value) }
            .sorted { $0.removalCategory.order < $1.removalCategory.order }
        self.allFiles = self.categories.flatMap(\.files)
    }

    func category(_ c: RemovalCategory) -> SimulationCategory? {
        categories.first { $0.removalCategory == c }
    }

    // MARK: - Storage buckets

    enum StorageBucket: String, CaseIterable, Identifiable {
        case application, support, caches, preferences, other
        var id: String { rawValue }
        var title: String {
            switch self {
            case .application: return "Main Bundle"
            case .support: return "Support Files"
            case .caches: return "Caches"
            case .preferences: return "Preferences"
            case .other: return "Other"
            }
        }
    }

    func bucket(for category: RemovalCategory) -> StorageBucket {
        switch category {
        case .application: return .application
        case .caches, .temporary: return .caches
        case .preferences, .savedState: return .preferences
        case .other: return .other
        default: return .support
        }
    }

    func bucketBytes(_ bucket: StorageBucket) -> Int64 {
        allFiles.filter { self.bucket(for: $0.category) == bucket }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    // MARK: - Summary counts

    var applicationCount: Int    { category(.application)?.files.count ?? 0 }
    var relatedFileCount: Int    { totalFiles - applicationCount }
    var loginItemCount: Int      { category(.loginItems)?.files.count ?? 0 }
    var launchAgentCount: Int    { category(.launchAgents)?.files.count ?? 0 }
    var launchDaemonCount: Int   { category(.launchDaemons)?.files.count ?? 0 }
    var privilegedHelperCount: Int { category(.privilegedHelper)?.files.count ?? 0 }
    var extensionCount: Int      { category(.extensions)?.files.count ?? 0 }
    var cacheFolderCount: Int    { category(.caches)?.files.count ?? 0 }
    var prefFileCount: Int       { category(.preferences)?.files.count ?? 0 }
    var savedStateCount: Int     { category(.savedState)?.files.count ?? 0 }
    var containerCount: Int      { category(.containers)?.files.count ?? 0 }
    var groupContainerCount: Int { category(.groupContainers)?.files.count ?? 0 }
    var backgroundComponentCount: Int { launchAgentCount + launchDaemonCount + privilegedHelperCount }

    // MARK: - Derived totals

    var totalFiles: Int      { allFiles.count }
    var totalSelected: Int   { allFiles.filter(\.isSelected).count }
    var totalBytes: Int64    { allFiles.reduce(0) { $0 + $1.sizeBytes } }
    var selectedBytes: Int64 { allFiles.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes } }
    var requiresAdmin: Bool  { allFiles.contains { $0.requiresAdmin && $0.isSelected } }
    var riskCategories: [SimulationCategory] { categories.filter(\.isRisk) }
    var riskFiles: [SimulationFile] { allFiles.filter(\.isShared) }

    /// IDs of the application bundle itself, which must remain selected.
    var protectedIDs: Set<UUID> {
        Set(category(.application)?.files.map(\.id) ?? [])
    }

    /// A rough estimate of how long the removal will take.
    var estimatedDurationSec: Double {
        let perFile = 0.08, perMB = 0.03
        return max(1.5, perFile * Double(totalSelected) + perMB * Double(totalBytes) / 1_000_000)
    }

    var reportStats: [(label: String, value: String)] {
        [
            ("Total Files", "\(totalFiles)"),
            ("Recoverable", Format.bytes(selectedBytes)),
            ("Categories", "\(categories.count)"),
            ("Background Components", "\(backgroundComponentCount)"),
            ("Login Items", "\(loginItemCount)"),
            ("Services", "\(launchDaemonCount + privilegedHelperCount)"),
            ("Containers", "\(containerCount + groupContainerCount)"),
            ("Preferences", "\(prefFileCount)"),
            ("Caches", "\(cacheFolderCount)"),
            ("Estimated Time", Format.duration(estimatedDurationSec)),
        ]
    }

    /// Every file converted back to immutable `RemovableItem`s, preserving each
    /// selection (the application bundle is always kept). Lets the engine run
    /// without a second scan.
    var asRemovableItems: [RemovableItem] {
        let protected = protectedIDs
        return allFiles.map { file in
            RemovableItem(
                category: file.category,
                url: file.url,
                sizeBytes: file.sizeBytes,
                requiresAdmin: file.requiresAdmin,
                isSelected: file.isSelected || protected.contains(file.id),
                matchReason: file.matchReason
            )
        }
    }
}
