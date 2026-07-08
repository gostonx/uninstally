import Foundation

/// Heuristics for matching on-disk artefacts to an application. The scanner never
/// deletes a folder purely because its *name* matches; instead it derives a set of
/// high-confidence tokens (bundle identifiers and their prefixes) and matches
/// artefacts against those, recording a human-readable reason for every match.
enum IdentifierMatcher {
    /// Produces the set of exact identifiers that unambiguously belong to an app.
    /// These include the primary bundle id plus any auxiliary identifiers harvested
    /// from the bundle (helpers, extensions, login items).
    static func exactIdentifiers(for app: AppInfo) -> Set<String> {
        var ids = Set<String>()
        if !app.bundleIdentifier.isEmpty { ids.insert(app.bundleIdentifier) }
        for extra in app.extraBundleIdentifiers where !extra.isEmpty {
            ids.insert(extra)
        }
        return ids
    }

    /// A conservative reverse-DNS prefix (e.g. `com.acme.app` -> `com.acme.app.`)
    /// used to match nested helper identifiers such as `com.acme.app.helper`.
    static func prefixes(for app: AppInfo) -> Set<String> {
        var prefixes = Set<String>()
        for id in exactIdentifiers(for: app) where id.split(separator: ".").count >= 2 {
            prefixes.insert(id + ".")
        }
        return prefixes
    }

    /// Decides whether a file/directory name belongs to the app, returning a reason
    /// string when it does. `name` should be the last path component.
    static func match(fileName name: String, app: AppInfo) -> String? {
        let exact = exactIdentifiers(for: app)

        // 1. Exact identifier match (highest confidence).
        for id in exact {
            if name == id || name.hasPrefix(id + ".") || name == id + ".plist" {
                return "Matches bundle identifier \(id)"
            }
        }

        // 2. Prefix match for nested helper identifiers.
        for prefix in prefixes(for: app) where name.hasPrefix(prefix) {
            return "Belongs to identifier namespace \(prefix)"
        }

        return nil
    }

    /// Matches a *directory named after the bundle identifier* exactly. Used for
    /// container-style roots where the folder name is the identifier.
    static func matchesIdentifierExactly(_ name: String, app: AppInfo) -> String? {
        let bare = (name as NSString).deletingPathExtension
        for id in exactIdentifiers(for: app) where bare == id || name == id {
            return "Container for \(id)"
        }
        for prefix in prefixes(for: app) where bare.hasPrefix(prefix) {
            return "Nested container under \(prefix)"
        }
        return nil
    }
}
