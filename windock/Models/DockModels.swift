import Foundation
import SwiftUI
import AppKit

/// Represents a single window belonging to an application
struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let title: String
    let thumbnail: NSImage?
    let bounds: CGRect

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents a running application in the dock
struct DockApp: Identifiable, Hashable {
    var id: String { bundleIdentifier }

    let name: String
    let bundleIdentifier: String
    let icon: NSImage?
    var isRunning: Bool
    var openWindows: [WindowInfo]

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: DockApp, rhs: DockApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}
