import Foundation

/// Strict, security-critical validation of a single file-system path before it is
/// ever considered for deletion.
///
/// The validator is deliberately conservative: it canonicalises the path (resolving
/// symbolic links), refuses anything that resolves to a protected system location
/// or a volume/root directory, and requires the result to live **strictly inside**
/// one of a fixed set of approved roots. Nothing outside those roots can be
/// deleted, no matter what the scanner produced.
enum PathValidator {

    struct Rejection: Error, Sendable {
        let path: String
        let reason: String
    }

    private static let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL

    // MARK: - Approved roots

    /// The only directories whose *descendants* may be deleted. System roots are
    /// included only when the user has enabled "Scan System Level Locations".
    static func allowedRoots(includeSystem: Bool) -> [URL] {
        var roots: [URL] = []
        roots += LibraryPaths.applicationDirectories
        roots += LibraryPaths.userCategoryRoots.map(\.1)
        roots += LibraryPaths.temporaryRoots
        if includeSystem {
            roots += LibraryPaths.systemCategoryRoots.map(\.1)
        }
        return roots.map(\.standardizedFileURL)
    }

    // MARK: - Protected locations (never deletable, even the roots themselves)

    private static func protectedPaths() -> Set<String> {
        protectedPathsCache
    }

    /// Computed once — mounted volumes and the home layout are stable within a run.
    private static let protectedPathsCache: Set<String> = {
        var set: Set<String> = [
            "/", "/System", "/System/Library", "/Library", "/Users", "/Applications",
            "/private", "/private/var", "/private/etc", "/usr", "/usr/local",
            "/bin", "/sbin", "/etc", "/var", "/tmp", "/opt", "/cores", "/Volumes",
        ]
        set.insert(home.path)
        set.insert(home.appending(path: "Library").standardizedFileURL.path)
        set.insert(home.appending(path: "Applications").standardizedFileURL.path)
        for name in ["Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures", "Public"] {
            set.insert(home.appending(path: name).standardizedFileURL.path)
        }
        if let volumes = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: nil
        ) {
            for volume in volumes { set.insert(volume.standardizedFileURL.path) }
        }
        return set
    }()

    // MARK: - Validation

    /// Validates a candidate URL. On success returns the canonicalised URL that
    /// should actually be deleted; on failure returns a reason.
    static func validate(_ url: URL, includeSystem: Bool) -> Result<URL, Rejection> {
        let fm = FileManager.default

        // 1. Must exist.
        guard fm.fileExists(atPath: url.path) else {
            return .failure(Rejection(path: url.path, reason: "Path no longer exists"))
        }

        // 2. Canonicalise: resolve symlinks + standardise.
        let canonical = url.resolvingSymlinksInPath().standardizedFileURL
        let path = canonical.path

        // 3. Never a protected/root/volume path.
        if protectedPaths().contains(path) {
            return .failure(Rejection(path: path, reason: "Protected system location"))
        }

        // 4. Never dangerously shallow (e.g. "/", "/Applications").
        if canonical.pathComponents.count <= 2 {
            return .failure(Rejection(path: path, reason: "Too close to a root directory"))
        }

        // 5. Must be strictly inside an approved root, and never a root itself.
        let roots = allowedRoots(includeSystem: includeSystem)
        if roots.contains(where: { $0.path == path }) {
            return .failure(Rejection(path: path, reason: "Refuses to delete an approved root directory"))
        }
        guard roots.contains(where: { isStrictDescendant(canonical, of: $0) }) else {
            return .failure(Rejection(path: path, reason: "Outside every approved location"))
        }

        return .success(canonical)
    }

    /// True when `url` is a strict descendant of `root` (component-wise, so
    /// "/Applications" never matches "/ApplicationsOther").
    static func isStrictDescendant(_ url: URL, of root: URL) -> Bool {
        let u = url.standardizedFileURL.pathComponents
        let r = root.standardizedFileURL.pathComponents
        guard u.count > r.count else { return false }
        return Array(u.prefix(r.count)) == r
    }
}
