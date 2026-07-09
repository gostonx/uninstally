import Foundation
import Observation

/// A named, expandable group of `SimulationFile`s — e.g. "Caches", "Preferences".
/// Tracks aggregate selection and size so the UI can toggle a whole section and
/// show live totals.
@Observable
final class SimulationCategory: Identifiable {
    let id = UUID()
    let removalCategory: RemovalCategory
    var files: [SimulationFile]

    init(removalCategory: RemovalCategory, files: [SimulationFile]) {
        self.removalCategory = removalCategory
        // Largest first so the meaningful items surface to the top.
        self.files = files.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// True when any member may be shared with other software.
    var isRisk: Bool { files.contains(where: \.isShared) }

    /// Whether every file in the category is selected (settable to toggle all).
    var isSelected: Bool {
        get { !files.isEmpty && files.allSatisfy(\.isSelected) }
        set { for file in files { file.isSelected = newValue } }
    }

    var selectedCount: Int { files.filter(\.isSelected).count }
    var totalBytes: Int64 { files.reduce(0) { $0 + $1.sizeBytes } }
    var selectedBytes: Int64 { files.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes } }
}
