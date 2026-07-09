import Foundation
import SwiftData

/// A persisted record of a single application uninstalled through Uninstally.
///
/// This is an **uninstall history**, not a recycle bin — it only records apps that
/// Uninstally removed. All data is stored locally with SwiftData; nothing is
/// uploaded and no analytics are collected.
@Model
final class UninstallRecord {
    var appName: String
    var bundleIdentifier: String
    var developer: String
    var version: String
    /// The directory the app used to live in (e.g. `/Applications`).
    var originalLocation: String
    var dateUninstalled: Date
    var filesRemoved: Int
    /// Bytes of storage reclaimed.
    var storageRecovered: Int
    /// `DeletionMode` raw value: "trash" or "permanent".
    var deletionMethodRaw: String
    /// If moved to the Trash, the app bundle's resulting path there (for restore).
    var trashedAppPath: String?
    /// A captured PNG of the app icon (the bundle may no longer exist).
    @Attribute(.externalStorage) var iconData: Data?

    init(
        appName: String,
        bundleIdentifier: String,
        developer: String,
        version: String,
        originalLocation: String,
        dateUninstalled: Date = .now,
        filesRemoved: Int,
        storageRecovered: Int,
        deletionMethod: DeletionMode,
        trashedAppPath: String? = nil,
        iconData: Data? = nil
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.developer = developer
        self.version = version
        self.originalLocation = originalLocation
        self.dateUninstalled = dateUninstalled
        self.filesRemoved = filesRemoved
        self.storageRecovered = storageRecovered
        self.deletionMethodRaw = deletionMethod.rawValue
        self.trashedAppPath = trashedAppPath
        self.iconData = iconData
    }

    var deletionMethod: DeletionMode {
        DeletionMode(rawValue: deletionMethodRaw) ?? .permanent
    }

    /// The current URL of the trashed app bundle, if one was recorded and it still
    /// exists in the Trash (used to enable/disable "Restore from Trash").
    var restorableTrashURL: URL? {
        guard deletionMethod == .trash, let path = trashedAppPath else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
