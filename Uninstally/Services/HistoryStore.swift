import Foundation
import SwiftData
import Observation
import os

/// Owns the local SwiftData store for uninstall history and provides the small set
/// of operations the app needs: recording an uninstall, removing/clearing entries,
/// and pruning by the retention setting.
///
/// All data stays on device. Nothing is uploaded and no analytics are collected.
@MainActor
@Observable
final class HistoryStore {
    /// The SwiftData container, also injected into the SwiftUI environment so views
    /// can use `@Query`.
    let container: ModelContainer

    private var context: ModelContext { container.mainContext }

    init() {
        // Use a dedicated, explicitly-named store so history never collides with
        // any other SwiftData store on the system.
        let base = URL.applicationSupportDirectory.appending(path: "Uninstally", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let storeURL = base.appending(path: "UninstallHistory.store")
        do {
            let config = ModelConfiguration(url: storeURL)
            container = try ModelContainer(for: UninstallRecord.self, configurations: config)
        } catch {
            // Fall back to an in-memory store so the app never fails to launch.
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: UninstallRecord.self, configurations: config)
        }
    }

    /// Whether history recording is enabled (defaults to `true`).
    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppSettings.keepHistoryKey) as? Bool ?? true
    }

    // MARK: - Mutations

    /// Records a completed uninstall, honouring the "Keep Uninstall History"
    /// preference. `iconData` is a PNG captured before removal (the bundle may be
    /// gone by now).
    func record(app: AppInfo, result: UninstallResult, mode: DeletionMode, iconData: Data?) {
        guard isEnabled else { return }
        let record = UninstallRecord(
            appName: app.name,
            bundleIdentifier: app.bundleIdentifier,
            developer: app.developer,
            version: app.displayVersion,
            originalLocation: app.url.deletingLastPathComponent().path,
            filesRemoved: result.removedFileCount,
            storageRecovered: Int(result.reclaimedBytes),
            deletionMethod: mode,
            trashedAppPath: result.trashedAppURL?.path,
            iconData: iconData
        )
        context.insert(record)
        save()
    }

    func remove(_ record: UninstallRecord) {
        context.delete(record)
        save()
    }

    func clear() {
        try? context.delete(model: UninstallRecord.self)
        save()
    }

    /// Deletes records older than the current retention window.
    func prune() {
        guard let cutoff = HistoryRetention.stored.cutoffDate else { return }
        let predicate = #Predicate<UninstallRecord> { $0.dateUninstalled < cutoff }
        try? context.delete(model: UninstallRecord.self, where: predicate)
        save()
    }

    private func save() {
        do { try context.save() } catch {
            Logger.app.error("History save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
