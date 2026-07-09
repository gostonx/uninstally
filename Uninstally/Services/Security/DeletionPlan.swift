import Foundation

/// A single, validated artefact scheduled for deletion. Produced only after it has
/// passed `PathValidator` and the belongs-to-application check.
struct PlannedDeletion: Identifiable, Sendable {
    let id: UUID
    /// The path as originally discovered by the scanner.
    let originalURL: URL
    /// The canonicalised, symlink-resolved path that will actually be deleted.
    let canonicalURL: URL
    let category: RemovalCategory
    let sizeBytes: Int64
    let requiresAdmin: Bool
    let isShared: Bool
    let matchReason: String

    var name: String { canonicalURL.lastPathComponent }
    var isApplicationBundle: Bool { category == .application }
}

/// An artefact that was excluded from the plan because it failed validation.
/// Retained for transparency and logging.
struct RejectedDeletion: Identifiable, Sendable {
    let id = UUID()
    let path: String
    let reason: String
}

/// The validated, ready-to-execute deletion plan for one application. The executor
/// runs this directly — there is no rescanning between planning and execution.
struct DeletionPlan: Sendable {
    let app: AppInfo
    let method: DeletionMode
    let items: [PlannedDeletion]
    let rejected: [RejectedDeletion]

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }
    var fileCount: Int { items.count }
    var requiresAdmin: Bool { items.contains { $0.requiresAdmin } }

    func items(in category: RemovalCategory) -> [PlannedDeletion] {
        items.filter { $0.category == category }
    }
}
