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
                
                // Position at bottom of screen
                if let screen = window.screen {
                    let screenRect = screen.frame
                    // Restrict window to bottom 150pt to prevent blocking the whole screen
                    let dockHeight: CGFloat = 150
                    let newFrame = NSRect(
                        x: screenRect.minX,
                        y: screenRect.minY,
                        width: screenRect.width,
                        height: dockHeight
                    )
                    window.setFrame(newFrame, display: true)
                }
                
                // Ignore mouse events in the transparent parts so you can click through to the desktop
                window.ignoresMouseEvents = false
            }
        }
    }
}
