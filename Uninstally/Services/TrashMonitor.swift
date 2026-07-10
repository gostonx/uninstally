import Foundation
import Observation
import os

extension Notification.Name {
    /// Posted when the "Monitor Trash" preference changes, so the running monitor
    /// can start/stop immediately.
    static let trashMonitorPreferenceChanged = Notification.Name("trashMonitorPreferenceChanged")
}

/// Watches the user's Trash and, when a supported bundle (`.app`, `.component`,
/// `.vst`, `.vst3`, `.aaxplugin`, `.clap`) appears there, offers to remove the
/// application's or plug-in's leftover files.
///
/// Uses a `DispatchSource` file-system-object observer on the Trash directory —
/// event-driven, so it consumes virtually no CPU while idle (no polling). New
/// bundles are detected only *after* the move completes (debounced), and each
/// is reported once (duplicate events are ignored).
///
/// Independent of the uninstall engine: it only detects and notifies.
@MainActor
@Observable
final class TrashMonitor {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var debounceTask: Task<Void, Never>?
    /// Supported bundle paths already present/handled, so only genuinely new ones
    /// notify.
    private var seenBundlePaths: Set<String> = []

    private let trashURL: URL? = try? FileManager.default.url(
        for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false
    )

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppSettings.monitorTrashKey) as? Bool ?? true
    }

    // MARK: - Lifecycle

    /// Starts monitoring if the preference is enabled. Idempotent.
    func start() {
        guard isEnabled, source == nil, let trashURL else { return }

        let fd = open(trashURL.path, O_EVTONLY)
        guard fd >= 0 else {
            Logger.app.error("TrashMonitor: couldn't open Trash for watching.")
            return
        }
        fileDescriptor = fd

        // Seed with what's already there so we only react to newly-added bundles.
        seenBundlePaths = currentBundlePaths()

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main
        )
        src.setEventHandler { [weak self] in self?.scheduleScan() }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 { close(fd) }
            self?.fileDescriptor = -1
        }
        source = src
        src.resume()
    }

    func stop() {
        debounceTask?.cancel()
        source?.cancel()
        source = nil
    }

    /// Re-evaluates the preference: start or stop accordingly.
    func refresh() {
        if isEnabled { start() } else { stop() }
    }

    // MARK: - Detection

    /// Debounce so we only act once the Finder move has fully settled.
    private func scheduleScan() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            self?.detectNewBundles()
        }
    }

    private func currentBundlePaths() -> Set<String> {
        guard let trashURL,
              let entries = try? FileManager.default.contentsOfDirectory(
                  at: trashURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
              ) else { return [] }
        return Set(entries.filter { LibraryPaths.isSupportedBundle($0) }.map(\.standardizedFileURL.path))
    }

    private func detectNewBundles() {
        let current = currentBundlePaths()
        let newlyAdded = current.subtracting(seenBundlePaths)
        seenBundlePaths = current
        guard !newlyAdded.isEmpty else { return }

        // Inspect off the main actor (size calculation can be heavy), then notify.
        let scanner = ApplicationScanner()
        for path in newlyAdded {
            Task.detached { [weak self] in
                guard let app = scanner.inspect(bundleURL: URL(fileURLWithPath: path)) else { return }
                await self?.notify(app)
            }
        }
    }

    private func notify(_ bundle: AppInfo) {
        Logger.app.log("TrashMonitor: detected \(bundle.name, privacy: .public) in Trash")
        NotificationService.shared.postTrashLeftovers(appName: bundle.name, appURL: bundle.url)
    }
}
