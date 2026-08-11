import SwiftUI
import AppKit
import Observation

enum DockPosition {
    case bottom, left, right
}

/// Coordinates dock hover detection, window preview, and panel display
@Observable
final class DockViewModel {
    private(set) var hoveredApp: DockApp?
    private(set) var windows: [WindowInfo] = []
    var isPreviewHovered = false

    private let dockObserver = DockObserver()
    private let previewPanel = PreviewPanel()
    private let highlightOverlay = WindowHighlightOverlay()
    private let workspace = NSWorkspace.shared
    private var dismissTask: DispatchWorkItem?
    private var currentBundleId: String?
    private var currentDockIconRect: CGRect?
    private var currentDockPosition: DockPosition = .bottom
    private var mouseTrackingTimer: Timer?

    private enum HoverTracking {
        static let pollInterval: TimeInterval = 0.05
        static let dismissDelay: TimeInterval = 0.2
        static let hitTolerance: CGFloat = 4
    }

    init() {
        dockObserver.onDockItemHovered = { [weak self] app, iconRect in
            self?.handleDockHover(app: app, iconRect: iconRect)
        }
        dockObserver.onDockItemUnhovered = { [weak self] in
            self?.reconcilePointerState()
        }
    }

    // MARK: - Dock Hover

    private func handleDockHover(app: NSRunningApplication, iconRect: CGRect) {
        let bundleId = app.bundleIdentifier ?? ""
        currentDockIconRect = iconRect
        cancelDismiss()

        // A repeated hover callback for the same app must still cancel any stale
        // dismiss request and refresh the icon hit target.
        if bundleId == currentBundleId, previewPanel.isVisible {
            reconcilePointerState()
            return
        }

        currentBundleId = bundleId

        let appWindows = getWindows(for: app)
        guard !appWindows.isEmpty else {
            dismissPreview()
            return
        }

        let dockApp = DockApp(
            name: app.localizedName ?? "App",
            bundleIdentifier: bundleId,
            icon: app.icon,
            isRunning: true,
            openWindows: appWindows
        )

        hoveredApp = dockApp
        windows = appWindows
        showPreview(iconRect: iconRect)

        // Capture thumbnails async
        Task { @MainActor in
            await self.refreshThumbnails(pid: app.processIdentifier)
        }
    }

    // MARK: - Preview Display

    private func showPreview(iconRect: CGRect) {
        guard hoveredApp != nil else { return }

        let dockPosition = detectDockPosition(iconRect: iconRect)
        currentDockPosition = dockPosition
        let content = makePreviewContent(dockPosition: dockPosition)
        let previewSize = calculatePreviewSize(dockPosition: dockPosition)
        let origin = calculatePreviewOrigin(iconRect: iconRect, previewSize: previewSize, dockPosition: dockPosition)

        previewPanel.alphaValue = 1
        previewPanel.show(content: content, at: origin, size: previewSize)
        startMouseTracking()
        reconcilePointerState()
    }

    /// Updates the preview content without repositioning the panel
    private func updatePreviewContent() {
        guard hoveredApp != nil else { return }

        let content = makePreviewContent(dockPosition: currentDockPosition)
        // Rebuild the hosting view after thumbnails arrive. Updating rootView in
        // place can leave SwiftUI's ForEach rows displaying the initial nil-image
        // state even though ScreenCaptureKit successfully returned thumbnails.
        // Pointer lifetime is tracked independently by the polling timer, so
        // replacing this view no longer causes the preview to dismiss.
        let hostingView = FirstMouseHostingView(rootView: content)
        hostingView.frame = previewPanel.contentView?.bounds ?? .zero
        previewPanel.contentView = hostingView
    }

    private func makePreviewContent(dockPosition: DockPosition) -> PreviewPanelContent {
        PreviewPanelContent(
            dockPosition: dockPosition,
            app: hoveredApp!,
            windows: windows,
            onWindowClick: { [weak self] window in
                self?.handleWindowClick(window)
            },
            onWindowClose: { [weak self] window in
                self?.handleWindowClose(window)
            },
            onWindowHover: { [weak self] window in
                self?.handleWindowHighlight(window)
            },
            onHoverChanged: { [weak self] isHovering in
                self?.handlePreviewHover(isHovering)
            }
        )
    }

    private func detectDockPosition(iconRect: CGRect) -> DockPosition {
        guard let screen = NSScreen.main else { return .bottom }

        let threshold: CGFloat = 80
        if iconRect.minX < screen.frame.minX + threshold {
            return .left
        } else if iconRect.maxX > screen.frame.maxX - threshold {
            return .right
        }
        return .bottom
    }

    private func calculatePreviewSize(dockPosition: DockPosition) -> CGSize {
        let count = CGFloat(max(windows.count, 1))
        let cardWidth = Layout.Preview.thumbnailWidth + Layout.Preview.cardPadding * 2
        let cardHeight: CGFloat = Layout.Preview.thumbnailHeight + 60

        switch dockPosition {
        case .bottom:
            let totalWidth = count * cardWidth + (count - 1) * Layout.Preview.cardSpacing + Layout.Preview.containerPadding * 2
            let height = cardHeight + Layout.Preview.containerPadding * 2
            return CGSize(width: min(totalWidth, 800), height: height)
        case .left, .right:
            let width = cardWidth + Layout.Preview.containerPadding * 2
            let totalHeight = count * cardHeight + (count - 1) * Layout.Preview.cardSpacing + Layout.Preview.containerPadding * 2
            return CGSize(width: width, height: min(totalHeight, 600))
        }
    }

    private func calculatePreviewOrigin(iconRect: CGRect, previewSize: CGSize, dockPosition: DockPosition) -> CGPoint {
        // iconRect is in CG coordinates (origin at top-left)
        // NSWindow uses NS coordinates (origin at bottom-left)
        guard let screen = NSScreen.main else {
            return CGPoint(x: iconRect.midX - previewSize.width / 2, y: 0)
        }

        let screenHeight = screen.frame.height
        let buffer = Layout.Preview.bufferFromDock

        switch dockPosition {
        case .bottom:
            let iconBottomNS = screenHeight - iconRect.maxY
            let x = max(screen.frame.minX, min(
                iconRect.midX - previewSize.width / 2,
                screen.frame.maxX - previewSize.width
            ))
            let y = iconBottomNS + iconRect.height + buffer
            return CGPoint(x: x, y: y)

        case .left:
            let x = iconRect.maxX + buffer
            let iconMidNS = screenHeight - iconRect.midY
            let y = max(screen.frame.minY, min(
                iconMidNS - previewSize.height / 2,
                screen.frame.maxY - previewSize.height
            ))
            return CGPoint(x: x, y: y)

        case .right:
            let x = iconRect.minX - previewSize.width - buffer
            let iconMidNS = screenHeight - iconRect.midY
            let y = max(screen.frame.minY, min(
                iconMidNS - previewSize.height / 2,
                screen.frame.maxY - previewSize.height
            ))
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Window Interaction

    private func handleWindowClick(_ window: WindowInfo) {
        guard let hoveredApp else { return }

        dismissPreview()

        if let runningApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == hoveredApp.bundleIdentifier }) {
            if !WindowManager.focusWindow(windowID: window.id, pid: runningApp.processIdentifier) {
                runningApp.activate()
            }
        }
    }

    private func handleWindowClose(_ window: WindowInfo) {
        guard let hoveredApp,
              let runningApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == hoveredApp.bundleIdentifier }) else { return }

        WindowManager.closeWindow(windowID: window.id, pid: runningApp.processIdentifier)

        // Remove the closed window from the list and refresh preview
        windows.removeAll { $0.id == window.id }
        if windows.isEmpty {
            dismissPreview()
        } else {
            updatePreviewContent()
        }
    }

    // MARK: - Aero Peek

    private func handleWindowHighlight(_ window: WindowInfo?) {
        if let window, let thumbnail = window.thumbnail {
            highlightOverlay.peek(thumbnail: thumbnail, bounds: window.bounds)
        } else {
            highlightOverlay.hide()
        }
    }

    // MARK: - Dismiss Logic

    func handlePreviewHover(_ isHovering: Bool) {
        isPreviewHovered = isHovering
        reconcilePointerState()
    }

    private func scheduleDismiss() {
        guard previewPanel.isVisible, dismissTask == nil else { return }

        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.dismissTask = nil
            guard !self.isPointerInInteractiveRegion() else { return }
            self.dismissPreview()
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + HoverTracking.dismissDelay, execute: task)
    }

    private func cancelDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    private func dismissPreview() {
        cancelDismiss()
        stopMouseTracking()
        previewPanel.dismiss()
        highlightOverlay.hide()
        hoveredApp = nil
        windows = []
        currentBundleId = nil
        currentDockIconRect = nil
        isPreviewHovered = false
    }

    // MARK: - Pointer Tracking

    /// Polling `NSEvent.mouseLocation` keeps working while the cursor is over the
    /// Dock or another app, unlike a local event monitor which only sees WinDock's
    /// own events. The timer only exists while a preview is visible.
    private func startMouseTracking() {
        guard mouseTrackingTimer == nil else { return }

        let timer = Timer(timeInterval: HoverTracking.pollInterval, repeats: true) { [weak self] _ in
            self?.reconcilePointerState()
        }
        RunLoop.main.add(timer, forMode: .common)
        mouseTrackingTimer = timer
    }

    private func stopMouseTracking() {
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
    }

    private func reconcilePointerState() {
        guard previewPanel.isVisible else { return }

        isPreviewHovered = isPointerOverPreview()
        if isPointerInInteractiveRegion() {
            cancelDismiss()
        } else {
            scheduleDismiss()
        }
    }

    private func isPointerInInteractiveRegion() -> Bool {
        isPointerOverDockIcon() || isPointerOverPreview()
    }

    private func isPointerOverDockIcon() -> Bool {
        guard let iconRect = currentDockIconRect,
              let mouseLocation = CGEvent(source: nil)?.location else { return false }

        return iconRect
            .insetBy(dx: -HoverTracking.hitTolerance, dy: -HoverTracking.hitTolerance)
            .contains(mouseLocation)
    }

    private func isPointerOverPreview() -> Bool {
        guard previewPanel.isVisible else { return false }

        return previewPanel.frame
            .insetBy(dx: -HoverTracking.hitTolerance, dy: -HoverTracking.hitTolerance)
            .contains(NSEvent.mouseLocation)
    }

    // MARK: - Window Enumeration

    private func getWindows(for app: NSRunningApplication) -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: AnyObject]] else {
            return []
        }

        return windowList.compactMap { info in
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                ownerPID == app.processIdentifier,
                let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                let name = info[kCGWindowName as String] as? String, !name.isEmpty,
                let windowID = info[kCGWindowNumber as String] as? CGWindowID
            else {
                return nil
            }

            let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat]
            let bounds = CGRect(
                x: boundsDict?["X"] ?? 0,
                y: boundsDict?["Y"] ?? 0,
                width: boundsDict?["Width"] ?? 0,
                height: boundsDict?["Height"] ?? 0
            )

            return WindowInfo(id: windowID, title: name, thumbnail: nil, bounds: bounds)
        }
    }

    // MARK: - Thumbnail Capture

    @MainActor
    private func refreshThumbnails(pid: pid_t) async {
        let windowIDs = windows.map(\.id)
        let thumbnails = await WindowCaptureService.captureThumbnails(windowIDs: windowIDs)

        // Only update if still showing the same app
        guard hoveredApp?.bundleIdentifier == currentBundleId else { return }

        windows = windows.map { window in
            WindowInfo(id: window.id, title: window.title, thumbnail: thumbnails[window.id] ?? window.thumbnail, bounds: window.bounds)
        }
        hoveredApp?.openWindows = windows

        updatePreviewContent()
    }
}
