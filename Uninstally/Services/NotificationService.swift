import Foundation
import UserNotifications
import os

/// Thin wrapper around `UNUserNotificationCenter` for delivering native
/// completion notifications. Requests authorisation lazily on first use.
final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private var authorized = false

    private init() {}

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

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    /// Posts a general-purpose notification (used by the update pipeline).
    func post(title: String, body: String, sound: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound { content.sound = .default }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
