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
                // Listen for changes in the preview state to resize the window dynamically
                .onChange(of: viewModel.selectedAppForPreview) { _, newValue in
                    appDelegate.updateDockHeight(expanded: newValue != nil)
                }
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
        
        // Initial Position (Collapsed state)
        if let screen = window.screen {
            let screenRect = screen.frame
            // Default to the collapsed height (95px)
            let dockHeight: CGFloat = 95
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
    
    // Helper to animate the dock height
    func updateDockHeight(expanded: Bool) {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first,
                  let screen = window.screen else { return }
            
            let screenRect = screen.frame
            let newHeight: CGFloat = expanded ? 300 : 95
            
            let newFrame = NSRect(
                x: screenRect.minX,
                y: screenRect.minY,
                width: screenRect.width,
                height: newHeight
            )
            
            // animate: true creates a smooth native macOS window transition
            window.setFrame(newFrame, display: true, animate: true)
        }
    }
}
