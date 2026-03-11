import AppKit

/// Aero Peek: shows a window's thumbnail at its actual screen position as an overlay.
/// No hierarchy changes, no full-screen dim — just the thumbnail floating in place.
final class WindowHighlightOverlay {
    private var overlayWindow: NSWindow?

    /// Shows the thumbnail image at the window's screen position
    func peek(thumbnail: NSImage, bounds: CGRect) {
        guard let mainScreen = NSScreen.main else { return }
        let screenHeight = mainScreen.frame.height

        // Convert CG coordinates (top-left) to NS coordinates (bottom-left)
        let nsFrame = NSRect(
            x: bounds.origin.x,
            y: screenHeight - bounds.origin.y - bounds.height,
            width: bounds.width,
            height: bounds.height
        )

        if let existing = overlayWindow {
            existing.setFrame(nsFrame, display: false)
            (existing.contentView as? NSImageView)?.image = thumbnail
            existing.orderFrontRegardless()
            return
        }

        let window = NSWindow(
            contentRect: nsFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)) - 1)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .transient]

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: nsFrame.size))
        imageView.image = thumbnail
        imageView.imageScaling = .scaleAxesIndependently
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true
        imageView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
        imageView.layer?.borderWidth = 3

        window.contentView = imageView
        window.orderFrontRegardless()
        overlayWindow = window
    }

    /// Hides the overlay
    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}
