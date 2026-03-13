import SwiftUI
import AppKit
import Observation

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

    init() {
        dockObserver.onDockItemHovered = { [weak self] app, iconRect in
            self?.handleDockHover(app: app, iconRect: iconRect)
        }
        dockObserver.onDockItemUnhovered = { [weak self] in
            self?.scheduleDismiss()
        }
    }

    // MARK: - Dock Hover

    private func handleDockHover(app: NSRunningApplication, iconRect: CGRect) {
        let bundleId = app.bundleIdentifier ?? ""

        // Same app already showing - skip
        if bundleId == currentBundleId, previewPanel.isVisible { return }

        cancelDismiss()
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
        guard let hoveredApp else { return }

        let content = makePreviewContent()
        let previewSize = calculatePreviewSize()
        let origin = calculatePreviewOrigin(iconRect: iconRect, previewSize: previewSize)

        previewPanel.alphaValue = 1
        previewPanel.show(content: content, at: origin, size: previewSize)
    }

    /// Updates the preview content without repositioning the panel
    private func updatePreviewContent() {
        guard hoveredApp != nil else { return }

        let content = makePreviewContent()
        let hostingView = FirstMouseHostingView(rootView: content)
        hostingView.frame = previewPanel.contentView?.bounds ?? .zero
        previewPanel.contentView = hostingView
    }

    private func makePreviewContent() -> PreviewPanelContent {
        PreviewPanelContent(
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

    private func calculatePreviewSize() -> CGSize {
        let count = CGFloat(max(windows.count, 1))
        let cardWidth = Layout.Preview.thumbnailWidth + Layout.Preview.cardPadding * 2
        let totalWidth = count * cardWidth + (count - 1) * Layout.Preview.cardSpacing + Layout.Preview.containerPadding * 2
        let height: CGFloat = Layout.Preview.thumbnailHeight + 60 + Layout.Preview.containerPadding * 2
        return CGSize(width: min(totalWidth, 800), height: height)
    }

    private func calculatePreviewOrigin(iconRect: CGRect, previewSize: CGSize) -> CGPoint {
        // iconRect is in CG coordinates (origin at top-left)
        // NSWindow uses NS coordinates (origin at bottom-left)
        guard let screen = NSScreen.main else {
            return CGPoint(x: iconRect.midX - previewSize.width / 2, y: 0)
        }

        let screenHeight = screen.frame.height

        // Convert CG top-left Y to NS bottom-left Y
        let iconBottomNS = screenHeight - iconRect.maxY
        let bufferFromDock: CGFloat = 4

        let x = max(screen.frame.minX, min(
            iconRect.midX - previewSize.width / 2,
            screen.frame.maxX - previewSize.width
        ))
        let y = iconBottomNS + iconRect.height + bufferFromDock

        return CGPoint(x: x, y: y)
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
        if isHovering {
            cancelDismiss()
        } else {
            scheduleDismiss()
        }
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Check actual mouse position instead of relying solely on .onHover state,
            // which can get stuck when the content view is replaced (tracking areas lost)
            let mouseLocation = NSEvent.mouseLocation
            if self.previewPanel.isVisible, self.previewPanel.frame.contains(mouseLocation) {
                return
            }
            self.isPreviewHovered = false
            self.dismissPreview()
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    private func cancelDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    private func dismissPreview() {
        previewPanel.dismiss()
        highlightOverlay.hide()
        hoveredApp = nil
        windows = []
        currentBundleId = nil
        isPreviewHovered = false
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
