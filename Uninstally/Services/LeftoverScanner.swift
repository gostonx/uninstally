import Foundation
import os

/// Scans the Library hierarchy for *orphaned* artefacts — files whose owning
/// application is no longer installed.
///
/// The scan is identifier-driven: a candidate whose name resembles a reverse-DNS
/// bundle identifier is considered an orphan only when it does not correspond to
/// any currently installed application (by exact id or namespace prefix). This
/// avoids the classic mistake of flagging Apple/system caches as removable.
struct LeftoverScanner: Sendable {

    /// Scans for orphans given the set of currently installed applications.
    func scan(installedApps: [AppInfo], includeSystem: Bool = SecurityPreferences.scanSystemLevel) async -> [LeftoverItem] {
        let installedIdentifiers = Self.installedIdentifierSet(installedApps)

        return await withTaskGroup(of: [LeftoverItem].self) { group in
            for (category, root) in LibraryPaths.userCategoryRoots {
                group.addTask {
                    Self.scanRoot(root, category: category, installed: installedIdentifiers, admin: false)
                }
            }
            if includeSystem {
                for (category, root) in LibraryPaths.systemCategoryRoots {
                    group.addTask {
                        Self.scanRoot(root, category: category, installed: installedIdentifiers, admin: true)
                    }
                }
            }
            group.addTask { Self.scanBrokenAliases() }

            var results: [LeftoverItem] = []
            for await batch in group {
                if Task.isCancelled { break }
                results.append(contentsOf: batch)
            }

            var seen = Set<String>()
            return results
                .filter { seen.insert($0.url.standardizedFileURL.path).inserted }
                .sorted { $0.sizeBytes > $1.sizeBytes }
        }
    }

    // MARK: - Private

    private static func installedIdentifierSet(_ apps: [AppInfo]) -> Set<String> {
        var set = Set<String>()
        for app in apps {
            for id in IdentifierMatcher.exactIdentifiers(for: app) {
                set.insert(id.lowercased())
            }
        }
        return set
    }

    private static func scanRoot(
        _ root: URL,
        category: RemovalCategory,
        installed: Set<String>,
        admin: Bool
    ) -> [LeftoverItem] {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }

        var orphans: [LeftoverItem] = []
        for child in children {
            if Task.isCancelled { return orphans }
            let name = child.lastPathComponent
            guard let identifier = candidateIdentifier(from: name),
                  !isInstalled(identifier, installed: installed),
                  !isSystemReserved(identifier) else { continue }

            orphans.append(LeftoverItem(
                category: category,
                url: child,
                sizeBytes: FileSystemUtil.size(of: child),
                requiresAdmin: admin,
                associatedIdentifier: identifier
            ))
        }
        return orphans
    }

    /// Extracts a bundle-identifier-like token from a file name, or `nil` if the
    /// name doesn't resemble one.
    private static func candidateIdentifier(from name: String) -> String? {
        var bare = name
        for ext in [".plist", ".savedState", ".lockfile", ".binarycookies"] where bare.hasSuffix(ext) {
            bare = String(bare.dropLast(ext.count))
        }
        // ByHost preferences append a hardware UUID: strip a trailing UUID chunk.
        if let range = bare.range(of: #"\.[0-9A-Fa-f-]{36}$"#, options: .regularExpression) {
            bare.removeSubrange(range)
        }
        let parts = bare.split(separator: ".")
        guard parts.count >= 3, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
        return bare
    }

    private static func isInstalled(_ identifier: String, installed: Set<String>) -> Bool {
        let lower = identifier.lowercased()
        if installed.contains(lower) { return true }
        // Nested helper of an installed app, or an app whose id is a prefix.
        for id in installed where lower.hasPrefix(id + ".") || id.hasPrefix(lower + ".") {
            return true
        }
        return false
    }

    /// Excludes Apple/system namespaces that must never be flagged.
    private static func isSystemReserved(_ identifier: String) -> Bool {
        let reservedPrefixes = ["com.apple.", "group.com.apple.", "org.swift.", "com.google.keystone"]
        let lower = identifier.lowercased()
        return reservedPrefixes.contains { lower.hasPrefix($0) }
    }

    /// Detects broken aliases / symlinks in the Applications directories.
    private static func scanBrokenAliases() -> [LeftoverItem] {
        var items: [LeftoverItem] = []
        for dir in LibraryPaths.applicationDirectories {
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            for child in children where FileSystemUtil.isBrokenAlias(child) {
                items.append(LeftoverItem(
                    category: .other,
                    url: child,
                    sizeBytes: 0,
                    requiresAdmin: FileSystemUtil.requiresElevatedPrivileges(for: child),
                    associatedIdentifier: "Broken alias"
                ))
            }
        }
        return items
    }
}
