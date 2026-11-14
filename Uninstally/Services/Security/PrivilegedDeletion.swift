import AppKit
import Foundation
import os

/// Removes PathValidator-approved paths that the current user cannot modify,
/// using one macOS administrator password dialog for the whole batch.
///
/// Implementation notes:
/// * Only absolute paths that already passed `PathValidator` are written into a
///   short-lived script; there is no open-ended shell surface.
/// * Authorization runs via `/usr/bin/osascript` (`do shell script … with
///   administrator privileges`) off the main actor so SwiftUI/AppKit are not
///   nested inside the auth wait.
enum PrivilegedDeletion: Sendable {

    enum Outcome: Sendable, Equatable {
        case removed
        case alreadyGone
        case cancelled
        case failed(String)
    }

    /// Attempts to remove every URL. Returns a per-path outcome. Empty input yields `[:]`.
    static func remove(urls: [URL], mode: DeletionMode) async -> [URL: Outcome] {
        guard !urls.isEmpty else { return [:] }

        var results: [URL: Outcome] = [:]
        var pending: [URL] = []
        for url in urls {
            if !FileManager.default.fileExists(atPath: url.path) {
                results[url] = .alreadyGone
            } else {
                pending.append(url)
            }
        }
        guard !pending.isEmpty else { return results }

        await MainActor.run {
            NSApp.keyWindow?.endEditing(for: nil)
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        // Let any field-editor / IMK teardown finish before the auth sheet.
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        do {
            let scriptURL = try writeScript(for: pending, mode: mode)
            defer { try? FileManager.default.removeItem(at: scriptURL) }

            try await runAdministratorScript(at: scriptURL)

            for url in pending {
                if FileManager.default.fileExists(atPath: url.path) {
                    results[url] = .failed("Item still present after privileged removal")
                } else {
                    results[url] = .removed
                }
            }
        } catch let error as AuthError {
            let outcome: Outcome = (error == .cancelled)
                ? .cancelled
                : .failed(error.localizedDescription)
            for url in pending { results[url] = outcome }
        } catch {
            for url in pending {
                results[url] = .failed(error.localizedDescription)
            }
        }
        return results
    }

    // MARK: - Script

    private static func writeScript(for urls: [URL], mode: DeletionMode) throws -> URL {
        let fm = FileManager.default
        let scriptURL = fm.temporaryDirectory
            .appending(path: "uninstally-privileged-\(UUID().uuidString).sh")

        var lines: [String] = [
            "#!/bin/bash",
            "set -euo pipefail",
        ]

        switch mode {
        case .permanent:
            for url in urls {
                lines.append("/bin/rm -rf -- \(shellQuote(url.path))")
            }
        case .trash:
            let trash = fm.homeDirectoryForCurrentUser
                .appending(path: ".Trash", directoryHint: .isDirectory)
            lines.append("/bin/mkdir -p -- \(shellQuote(trash.path))")
            for url in urls {
                let destination = uniqueTrashURL(for: url, in: trash)
                lines.append("/bin/mv -- \(shellQuote(url.path)) \(shellQuote(destination.path))")
            }
        }

        let body = lines.joined(separator: "\n") + "\n"
        try body.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        return scriptURL
    }

    private static func uniqueTrashURL(for url: URL, in trash: URL) -> URL {
        let fm = FileManager.default
        let base = url.lastPathComponent
        var candidate = trash.appending(path: base)
        if !fm.fileExists(atPath: candidate.path) { return candidate }

        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        for index in 1...1_000 {
            let name = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
            candidate = trash.appending(path: name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return trash.appending(path: "\(base)-\(UUID().uuidString)")
    }

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Authorization

    private enum AuthError: Error, Equatable, LocalizedError {
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: return "Administrator authorization was cancelled"
            case .failed(let message): return message
            }
        }
    }

    private static func runAdministratorScript(at scriptURL: URL) async throws {
        let escapedPath = scriptURL.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        do shell script "/bin/bash " & quoted form of "\(escapedPath)" with administrator privileges
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw AuthError.failed(error.localizedDescription)
        }

        // Wait without blocking the cooperative thread pool via a continuous spin;
        // Process doesn't offer async API on older macOS, so poll termination.
        while process.isRunning {
            try? await Task.sleep(for: .milliseconds(50))
        }

        let status = process.terminationStatus
        if status == 0 { return }

        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let errText = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if errText.localizedCaseInsensitiveContains("User canceled")
            || errText.localizedCaseInsensitiveContains("user cancelled") {
            throw AuthError.cancelled
        }
        let message = errText.isEmpty
            ? "Administrator authorization failed (status \(status))"
            : errText
        Logger.engine.error("Privileged deletion failed (\(status)): \(message, privacy: .public)")
        throw AuthError.failed(message)
    }
}
