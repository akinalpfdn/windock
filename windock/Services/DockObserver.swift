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
        print("[DockObserver] Setting up...")
        print("[DockObserver] AX trusted: \(AXIsProcessTrusted())")

        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            print("[DockObserver] ERROR: Dock process not found")
            return
        }

        currentDockPID = dockApp.processIdentifier
        print("[DockObserver] Dock PID: \(currentDockPID)")
        let dockAppElement = AXUIElementCreateApplication(currentDockPID)

        // Find the AXList child (the actual dock bar)
        guard let dockList = findDockList(in: dockAppElement) else {
            print("[DockObserver] ERROR: Could not find AXList in Dock")
            return
        }
        dockListElement = dockList
        print("[DockObserver] Found dock list element")

        // Create observer for selected children changes (= hover)
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, element, notification, refcon in
            guard let refcon else { return }
            let notifStr = notification as String
            print("[DockObserver] Callback fired: \(notifStr)")
            let this = Unmanaged<DockObserver>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async { this.handleSelectionChanged() }
        }

        let createResult = AXObserverCreate(currentDockPID, callback, &observer)
        guard createResult == .success, let observer else {
            print("[DockObserver] ERROR: AXObserverCreate failed: \(createResult.rawValue)")
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let addResult = AXObserverAddNotification(observer, dockList, kAXSelectedChildrenChangedNotification as CFString, refcon)
        print("[DockObserver] AXObserverAddNotification result: \(addResult.rawValue) (0=success)")

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)

        axObserver = observer
        print("[DockObserver] Setup complete - listening for dock hover events")
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
        print("[DockObserver] handleSelectionChanged called")
        guard let dockList = dockListElement else {
            print("[DockObserver] ERROR: dockListElement is nil")
            return
        }

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
        // Read the URL attribute to get the app's bundle URL
        var urlRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockItem, kAXURLAttribute as CFString, &urlRef) == .success,
              let url = urlRef as? URL ?? (urlRef as? NSURL)?.absoluteURL else {
            return nil
        }

        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else { return nil }

        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
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
