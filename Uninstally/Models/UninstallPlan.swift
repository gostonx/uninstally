import Foundation

/// The complete, reviewed plan for removing an application: the app itself plus
/// every associated artefact discovered by the smart scanner.
struct UninstallPlan: Identifiable, Sendable {
    let id = UUID()
    let app: AppInfo
    var items: [RemovableItem]

    /// Items the user has chosen to remove.
    var selectedItems: [RemovableItem] {
        items.filter(\.isSelected)
    }

    /// Total bytes that will be reclaimed given the current selection.
    var reclaimableBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Total bytes across everything discovered, regardless of selection.
    var totalDiscoveredBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedCount: Int { selectedItems.count }

    var requiresAdmin: Bool {
        selectedItems.contains { $0.requiresAdmin }
    }

    /// Items grouped by category and sorted for display.
    var groupedItems: [(category: RemovalCategory, items: [RemovableItem])] {
        Dictionary(grouping: items, by: \.category)
            .map { (category: $0.key, items: $0.value.sorted { $0.sizeBytes > $1.sizeBytes }) }
            .sorted { $0.category.order < $1.category.order }
    }
}
