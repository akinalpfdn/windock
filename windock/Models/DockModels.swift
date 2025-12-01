import Foundation
import SwiftUI

// Represents a single simulated window for an application
struct WindowInfo: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let previewColor: Color // Mocking a snapshot/thumbnail with a color
}

// Represents an App sitting in the Dock
struct DockApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let iconName: String // SF Symbol name for simplicity
    var isRunning: Bool
    var openWindows: [WindowInfo]
}
