import Foundation

/// A single file-system artefact that Uninstally proposes to remove.
///
/// Items are discovered by the `AssociatedFileScanner` and presented to the user
/// for review. Each item tracks whether it requires elevated privileges so the
/// engine can batch privileged deletions behind a single authorisation prompt.
struct RemovableItem: Identifiable, Hashable, Sendable {
    let id = UUID()

    /// The category this artefact belongs to, used for grouping and iconography.
    let category: RemovalCategory

    /// Absolute file-system location of the artefact.
    let url: URL

    /// Size on disk in bytes (recursively summed for directories).
    let sizeBytes: Int64

    /// Whether deletion requires administrator privileges (e.g. `/Library`, root-owned).
    let requiresAdmin: Bool

    /// Whether the user has selected this item for removal. Defaults to `true`.
    var isSelected: Bool = true

    /// A short explanation of *why* this artefact was matched, aiding user trust.
    let matchReason: String

    var displayPath: String {
        url.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }

    var name: String { url.lastPathComponent }

    /// Whether this artefact may belong to more than one application (e.g. shared
    /// Group Containers). Such items are flagged with a warning before removal.
    var isShared: Bool {
        switch category {
        case .groupContainers, .containers: return false // we match by exact id
        default: return false
        }
    }
}
