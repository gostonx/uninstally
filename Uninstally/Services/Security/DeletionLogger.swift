import Foundation
import os

/// A structured record of one uninstall operation, suitable for auditing.
struct DeletionLogEntry: Codable, Identifiable, Sendable {
    struct FileOutcome: Codable, Sendable {
        let path: String
        let reason: String
    }

    var id = UUID()
    let timestamp: Date
    let appName: String
    let bundleIdentifier: String
    let version: String
    /// "trash" or "permanent".
    let method: String
    let deletedPaths: [String]
    let skipped: [FileOutcome]
    let permissionErrors: [FileOutcome]
    let recoveredBytes: Int64
    let success: Bool
}

/// Persists a detailed, append-only uninstall log on disk and supports export.
/// An `actor` so it can be written safely from the executor's background task.
actor DeletionLogger {
    static let shared = DeletionLogger()

    private let fileURL: URL
    private let maxEntries = 1000

    init() {
        let base = URL.applicationSupportDirectory.appending(path: "Uninstally", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appending(path: "uninstall-log.json")
    }

    /// Appends an entry to the persisted log.
    func record(_ entry: DeletionLogEntry) {
        var entries = load()
        entries.append(entry)
        if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }
        save(entries)
        Logger.engine.log("Logged uninstall of \(entry.appName, privacy: .public): \(entry.deletedPaths.count) removed, \(entry.skipped.count) skipped, success=\(entry.success)")
    }

    func allEntries() -> [DeletionLogEntry] {
        load().sorted { $0.timestamp > $1.timestamp }
    }

    /// The on-disk log file URL — used for "Export Log".
    nonisolated var logFileURL: URL {
        let base = URL.applicationSupportDirectory.appending(path: "Uninstally", directoryHint: .isDirectory)
        return base.appending(path: "uninstall-log.json")
    }

    /// A human-readable export of the entire log.
    func exportText() -> String {
        let entries = allEntries()
        let df = ISO8601DateFormatter()
        var out = "Uninstally — Uninstall Log\nGenerated \(df.string(from: Date()))\n\n"
        for e in entries {
            out += "──────────────────────────────────────────\n"
            out += "\(df.string(from: e.timestamp))  \(e.appName) \(e.version) [\(e.bundleIdentifier)]\n"
            out += "Method: \(e.method)   Recovered: \(Format.bytes(e.recoveredBytes))   Success: \(e.success)\n"
            out += "Deleted (\(e.deletedPaths.count)):\n" + e.deletedPaths.map { "  ✓ \($0)" }.joined(separator: "\n") + "\n"
            if !e.skipped.isEmpty {
                out += "Skipped (\(e.skipped.count)):\n" + e.skipped.map { "  – \($0.path) — \($0.reason)" }.joined(separator: "\n") + "\n"
            }
            if !e.permissionErrors.isEmpty {
                out += "Permission errors (\(e.permissionErrors.count)):\n" + e.permissionErrors.map { "  ! \($0.path) — \($0.reason)" }.joined(separator: "\n") + "\n"
            }
            out += "\n"
        }
        return out
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Storage

    private func load() -> [DeletionLogEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([DeletionLogEntry].self, from: data)) ?? []
    }

    private func save(_ entries: [DeletionLogEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
