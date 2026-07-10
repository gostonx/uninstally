import Foundation
import Observation
#if canImport(Sparkle)
import Sparkle
#endif

/// The update delivery channel. `stable` maps to appcast items with no channel;
/// pre-release channels map to Sparkle `sparkle:channel` identifiers.
enum UpdateChannel: String, CaseIterable, Identifiable, Sendable {
    case stable
    case beta
    case nightly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stable: return "Stable"
        case .beta: return "Beta"
        case .nightly: return "Nightly"
        }
    }

    /// The Sparkle channel identifiers a subscriber to this channel may receive.
    /// Stable subscribers only get default (unmarked) items.
    var sparkleChannels: Set<String> {
        switch self {
        case .stable: return []
        case .beta: return ["beta"]
        case .nightly: return ["beta", "nightly"]
        }
    }
}

/// MVVM wrapper around Sparkle. Owns the `SPUStandardUpdaterController` (which
/// provides Sparkle's native, first-party-quality update UI: release notes,
/// download progress, install prompts) and exposes an observable summary plus the
/// user preferences for the Settings screen.
///
/// Security is enforced by Sparkle: the feed URL is pinned to
/// `https://codenta.us/appcast.xml`, and every update must carry a valid EdDSA
/// signature matching `SUPublicEDKey`. Unsigned, tampered, or off-feed updates are
/// rejected. Draft/pre-release items are filtered via channels unless the user
/// opts into betas.
///
/// The implementation degrades gracefully if the Sparkle package is unavailable so
/// the project always compiles.
@MainActor
@Observable
final class UpdateManager: NSObject {

    /// A concise, observable summary of the updater state for the UI.
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String)
        case error(String)
    }

    /// The canonical, only-trusted appcast feed.
    nonisolated static let feedURL = "https://codenta.us/appcast.xml"

    // MARK: Observable state

    private(set) var status: Status = .idle
    private(set) var latestVersion: String?
    private(set) var latestReleaseNotesHTML: String?
    private(set) var latestReleaseDate: String?
    private(set) var latestContentLength: UInt64 = 0

    /// Set true when an update is found — triggers the update prompt sheet.
    var showUpdatePrompt = false

    // MARK: Preferences

    var channel: UpdateChannel {
        didSet { UserDefaults.standard.set(channel.rawValue, forKey: AppSettings.updateChannelKey) }
    }

    var receiveBetaUpdates: Bool {
        didSet { UserDefaults.standard.set(receiveBetaUpdates, forKey: AppSettings.receiveBetaUpdatesKey) }
    }

    var automaticallyChecksForUpdates: Bool {
        didSet {
            #if canImport(Sparkle)
            controller?.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
            #endif
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        didSet {
            #if canImport(Sparkle)
            controller?.updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
            #endif
        }
    }

    // MARK: Derived

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var lastChecked: Date? {
        #if canImport(Sparkle)
        return controller?.updater.lastUpdateCheckDate
        #else
        return nil
        #endif
    }

    var canCheckForUpdates: Bool {
        #if canImport(Sparkle)
        return controller?.updater.canCheckForUpdates ?? false
        #else
        return false
        #endif
    }

    #if canImport(Sparkle)
    private var controller: SPUStandardUpdaterController?
    #endif

    // MARK: Init

    override init() {
        let defaults = UserDefaults.standard
        channel = UpdateChannel(rawValue: defaults.string(forKey: AppSettings.updateChannelKey) ?? "") ?? .stable
        receiveBetaUpdates = defaults.bool(forKey: AppSettings.receiveBetaUpdatesKey)
        automaticallyChecksForUpdates = defaults.object(forKey: "SUEnableAutomaticChecks") as? Bool ?? true
        automaticallyDownloadsUpdates = defaults.object(forKey: "SUAutomaticallyUpdate") as? Bool ?? false
        super.init()

        #if canImport(Sparkle)
        // Starts the updater immediately; Sparkle will perform a scheduled check on
        // launch and every `SUScheduledCheckInterval` (24h) thereafter.
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.controller = controller
        // Reflect Sparkle's persisted state back into our observable mirror.
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = controller.updater.automaticallyDownloadsUpdates
        #endif
    }

    // MARK: Actions

    /// A user-initiated check. Shows Sparkle's native UI if an update is found.
    func checkForUpdates() {
        #if canImport(Sparkle)
        guard status != .checking else { return } // prevent duplicate checks
        status = .checking
        NotificationService.shared.post(
            title: "Checking for Updates",
            body: "Uninstally is checking for a new version."
        )
        controller?.updater.checkForUpdates()
        #endif
    }

    /// A silent background check (used on launch). Only surfaces UI if appropriate.
    func checkForUpdatesInBackground() {
        #if canImport(Sparkle)
        guard status != .checking, canCheckForUpdates else { return }
        controller?.updater.checkForUpdatesInBackground()
        #endif
    }

    /// Clears a previously "skipped" version so it will be offered again.
    func clearIgnoredVersion() {
        UserDefaults.standard.removeObject(forKey: "SUSkippedVersion")
    }

    /// Restores all update-related preferences to their defaults.
    func resetUpdatePreferences() {
        let defaults = UserDefaults.standard
        for key in ["SUSkippedVersion", "SUEnableAutomaticChecks", "SUAutomaticallyUpdate",
                    AppSettings.updateChannelKey, AppSettings.receiveBetaUpdatesKey] {
            defaults.removeObject(forKey: key)
        }
        channel = .stable
        receiveBetaUpdates = false
        automaticallyChecksForUpdates = true
        automaticallyDownloadsUpdates = false
        status = .idle
        latestVersion = nil
    }
}

#if canImport(Sparkle)
extension UpdateManager: SPUUpdaterDelegate {
    /// Pin the feed so only the official appcast is ever trusted.
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        UpdateManager.feedURL
    }

    /// Gate pre-release channels behind the beta preference.
    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        MainActor.assumeIsolated {
            receiveBetaUpdates ? channel.sparkleChannels : []
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        MainActor.assumeIsolated {
            latestVersion = item.displayVersionString
            latestReleaseNotesHTML = item.itemDescription
            latestReleaseDate = item.dateString
            latestContentLength = item.contentLength
            status = .updateAvailable(version: item.displayVersionString)
            showUpdatePrompt = true
            NotificationService.shared.post(
                title: "Update Available",
                body: "Uninstally \(item.displayVersionString) is available to download.",
                sound: true
            )
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        MainActor.assumeIsolated {
            latestVersion = currentVersion
            status = .upToDate
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        MainActor.assumeIsolated {
            // Code 1001 is "no update found" style cancellation; keep it quiet.
            let nsError = error as NSError
            if nsError.code == 1001 { return }
            status = .error(error.localizedDescription)
        }
    }
}
#endif
