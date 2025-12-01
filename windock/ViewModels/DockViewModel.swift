import SwiftUI
import AppKit
import Observation

@Observable
class DockViewModel {
    var apps: [DockApp] = []
    
    // The app currently showing its window previews
    var selectedAppForPreview: DockApp? = nil
    
    // Track hover state for magnification effects
    var hoveredAppId: String? = nil // Changed to String to match DockApp.id
    
    // Track content width for window resizing
    var contentWidth: CGFloat = 0

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

    @objc func refreshRunningApps() {
        DispatchQueue.main.async {
            // Filter for apps that have a UI (ActivationPolicy.regular)
            let runningApps = self.workspace.runningApplications.filter { $0.activationPolicy == .regular }
            
            self.apps = runningApps.map { nsApp in
                DockApp(
                    name: nsApp.localizedName ?? "App",
                    bundleIdentifier: nsApp.bundleIdentifier ?? UUID().uuidString,
                    icon: nsApp.icon,
                    isRunning: true,
                    // Note: Getting real window snapshots for *other* apps requires
                    // Screen Recording permissions and complex CGWindowList APIs.
                    // We will keep the window list empty or mock it for now.
                    openWindows: []
                )
            }
        }
    }

    func handleAppClick(_ app: DockApp) {
        // 1. Activate the real app
        if let runningApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            runningApp.activate(options: .activateIgnoringOtherApps)
        }
        
        // 2. Toggle preview logic (kept for when we add real window logic later)
        if selectedAppForPreview?.id == app.id {
            withAnimation(.snappy) {
                selectedAppForPreview = nil
            }
        } else {
            // Only show if there are windows (currently empty in this step)
            if !app.openWindows.isEmpty {
                withAnimation(.bouncy(duration: 0.3, extraBounce: 0.1)) {
                    selectedAppForPreview = app
                }
            }
        }
    }
}
