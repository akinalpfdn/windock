import AppKit
import ApplicationServices

// Private Accessibility API for getting CGWindowID from AXUIElement
@_silgen_name("_AXUIElementGetWindow")
func AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Manages window-level operations using Accessibility API
enum WindowManager {

    /// Brings a specific window to front using AXUIElement
    @discardableResult
    static func focusWindow(windowID: CGWindowID, pid: pid_t) -> Bool {
        guard let runningApp = NSRunningApplication(processIdentifier: pid) else { return false }
        runningApp.activate()

        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement] else {
            return false
        }

        for axWindow in axWindows {
            guard cgWindowID(of: axWindow) == windowID else { continue }
            AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            return true
        }

        return false
    }

    /// Extracts the CGWindowID from an AXUIElement window
    private static func cgWindowID(of element: AXUIElement) -> CGWindowID? {
        var wid: CGWindowID = 0
        let result = AXUIElementGetWindow(element, &wid)
        return result == .success ? wid : nil
    }
}
