import Foundation

/// Low-level file-system helpers shared across the scanning and uninstall engines.
enum FileSystemUtil {
    private static let fm = FileManager.default

    /// Computes the total allocated size of a file or directory tree, in bytes.
    ///
    /// Uses `/usr/bin/du -sk` for directories which is significantly faster than
    /// `FileManager.enumerator` for large trees (LLM models, caches, containers).
    /// Reports size in 1024-byte blocks as macOS Finder does.
    static func size(of url: URL) -> Int64 {
        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey])
        guard let rv = resourceValues else { return 0 }

        if rv.isDirectory == true {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
            process.arguments = ["-sk", url.path]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            guard let _ = try? process.run() else { return 0 }
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return 0 }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0 }
            let parts = output.components(separatedBy: .whitespaces)
            guard let first = parts.first, let blocks = Int64(first) else { return 0 }
            return blocks * 1024
        }

        return Int64(rv.totalFileAllocatedSize ?? rv.fileSize ?? 0)
    }

    /// Returns `true` when the item exists and is not writable by the current user,
    /// or is owned by root — a strong signal that admin rights are required to delete it.
    static func requiresElevatedPrivileges(for url: URL) -> Bool {
        // Anything under /Library (but not ~/Library) needs admin.
        if url.path.hasPrefix("/Library/") { return true }
        if url.path.hasPrefix("/Applications/") {
            // Not writable => admin.
            return !fm.isWritableFile(atPath: url.path)
        }
        guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return false }
        if let owner = attrs[.ownerAccountID] as? NSNumber, owner.intValue == 0 { return true }
        return !fm.isWritableFile(atPath: url.deletingLastPathComponent().path)
    }

    /// Creation date of an item, if available.
    static func creationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
    }

    /// Best-effort "last used" date: LaunchServices content-access date, falling
    /// back to the modification date.
    static func lastUsedDate(of url: URL) -> Date? {
        let keys: Set<URLResourceKey> = [.contentAccessDateKey, .contentModificationDateKey]
        let values = try? url.resourceValues(forKeys: keys)
        return values?.contentAccessDate ?? values?.contentModificationDate
    }

    /// Volume display name for a URL (e.g. "Macintosh HD", "SanDisk").
    static func volumeName(of url: URL) -> String? {
        (try? url.resourceValues(forKeys: [.volumeNameKey]))?.volumeName
    }

    /// Whether a URL is a broken symbolic link / alias.
    static func isBrokenAlias(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isAliasFileKey]) else {
            return false
        }
        if values.isSymbolicLink == true || values.isAliasFile == true {
            let resolved = url.resolvingSymlinksInPath()
            return !fm.fileExists(atPath: resolved.path)
        }
        return false
    }

    static func exists(_ url: URL) -> Bool {
        fm.fileExists(atPath: url.path)
    }
}
