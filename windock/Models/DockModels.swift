import Foundation
import SwiftUI
import AppKit

// Represents a single simulated window for an application
struct WindowInfo: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let previewColor: Color // Mocking a snapshot/thumbnail with a color
}

// Represents an App sitting in the Dock
struct DockApp: Identifiable, Hashable {
    // Use bundleIdentifier as ID so the dock position stays stable
    var id: String { bundleIdentifier }
    
    let name: String
    let bundleIdentifier: String
    let icon: NSImage?
    var isRunning: Bool
    var openWindows: [WindowInfo]
    
    // Hashable conformance for NSImage (which isn't hashable by default)
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
        hasher.combine(isRunning)
    }
    
    static func == (lhs: DockApp, rhs: DockApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier && lhs.isRunning == rhs.isRunning
    }
}
