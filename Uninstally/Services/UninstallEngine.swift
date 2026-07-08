import AppKit
import Foundation
import os

/// Events streamed by the `UninstallEngine` during an operation.
enum UninstallEvent: Sendable {
    case progress(UninstallProgress)
    case finished(UninstallResult)
}

/// Performs the actual removal of an application and its artefacts.
///
/// Removal strategy:
/// * **User-domain artefacts** are moved to the Trash via `FileManager.trashItem`.
///   This is the reversible, Apple-sanctioned deletion path and gives the user a
///   native Undo affordance in Finder.
/// * **System-domain artefacts** (anything under `/Library`, root-owned files,
///   privileged helpers) are removed in a single elevated `rm` invocation so the
///   user is prompted for their password at most once. Elevation uses
///   `NSAppleScript`'s `with administrator privileges`, which — unlike the
///   deprecated `AuthorizationExecuteWithPrivileges` — remains supported for
///   user-initiated administrative actions.
///
/// Progress, the current path, a running byte total, and an ETA are streamed back
/// as the work proceeds so the UI never has to poll.
struct UninstallEngine: Sendable {

    /// Runs the uninstall for `plan`, returning a stream of progress + a final result.
    func run(plan: UninstallPlan) -> AsyncStream<UninstallEvent> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                await Self.perform(plan: plan, continuation: continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Execution

    private static func perform(
        plan: UninstallPlan,
        continuation: AsyncStream<UninstallEvent>.Continuation
    ) async {
        let start = Date()
        let items = plan.selectedItems
        let userItems = items.filter { !$0.requiresAdmin }
        let adminItems = items.filter { $0.requiresAdmin }
        let totalCount = items.count
        let totalBytes = items.reduce(Int64(0)) { $0 + $1.sizeBytes }

        var completed = 0
        var bytesRemoved: Int64 = 0
        var failures: [FailedRemoval] = []

        func emitProgress(currentPath: String) {
            let fraction = totalBytes > 0
                ? Double(bytesRemoved) / Double(totalBytes)
                : (totalCount > 0 ? Double(completed) / Double(totalCount) : 1)
            let elapsed = Date().timeIntervalSince(start)
            let eta: TimeInterval? = fraction > 0.02
                ? elapsed / fraction * (1 - fraction)
                : nil
            continuation.yield(.progress(UninstallProgress(
                fractionCompleted: min(max(fraction, 0), 1),
                currentPath: currentPath,
                completedCount: completed,
                totalCount: totalCount,
                bytesRemoved: bytesRemoved,
                estimatedTimeRemaining: eta
            )))
        }

        emitProgress(currentPath: "Preparing…")

        // 1. Trash user-domain items individually so we can report per-file progress.
        for item in userItems {
            if Task.isCancelled { break }
            emitProgress(currentPath: item.displayPath)
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                bytesRemoved += item.sizeBytes
            } catch {
                // If the item is simply gone already, treat it as success.
                if FileSystemUtil.exists(item.url) {
                    failures.append(FailedRemoval(path: item.displayPath, reason: error.localizedDescription))
                    Logger.engine.error("Failed to trash \(item.url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                } else {
                    bytesRemoved += item.sizeBytes
                }
            }
            completed += 1
            emitProgress(currentPath: item.displayPath)
            // Small yield so the UI can breathe on huge selections.
            await Task.yield()
        }

        // 2. Remove admin items in a single elevated batch.
        if !adminItems.isEmpty, !Task.isCancelled {
            emitProgress(currentPath: "Requesting administrator privileges…")
            let paths = adminItems.map(\.url.path)
            let elevationError = await ElevatedRemover.remove(paths: paths)
            if let elevationError {
                for item in adminItems {
                    failures.append(FailedRemoval(path: item.displayPath, reason: elevationError))
                }
            } else {
                for item in adminItems {
                    bytesRemoved += item.sizeBytes
                    completed += 1
                    emitProgress(currentPath: item.displayPath)
                }
            }
        }

        let result = UninstallResult(
            appName: plan.app.name,
            reclaimedBytes: bytesRemoved,
            removedFileCount: completed,
            duration: Date().timeIntervalSince(start),
            failures: failures
        )
        continuation.yield(.finished(result))
    }
}

/// Encapsulates a single privileged deletion. Runs on the main actor because
/// `NSAppleScript` is not thread-safe.
private enum ElevatedRemover {
    /// Deletes all `paths` with administrator privileges. Returns `nil` on success
    /// or an error description on failure / cancellation.
    @MainActor
    static func remove(paths: [String]) async -> String? {
        guard !paths.isEmpty else { return nil }
        // Quote each path safely for the shell.
        let quoted = paths.map { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }
            .joined(separator: " ")
        let command = "/bin/rm -rf \(quoted)"
        let source = "do shell script \"\(command.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"

        guard let script = NSAppleScript(source: source) else {
            return "Could not construct privileged command."
        }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let number = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            if number == -128 { return "Administrator authorisation was cancelled." }
            return (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Privileged removal failed."
        }
        return nil
    }
}
