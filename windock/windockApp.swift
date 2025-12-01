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
                .onPreferenceChange(SizePreferenceKey.self) { size in
                    viewModel.contentWidth = size.width
                    appDelegate.updateWindowFrame(width: size.width, expanded: viewModel.selectedAppForPreview != nil)
                }
                // Listen for changes in the preview state to resize the window dynamically
                .onChange(of: viewModel.selectedAppForPreview) { _, newValue in
                    appDelegate.updateWindowFrame(width: viewModel.contentWidth, expanded: newValue != nil)
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
            // Default to the collapsed height (120px)
            let dockHeight: CGFloat = 120
            
            // Initial width estimate (will be updated by SwiftUI)
            let initialWidth: CGFloat = 600
            let initialX = screenRect.midX - (initialWidth / 2)
            
            let newFrame = NSRect(
                x: initialX,
                y: screenRect.minY,
                width: initialWidth,
                height: dockHeight
            )
            window.setFrame(newFrame, display: true)
        }
        
        // Ignore mouse events in the transparent parts so you can click through to the desktop
        window.ignoresMouseEvents = false
    }
    
    // Helper to animate the dock frame
    func updateWindowFrame(width: CGFloat, expanded: Bool) {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first,
                  let screen = window.screen else { return }
            
            let screenRect = screen.frame
            let newHeight: CGFloat = expanded ? 300 : 120
            
            // Ensure minimum width to avoid glitches
            let targetWidth = max(width, 100)
            
            // Center the window horizontally
            let newX = screenRect.midX - (targetWidth / 2)
            
            let newFrame = NSRect(
                x: newX,
                y: screenRect.minY,
                width: targetWidth,
                height: newHeight
            )
            
            // Avoid redundant frame updates
            if abs(window.frame.height - newHeight) < 1 && abs(window.frame.width - targetWidth) < 1 {
                return
            }
            
            // animate: false is CRITICAL here. 
            // SwiftUI is already animating the content size (width/height) frame-by-frame.
            // If we ask the window server to also animate (interpolate) the window frame, 
            // it creates a conflict and a layout loop, leading to the crash.
            window.setFrame(newFrame, display: true, animate: false)
        }
    }
}
