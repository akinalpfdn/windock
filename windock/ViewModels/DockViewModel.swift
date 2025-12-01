import SwiftUI
import Observation

@Observable
class DockViewModel {
    var apps: [DockApp] = []
    
    // The app currently showing its window previews
    var selectedAppForPreview: DockApp? = nil
    
    // Track hover state for magnification effects
    var hoveredAppId: UUID? = nil

    init() {
        loadMockData()
    }

    // Handles the core logic requested: Click -> Toggle Preview
    func handleAppClick(_ app: DockApp) {
        if app.isRunning {
            if selectedAppForPreview?.id == app.id {
                // Toggle off if clicking the same app
                withAnimation(.snappy) {
                    selectedAppForPreview = nil
                }
            } else {
                // Show preview if it has windows
                if !app.openWindows.isEmpty {
                    withAnimation(.bouncy(duration: 0.3, extraBounce: 0.1)) {
                        selectedAppForPreview = app
                    }
                }
            }
        } else {
            // Logic to launch app would go here
            toggleAppRunningState(app)
        }
    }
    
    // MARK: - Simulation Logic
    
    private func toggleAppRunningState(_ app: DockApp) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        
        apps[index].isRunning.toggle()
        
        // If we just "launched" it, give it some dummy windows
        if apps[index].isRunning {
            apps[index].openWindows = [
                WindowInfo(title: "\(app.name) - Main", previewColor: .blue.opacity(0.5)),
                WindowInfo(title: "\(app.name) - Settings", previewColor: .gray.opacity(0.5))
            ]
        } else {
            apps[index].openWindows = []
            if selectedAppForPreview?.id == app.id {
                selectedAppForPreview = nil
            }
        }
    }

    private func loadMockData() {
        self.apps = [
            DockApp(name: "Finder", iconName: "face.smiling", isRunning: true, openWindows: [
                WindowInfo(title: "Downloads", previewColor: .blue),
                WindowInfo(title: "Documents", previewColor: .cyan),
                WindowInfo(title: "Desktop", previewColor: .indigo)
            ]),
            DockApp(name: "Safari", iconName: "safari", isRunning: true, openWindows: [
                WindowInfo(title: "Apple.com", previewColor: .white),
                WindowInfo(title: "GitHub", previewColor: .black)
            ]),
            DockApp(name: "Messages", iconName: "message.fill", isRunning: false, openWindows: []),
            DockApp(name: "Mail", iconName: "envelope.fill", isRunning: true, openWindows: [
                WindowInfo(title: "Inbox (2)", previewColor: .blue)
            ]),
            DockApp(name: "Terminal", iconName: "terminal.fill", isRunning: false, openWindows: [])
        ]
    }
}
