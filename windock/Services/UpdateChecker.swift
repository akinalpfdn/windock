import AppKit
import Sparkle
import UserNotifications

/// Manages app updates via Sparkle framework with gentle reminders for background apps
final class UpdateChecker: NSObject, SPUStandardUserDriverDelegate, UNUserNotificationCenterDelegate {
    static let shared = UpdateChecker()

    private var updaterController: SPUStandardUpdaterController!
    private var updateAction: (() -> Void)?

    private override init() {
        super.init()

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )

        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
    }

    /// Manually triggers an update check
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    // MARK: - SPUStandardUserDriverDelegate

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        // For background scheduled checks, show a notification instead of a hidden window
        guard state.userInitiated == false else { return }
        showUpdateNotification(version: update.displayVersionString)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        // User engaged with the update — dismiss any pending notification
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["windock-update"])
    }

    // MARK: - Notification

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func showUpdateNotification(version: String) {
        let content = UNMutableNotificationContent()
        content.title = "WinDock Update Available"
        content.body = "Version \(version) is ready to install."
        content.sound = .default
        content.categoryIdentifier = "UPDATE"

        let request = UNNotificationRequest(identifier: "windock-update", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier == "windock-update" else { return }
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            checkForUpdates()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
