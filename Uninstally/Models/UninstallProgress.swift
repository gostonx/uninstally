import Foundation

/// Live progress emitted by the `UninstallEngine` as it removes artefacts.
struct UninstallProgress: Sendable {
    var fractionCompleted: Double
    var currentPath: String
    var completedCount: Int
    var totalCount: Int
    var bytesRemoved: Int64
    var estimatedTimeRemaining: TimeInterval?
}

/// The terminal result of an uninstall operation.
struct UninstallResult: Sendable {
    let appName: String
    let reclaimedBytes: Int64
    let removedFileCount: Int
    let duration: TimeInterval
    let failures: [FailedRemoval]
    /// When the app bundle was moved to the Trash, its resulting location there —
    /// used to offer "Restore from Trash" in the uninstall history.
    var trashedAppURL: URL?

    var succeeded: Bool { failures.isEmpty }
}

/// Describes a single artefact that could not be removed.
struct FailedRemoval: Identifiable, Sendable {
    let id = UUID()
    let path: String
    let reason: String
}
