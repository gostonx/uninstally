import Foundation

/// An orphaned artefact left behind by an application that is no longer installed.
struct LeftoverItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let category: RemovalCategory
    let url: URL
    let sizeBytes: Int64
    let requiresAdmin: Bool
    /// The bundle identifier (or best guess) this orphan appears to belong to.
    let associatedIdentifier: String
    var isSelected: Bool = false

    var displayPath: String {
        url.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }

    var name: String { url.lastPathComponent }
}
