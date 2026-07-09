import Foundation
import UserNotifications
import os

/// Wrapper around `UNUserNotificationCenter` for delivering native notifications
/// and handling their actions (e.g. the Trash-monitor "Scan Leftovers" button).
final class NotificationService: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private var authorized = false

    /// Category + action identifiers for the Trash-monitor notification.
    private static let trashCategory = "trashLeftovers"
    private static let scanAction = "scanLeftovers"
    private static let dismissAction = "dismiss"

    /// Invoked (on the main actor) when the user taps "Scan Leftovers", with the
    /// trashed application's URL. Set by the app at launch.
    var onScanLeftovers: (@MainActor (URL) -> Void)?

    private override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    private func registerCategories() {
        let scan = UNNotificationAction(identifier: Self.scanAction, title: "Scan Leftovers", options: [.foreground])
        let dismiss = UNNotificationAction(identifier: Self.dismissAction, title: "Dismiss", options: [])
        let category = UNNotificationCategory(
            identifier: Self.trashCategory,
            actions: [scan, dismiss],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorizationIfNeeded() {
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            self?.authorized = granted
        }
    }

    func postUninstallComplete(_ result: UninstallResult) {
        let content = UNMutableNotificationContent()
        content.title = result.succeeded ? "Uninstall Complete" : "Uninstall Finished with Issues"
        content.body = "\(result.appName) — \(Format.bytes(result.reclaimedBytes)) reclaimed, "
            + "\(result.removedFileCount) items removed."
        content.sound = .default
        add(content)
    }

    /// Posts a general-purpose notification.
    func post(title: String, body: String, sound: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound { content.sound = .default }
        add(content)
    }

    /// Posts the Trash-monitor notification with "Scan Leftovers" / "Dismiss".
    func postTrashLeftovers(appName: String, appURL: URL) {
        let content = UNMutableNotificationContent()
        content.title = "Application Moved to Trash"
        content.body = "Uninstally found leftover files for \(appName). Would you like to remove them?"
        content.categoryIdentifier = Self.trashCategory
        content.userInfo = ["appPath": appURL.path]
        content.sound = .default
        add(content)
    }

    private func add(_ content: UNMutableNotificationContent) {
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == Self.scanAction
            || response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        guard let path = response.notification.request.content.userInfo["appPath"] as? String else { return }
        let url = URL(fileURLWithPath: path)
        await MainActor.run { self.onScanLeftovers?(url) }
    }
}
