import SwiftUI
import AppKit
import Observation

@Observable
class DockViewModel {
    var apps: [DockApp] = []

    // The app currently showing its window previews
    var selectedAppForPreview: DockApp? = nil

    // Track hover state for magnification effects
    var hoveredAppId: String? = nil

    private let workspace = NSWorkspace.shared

    init() {
        setupObservers()
        refreshRunningApps()
    }

    private func setupObservers() {
        let center = workspace.notificationCenter
        // Listen for apps launching and terminating
        center.addObserver(self, selector: #selector(refreshRunningApps), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(refreshRunningApps), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }

    private func generateMockWindows(for appName: String) -> [WindowInfo] {
        let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .yellow, .cyan]
        let windowCount = Int.random(in: 1...3) // Random 1-3 windows per app

        return (1...windowCount).map { index in
            let color = colors.randomElement() ?? .blue
            let title = "\(appName) Window \(index)"
            return WindowInfo(title: title, previewColor: color)
        }
    }

    @objc func refreshRunningApps() {
        DispatchQueue.main.async {
            // Filter for apps that have a UI (ActivationPolicy.regular)
            let runningApps = self.workspace.runningApplications.filter { $0.activationPolicy == .regular }
            
            self.apps = runningApps.map { nsApp in
                // Generate mock windows for demo purposes
                let mockWindows = self.generateMockWindows(for: nsApp.localizedName ?? "App")

                return DockApp(
                    name: nsApp.localizedName ?? "App",
                    bundleIdentifier: nsApp.bundleIdentifier ?? UUID().uuidString,
                    icon: nsApp.icon,
                    isRunning: true,
                    // Note: Getting real window snapshots for *other* apps requires
                    // Screen Recording permissions and complex CGWindowList APIs.
                    // For now, we'll use mock windows for demonstration.
                    openWindows: mockWindows
                )
            }
        }
    }

    func handleAppClick(_ app: DockApp) {
        // Hide preview on click and activate app
        withAnimation(.snappy) {
            selectedAppForPreview = nil
        }

        // Always activate the real app
        if let runningApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            runningApp.activate()
        }
    }

    func handleWindowClick(_ window: WindowInfo, in app: DockApp) {
        // For now, just activate the app (in real implementation, this would focus the specific window)
        if let runningApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            runningApp.activate()
        }

        // Hide the preview after clicking a window
        withAnimation(.snappy) {
            selectedAppForPreview = nil
        }
    }

    // DEAD SIMPLE HOVER - NO TIMERS, NO BOUNCE!
    func handleHoverChanged(appId: String, isHovering: Bool) {
        // Handle hover magnification
        withAnimation(.easeInOut(duration: 0.2)) {
            hoveredAppId = isHovering ? appId : nil
        }

        // Handle preview - IMMEDIATE, no delays, no timers!
        if isHovering {
            if let app = apps.first(where: { $0.id == appId }), !app.openWindows.isEmpty {
                withAnimation(.bouncy(duration: 0.3)) {
                    selectedAppForPreview = app
                }
            }
        } else {
            // Hide preview when not hovering
            withAnimation(.easeOut(duration: 0.2)) {
                selectedAppForPreview = nil
            }
        }
    }
}
