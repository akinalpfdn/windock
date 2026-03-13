import AppKit
import SwiftUI

/// Non-activating floating panel for showing window previews above dock icons
final class PreviewPanel: NSPanel {

    /// Generation counter to cancel stale dismiss completion handlers
    private var dismissGeneration: UInt8 = 0

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Shows the panel with the given SwiftUI content at the specified position
    func show<Content: View>(content: Content, at origin: CGPoint, size: CGSize) {
        cancelDismiss()

        let hostingView = FirstMouseHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: size)
        contentView = hostingView

        let frame = NSRect(origin: origin, size: size)
        setFrame(frame, display: true)
        orderFrontRegardless()
    }

    /// Hides the panel with fade-out animation
    func dismiss() {
        let expectedTag = dismissGeneration &+ 1
        dismissGeneration = expectedTag

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.dismissGeneration == expectedTag else { return }
            self.orderOut(nil)
            self.alphaValue = 1
        })
    }

    /// Shows the panel with the given SwiftUI content at the specified position
    /// Cancels any in-flight dismiss animation to prevent race conditions.
    func cancelDismiss() {
        dismissGeneration &+= 1
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            self.animator().alphaValue = 1
        }
    }
}

// MARK: - First Mouse Hosting View

/// NSHostingView subclass that accepts first mouse click without requiring window activation
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
