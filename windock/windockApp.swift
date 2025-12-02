import SwiftUI
import AppKit

@main
struct WinDockApp: App {
    @State private var viewModel = DockViewModel()
    
    // Connect the AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .background(Color.clear)
        }
        .windowStyle(.hiddenTitleBar) // Basic SwiftUI hiding
        // We handle specific window styling in AppDelegate
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Delay slightly to ensure window is created
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                self.setupDockWindow(window)
            }
        }
    }
    
    private func setupDockWindow(_ window: NSWindow) {
        window.level = .floating // Floats above standard windows
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false

        // Allow the window to appear on all desktops (Spaces)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Remove standard window controls
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.remove(.titled)
        window.styleMask.remove(.closable)
        window.styleMask.remove(.miniaturizable)
        window.styleMask.remove(.resizable)

        // Use fixed window size to prevent layout loops
        if let screen = window.screen {
            let screenRect = screen.frame

            // Fixed size to accommodate both dock and preview
            let dockWidth: CGFloat = 800
            let dockHeight: CGFloat = 200 // Tall enough for preview

            // Center the window horizontally at the VERY BOTTOM
            let dockX = screenRect.midX - (dockWidth / 2)
            let dockY = screenRect.minY // Right at the bottom edge

            let newFrame = NSRect(
                x: dockX,
                y: dockY,
                width: dockWidth,
                height: dockHeight
            )
            window.setFrame(newFrame, display: true)
        }

        // Ignore mouse events in the transparent parts so you can click through to the desktop
        window.ignoresMouseEvents = false
    }
}
