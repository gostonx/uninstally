import Foundation

/// Low-level file-system helpers shared across the scanning and uninstall engines.
enum FileSystemUtil {
    private static let fm = FileManager.default

    /// Computes the total allocated size of a file or directory tree, in bytes.
    ///
    /// Uses `totalFileAllocatedSize` where available (matching Finder's notion of
    /// "size on disk") and falls back to logical file size. Symbolic links are not
    /// followed to avoid double-counting or escaping the tree.
    static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey,
        ]

        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }

        if values.isDirectory == true {
            var total: Int64 = 0
            guard let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { return 0 }

            for case let child as URL in enumerator {
                guard let childValues = try? child.resourceValues(forKeys: keys),
                      childValues.isRegularFile == true else { continue }
                total += Int64(childValues.totalFileAllocatedSize
                    ?? childValues.fileAllocatedSize
                    ?? childValues.fileSize
                    ?? 0)
            }
            return total
        }

        return Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
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
