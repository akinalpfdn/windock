import AppKit
import Sparkle

/// Manages app updates via Sparkle framework
final class UpdateChecker: NSObject {
    static let shared = UpdateChecker()

    private var updaterController: SPUStandardUpdaterController!

    private override init() {
        super.init()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Starts automatic update checks
    func start() {
        updaterController.updater.automaticallyChecksForUpdates = true
        updaterController.updater.updateCheckInterval = 3600
        try? updaterController.updater.start()
    }

    /// Manually triggers an update check
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
