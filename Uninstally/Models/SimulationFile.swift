import Foundation
import Observation

/// A single artefact presented in the simulation. Wraps an immutable
/// `RemovableItem` while being `@Observable` so the UI can bind to `isSelected`.
@Observable
final class SimulationFile: Identifiable {
    let id: UUID
    let category: RemovalCategory
    let url: URL
    let sizeBytes: Int64
    let requiresAdmin: Bool
    let matchReason: String
    /// Flags artefacts that may be shared with other software (e.g. group
    /// containers), which are highlighted with a warning.
    let isShared: Bool
    var isSelected: Bool

    var name: String { url.lastPathComponent }

    var displayPath: String {
        url.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }

    init(from item: RemovableItem) {
        self.id = item.id
        self.category = item.category
        self.url = item.url
        self.sizeBytes = item.sizeBytes
        self.requiresAdmin = item.requiresAdmin
        self.matchReason = item.matchReason
        self.isShared = item.isShared
        self.isSelected = item.isSelected
    }
}
