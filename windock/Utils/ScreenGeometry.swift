import AppKit

/// Converts between CG global coordinates (top-left origin) and AppKit coordinates (bottom-left origin)
enum ScreenGeometry {

    // MARK: - Public Methods

    /// Converts a CG/AX rect to AppKit coordinates.
    /// Both systems are anchored to the primary display (`NSScreen.screens[0]`), not `NSScreen.main`,
    /// which follows keyboard focus and breaks the flip on multi-display setups.
    static func appKitRect(fromCG rect: CGRect) -> NSRect {
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        return NSRect(
            x: rect.origin.x,
            y: primaryMaxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Returns the screen containing the rect's center, falling back to the one with the largest overlap
    static func screen(containing rect: NSRect) -> NSScreen? {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return screen
        }
        return NSScreen.screens.max { overlapArea($0.frame, rect) < overlapArea($1.frame, rect) }
    }

    // MARK: - Private Methods

    private static func overlapArea(_ a: NSRect, _ b: NSRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
