import AppKit
import Foundation
import os

/// Events streamed by the `DeletionExecutor` during an operation.
enum UninstallEvent: Sendable {
    case progress(UninstallProgress)
    case finished(UninstallResult)
}

/// Executes a **validated** `DeletionPlan`, one file at a time.
///
/// User-writable artefacts use native `FileManager` APIs. Items that require
/// administrator rights (or fail with a permission error) are batched into a
/// single macOS authentication dialog via `PrivilegedDeletion`. Authorization
/// cancel or failure is reported as a visible uninstall failure — never silently
/// treated as success.
struct DeletionExecutor: Sendable {

    func execute(plan: DeletionPlan) -> AsyncStream<UninstallEvent> {
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
        plan: DeletionPlan,
        continuation: AsyncStream<UninstallEvent>.Continuation
    ) async {
        let start = Date()
        let items = plan.items
        let totalCount = items.count
        let totalBytes = plan.totalBytes

        var completed = 0
        var bytesRemoved: Int64 = 0
        var trashedAppURL: URL?
        var deletedPaths: [String] = []
        var skipped: [DeletionLogEntry.FileOutcome] = []
        var permissionErrors: [DeletionLogEntry.FileOutcome] = []
        var failures: [FailedRemoval] = []
        var privilegedQueue: [PlannedDeletion] = []

        func emit(_ currentPath: String) {
            let fraction = totalBytes > 0
                ? Double(bytesRemoved) / Double(totalBytes)
                : (totalCount > 0 ? Double(completed) / Double(totalCount) : 1)
            let elapsed = Date().timeIntervalSince(start)
            let eta: TimeInterval? = fraction > 0.02 ? elapsed / fraction * (1 - fraction) : nil
            continuation.yield(.progress(UninstallProgress(
                fractionCompleted: min(max(fraction, 0), 1),
                currentPath: currentPath,
                completedCount: completed,
                totalCount: totalCount,
                bytesRemoved: bytesRemoved,
                estimatedTimeRemaining: eta
            )))
        }

        emit("Preparing…")

        for item in items {
            if Task.isCancelled { break }
            let displayPath = item.canonicalURL.path
            emit(displayPath)

            // 1. Re-validate at execution time (guards against TOCTOU / symlink swaps).
            let target: URL
            switch PathValidator.validate(item.canonicalURL, includeSystem: true) {
            case .failure(let rejection):
                skipped.append(.init(path: displayPath, reason: rejection.reason))
                completed += 1
                emit(displayPath)
                continue
            case .success(let validated):
                target = validated
            }

            if !FileManager.default.fileExists(atPath: target.path) {
                deletedPaths.append(target.path)
                bytesRemoved += item.sizeBytes
                completed += 1
                emit(displayPath)
                continue
            }

            // Root-owned / system items go through one shared auth prompt.
            if item.requiresAdmin {
                privilegedQueue.append(item)
                continue
            }

            // 2. Delete with native APIs; permission failures join the privileged batch.
            do {
                switch plan.method {
                case .trash:
                    var resulting: NSURL?
                    try FileManager.default.trashItem(at: target, resultingItemURL: &resulting)
                    if item.isApplicationBundle { trashedAppURL = resulting as URL? }
                    if !FileManager.default.fileExists(atPath: target.path) {
                        deletedPaths.append(target.path)
                        bytesRemoved += item.sizeBytes
                    } else {
                        failures.append(FailedRemoval(path: displayPath, reason: "Item still present after trashing"))
                    }
                case .permanent:
                    try FileManager.default.removeItem(at: target)
                    if !FileManager.default.fileExists(atPath: target.path) {
                        deletedPaths.append(target.path)
                        bytesRemoved += item.sizeBytes
                    } else {
                        failures.append(FailedRemoval(path: displayPath, reason: "Item still present after deletion"))
                    }
                }
            } catch {
                let nsError = error as NSError
                if !FileManager.default.fileExists(atPath: target.path) {
                    deletedPaths.append(target.path)
                    bytesRemoved += item.sizeBytes
                } else if isPermissionError(nsError) {
                    privilegedQueue.append(item)
                } else {
                    failures.append(FailedRemoval(path: displayPath, reason: error.localizedDescription))
                    Logger.engine.error("Failed to remove \(target.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            if !privilegedQueue.contains(where: { $0.id == item.id }) {
                completed += 1
                emit(displayPath)
            }
            await Task.yield()
        }

        // 3. One administrator prompt for every remaining privileged path.
        if !Task.isCancelled, !privilegedQueue.isEmpty {
            emit("Waiting for administrator authorization…")
            let urls = privilegedQueue.map(\.canonicalURL)
            let outcomes = await MainActor.run {
                PrivilegedDeletion.remove(urls: urls, mode: plan.method)
            }

            for item in privilegedQueue {
                if Task.isCancelled { break }
                let displayPath = item.canonicalURL.path
                emit(displayPath)

                switch outcomes[item.canonicalURL] ?? .failed("No privileged result") {
                case .removed, .alreadyGone:
                    deletedPaths.append(displayPath)
                    bytesRemoved += item.sizeBytes
                    if item.isApplicationBundle, plan.method == .trash {
                        trashedAppURL = trashedAppURL
                            ?? FileManager.default.homeDirectoryForCurrentUser
                                .appending(path: ".Trash/\(item.canonicalURL.lastPathComponent)")
                    }
                case .cancelled:
                    let reason = "Administrator authorization was cancelled"
                    permissionErrors.append(.init(path: displayPath, reason: reason))
                    failures.append(FailedRemoval(path: displayPath, reason: reason))
                case .failed(let reason):
                    permissionErrors.append(.init(path: displayPath, reason: reason))
                    failures.append(FailedRemoval(path: displayPath, reason: reason))
                    Logger.engine.error("Privileged removal failed for \(displayPath, privacy: .public): \(reason, privacy: .public)")
                }

                completed += 1
                emit(displayPath)
                await Task.yield()
            }
        }

        let result = UninstallResult(
            appName: plan.app.name,
            reclaimedBytes: bytesRemoved,
            removedFileCount: deletedPaths.count,
            duration: Date().timeIntervalSince(start),
            failures: failures,
            skippedCount: skipped.count,
            trashedAppURL: trashedAppURL
        )

        await DeletionLogger.shared.record(DeletionLogEntry(
            timestamp: start,
            appName: plan.app.name,
            bundleIdentifier: plan.app.bundleIdentifier,
            version: plan.app.displayVersion,
            method: plan.method.rawValue,
            deletedPaths: deletedPaths,
            skipped: skipped,
            permissionErrors: permissionErrors,
            recoveredBytes: bytesRemoved,
            success: failures.isEmpty && permissionErrors.isEmpty
        ))

        let changedDirs = Set(items.map { $0.canonicalURL.deletingLastPathComponent().path })
        await MainActor.run {
            for dir in changedDirs { NSWorkspace.shared.noteFileSystemChanged(dir) }
        }

        continuation.yield(.finished(result))
    }

    private static func isPermissionError(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain,
           [513 /* NSFileWriteNoPermissionError */, 257 /* NSFileReadNoPermissionError */].contains(error.code) {
            return true
        }
        if error.domain == NSPOSIXErrorDomain, [1 /* EPERM */, 13 /* EACCES */].contains(error.code) {
            return true
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionError(underlying)
        }
        return false
    }
}
