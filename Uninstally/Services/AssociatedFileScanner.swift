import Foundation
import os

/// The "smart detection" engine. Given an application it discovers every artefact
/// that belongs to it across the standard macOS Library hierarchy.
///
/// Design principles:
/// * **Never match on folder name alone.** Matching is driven by bundle
///   identifiers (and their helper namespaces) harvested from the bundle. A
///   name-equality match is only used for a small set of roots (Application
///   Support, Logs) where vendors conventionally name folders after the app, and
///   even then the match reason is recorded so the user can make an informed
///   decision.
/// * **Record a reason for every match** so the UI can explain itself.
/// * **Compute real sizes** so the reclaimable total is accurate.
struct AssociatedFileScanner: Sendable {

    func scan(for app: AppInfo, includeSystem: Bool = SecurityPreferences.scanSystemLevel) async -> [RemovableItem] {
        await withTaskGroup(of: [RemovableItem].self) { group in
            // The application bundle itself is always present.
            group.addTask { [Self.appBundleItem(app)] }

            // User-level category roots.
            for (category, root) in LibraryPaths.userCategoryRoots {
                group.addTask { Self.matchChildren(in: root, category: category, app: app, admin: false) }
            }

            // System-level category roots (admin required) — only when enabled.
            if includeSystem {
                for (category, root) in LibraryPaths.systemCategoryRoots {
                    group.addTask { Self.matchChildren(in: root, category: category, app: app, admin: true) }
                }
            }

            // Preferences require special handling (files, ByHost, lockfiles).
            group.addTask { Self.matchPreferences(app: app) }

            var results: [RemovableItem] = []
            for await batch in group {
                results.append(contentsOf: batch)
            }

            // De-duplicate by resolved path.
            var seen = Set<String>()
            return results
                .filter { seen.insert($0.url.standardizedFileURL.path).inserted }
                .sorted { $0.sizeBytes > $1.sizeBytes }
        }
    }

    // MARK: - Matching

    private static func appBundleItem(_ app: AppInfo) -> RemovableItem {
        RemovableItem(
            category: .application,
            url: app.url,
            sizeBytes: app.sizeBytes,
            requiresAdmin: FileSystemUtil.requiresElevatedPrivileges(for: app.url),
            matchReason: "The application bundle"
        )
    }

    /// Enumerates the immediate children of `root` and keeps those that match the
    /// app by identifier. For Application Support / Logs it additionally accepts a
    /// folder whose name equals the app's display name.
    private static func matchChildren(
        in root: URL,
        category: RemovalCategory,
        app: AppInfo,
        admin: Bool
    ) -> [RemovableItem] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let allowNameMatch = category == .applicationSupport || category == .logs
        var items: [RemovableItem] = []

        for child in children {
            let name = child.lastPathComponent
            var reason: String?

            if let identifierReason = IdentifierMatcher.matchesIdentifierExactly(name, app: app) {
                reason = identifierReason
            } else if containsIdentifier(name, app: app) {
                reason = "Named for \(app.bundleIdentifier)"
            } else if allowNameMatch, matchesDisplayName(name, app: app) {
                reason = "Folder named after \(app.name)"
            }

            guard let matchReason = reason else { continue }

            let size = FileSystemUtil.size(of: child)
            items.append(RemovableItem(
                category: category,
                url: child,
                sizeBytes: size,
                requiresAdmin: admin || FileSystemUtil.requiresElevatedPrivileges(for: child),
                matchReason: matchReason
            ))
        }
        return items
    }

    /// Preferences live in a few shapes: `<id>.plist`, `<id>.plist.lockfile`,
    /// and `ByHost/<id>.<uuid>.plist`.
    private static func matchPreferences(app: AppInfo) -> [RemovableItem] {
        var items: [RemovableItem] = []
        let prefsRoot = LibraryPaths.home
            .appending(path: "Library/Preferences", directoryHint: .isDirectory)
        let byHost = prefsRoot.appending(path: "ByHost", directoryHint: .isDirectory)

        for root in [prefsRoot, byHost] {
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            for child in children {
                let name = child.lastPathComponent
                guard containsIdentifier(name, app: app) else { continue }
                items.append(RemovableItem(
                    category: .preferences,
                    url: child,
                    sizeBytes: FileSystemUtil.size(of: child),
                    requiresAdmin: false,
                    matchReason: "Preferences for \(app.bundleIdentifier)"
                ))
            }
        }
        return items
    }

    // MARK: - Predicates

    /// True when `name` begins with, equals, or embeds an exact identifier.
    private static func containsIdentifier(_ name: String, app: AppInfo) -> Bool {
        let bare = (name as NSString).deletingPathExtension
        for id in IdentifierMatcher.exactIdentifiers(for: app) where !id.isEmpty {
            if bare == id || name.hasPrefix(id) || name.contains("." + id) || bare.hasSuffix(id) {
                return true
            }
        }
        for prefix in IdentifierMatcher.prefixes(for: app) where name.hasPrefix(prefix) || bare.hasPrefix(prefix) {
            return true
        }
        return false
    }

    private static func matchesDisplayName(_ name: String, app: AppInfo) -> Bool {
        guard app.name.count > 3 else { return false } // avoid tiny, generic names
        return name.compare(app.name, options: .caseInsensitive) == .orderedSame
    }
}
