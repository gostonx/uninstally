import Foundation

/// A discovered, installed macOS application together with the metadata Uninstally
/// needs to display it and to drive the associated-file scan.
///
/// `AppInfo` is a value type so it can be moved freely across concurrency domains.
/// Icons are loaded lazily and separately (see `IconLoader`) to keep this type
/// `Sendable` and cheap to copy.
struct AppInfo: Identifiable, Hashable, Sendable {
    /// Stable identity derived from the on-disk location.
    var id: String { url.path }

    /// Absolute location of the `.app` bundle.
    let url: URL

    /// Localised display name (falls back to the file name without extension).
    let name: String

    /// `CFBundleIdentifier`, e.g. `com.apple.Safari`. May be empty for malformed bundles.
    let bundleIdentifier: String

    /// Human readable version (`CFBundleShortVersionString`).
    let version: String

    /// Build number (`CFBundleVersion`).
    let buildVersion: String

    /// Best-effort developer / vendor name derived from the code signature or bundle id.
    let developer: String

    /// Total size on disk of the application bundle, in bytes.
    let sizeBytes: Int64

    /// Creation / installation date of the bundle.
    let installDate: Date?

    /// Last time the bundle was opened, as reported by the file system / LaunchServices.
    let lastUsedDate: Date?

    /// Whether the bundle lives on the boot volume or an external drive.
    let volumeName: String?

    /// True when the bundle is missing an executable or core resources.
    let isBrokenInstall: Bool

    /// The set of Info.plist derived metadata used later by the scanner.
    let extraBundleIdentifiers: [String]

    var displayVersion: String {
        if version.isEmpty && buildVersion.isEmpty { return "—" }
        if buildVersion.isEmpty || buildVersion == version { return version }
        if version.isEmpty { return buildVersion }
        return "\(version) (\(buildVersion))"
    }

    var location: String {
        url.deletingLastPathComponent().path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }

    /// A stable key used for Collection membership. Prefers the bundle identifier
    /// (survives the app moving on disk); falls back to the path for malformed
    /// bundles without one.
    var collectionKey: String {
        bundleIdentifier.isEmpty ? url.standardizedFileURL.path : bundleIdentifier
    }
}
