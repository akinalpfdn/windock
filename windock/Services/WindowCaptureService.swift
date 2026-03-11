import AppKit
import ScreenCaptureKit

/// Captures window thumbnails using ScreenCaptureKit
enum WindowCaptureService {

    /// Captures a thumbnail for a specific window
    static func captureThumbnail(windowID: CGWindowID) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            config.width = Int(scWindow.frame.width)
            config.height = Int(scWindow.frame.height)
            config.scalesToFit = true
            config.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        } catch {
            return nil
        }
    }

    /// Captures thumbnails for multiple windows in parallel
    static func captureThumbnails(windowIDs: [CGWindowID]) async -> [CGWindowID: NSImage] {
        await withTaskGroup(of: (CGWindowID, NSImage?).self) { group in
            for id in windowIDs {
                group.addTask {
                    (id, await captureThumbnail(windowID: id))
                }
            }

            var results: [CGWindowID: NSImage] = [:]
            for await (id, image) in group {
                if let image {
                    results[id] = image
                }
            }
            return results
        }
    }
}
