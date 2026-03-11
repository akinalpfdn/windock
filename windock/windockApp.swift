import SwiftUI
import AppKit
import ServiceManagement

@main
struct WinDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window - we only show the preview panel
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: DockViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermission()
        registerLoginItem()
        viewModel = DockViewModel()
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            print("WinDock needs Accessibility permission to monitor the Dock.")
        }
    }

    private func registerLoginItem() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("Failed to register login item: \(error)")
        }
    }
}
