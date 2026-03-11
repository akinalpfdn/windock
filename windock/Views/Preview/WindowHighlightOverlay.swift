import AppKit

/// Transparent overlay that highlights a window's actual screen position
final class WindowHighlightOverlay {
    private var overlayWindow: NSWindow?

    /// Shows a highlight border at the window's screen position
    func show(bounds: CGRect) {
        guard let screen = NSScreen.main else { return }

        // Convert CG coordinates (top-left origin) to NS coordinates (bottom-left origin)
        let screenHeight = screen.frame.height
        let nsOrigin = CGPoint(
            x: bounds.origin.x,
            y: screenHeight - bounds.origin.y - bounds.height
        )
        let nsFrame = NSRect(origin: nsOrigin, size: bounds.size)

        if let existing = overlayWindow {
            existing.setFrame(nsFrame, display: true)
            existing.orderFrontRegardless()
            return
        }

        let window = NSWindow(
            contentRect: nsFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .transient]

        // Blue highlight border with subtle fill
        let contentView = NSView(frame: NSRect(origin: .zero, size: nsFrame.size))
        contentView.wantsLayer = true
        contentView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
        contentView.layer?.borderWidth = 3
        contentView.layer?.cornerRadius = 8
        contentView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor

        window.contentView = contentView
        window.orderFrontRegardless()
        overlayWindow = window
    }

    /// Hides the highlight overlay
    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}
