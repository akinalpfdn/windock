import AppKit
import ApplicationServices

/// Observes macOS Dock hover events via Accessibility API
final class DockObserver {
    /// Called when a dock app icon is hovered, with the app info and icon screen rect
    var onDockItemHovered: ((NSRunningApplication, CGRect) -> Void)?
    /// Called when hover leaves dock items
    var onDockItemUnhovered: (() -> Void)?

    private var axObserver: AXObserver?
    private var dockListElement: AXUIElement?
    private var currentDockPID: pid_t = 0
    private var healthCheckTimer: Timer?

    init() {
        setupObserver()
        startHealthCheck()
    }

    deinit {
        healthCheckTimer?.invalidate()
        if let observer = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }

    // MARK: - Setup

    private func setupObserver() {
        guard AXIsProcessTrusted() else { return }

        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return
        }

        currentDockPID = dockApp.processIdentifier
        let dockAppElement = AXUIElementCreateApplication(currentDockPID)

        // Find the AXList child (the actual dock bar)
        guard let dockList = findDockList(in: dockAppElement) else {
            return
        }
        dockListElement = dockList

        // Create observer for selected children changes (= hover)
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, element, notification, refcon in
            guard let refcon else { return }
            let this = Unmanaged<DockObserver>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async { this.handleSelectionChanged() }
        }

        let createResult = AXObserverCreate(currentDockPID, callback, &observer)
        guard createResult == .success, let observer else {
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, dockList, kAXSelectedChildrenChangedNotification as CFString, refcon)

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)

        axObserver = observer
    }

    /// Periodically verifies the Dock process is still alive and re-subscribes if needed
    private func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let dockApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
            if dockApps.first?.processIdentifier != self.currentDockPID {
                self.tearDown()
                self.setupObserver()
            }
        }
    }

    private func tearDown() {
        if let observer = axObserver, let list = dockListElement {
            AXObserverRemoveNotification(observer, list, kAXSelectedChildrenChangedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        axObserver = nil
        dockListElement = nil
    }

    // MARK: - Event Handling

    private func handleSelectionChanged() {
        guard let dockList = dockListElement else { return }

        // Get the currently selected (hovered) dock item
        var selectedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockList, kAXSelectedChildrenAttribute as CFString, &selectedRef) == .success,
              let selectedItems = selectedRef as? [AXUIElement],
              let hoveredItem = selectedItems.first else {
            onDockItemUnhovered?()
            return
        }

        // Only care about application dock items
        guard subrole(of: hoveredItem) == "AXApplicationDockItem" else {
            onDockItemUnhovered?()
            return
        }

        // Resolve to a running application
        guard let app = resolveRunningApp(from: hoveredItem) else {
            onDockItemUnhovered?()
            return
        }

        // Get the icon's screen position
        let iconRect = screenRect(of: hoveredItem)
        onDockItemHovered?(app, iconRect)
    }

    // MARK: - AX Helpers

    private func findDockList(in appElement: AXUIElement) -> AXUIElement? {
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }

        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            if let role = roleRef as? String, role == kAXListRole {
                return child
            }
        }
        return nil
    }

    private func subrole(of element: AXUIElement) -> String? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &ref)
        return ref as? String
    }

    private func resolveRunningApp(from dockItem: AXUIElement) -> NSRunningApplication? {
        // Try URL attribute first
        var urlRef: CFTypeRef?
        let urlResult = AXUIElementCopyAttributeValue(dockItem, kAXURLAttribute as CFString, &urlRef)

        if urlResult == .success, let url = urlRef as? URL ?? (urlRef as? NSURL)?.absoluteURL {
            if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier,
               let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
                return app
            }
        }

        // Fallback: match by dock item title against running app names
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(dockItem, kAXTitleAttribute as CFString, &titleRef) == .success,
           let title = titleRef as? String,
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == title }) {
            return app
        }

        return nil
    }

    private func screenRect(of element: AXUIElement) -> CGRect {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)

        var point = CGPoint.zero
        var size = CGSize.zero

        if let posRef { AXValueGetValue(posRef as! AXValue, .cgPoint, &point) }
        if let sizeRef { AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) }

        return CGRect(origin: point, size: size)
    }
}
