import Foundation

/// Centralized layout and animation constants
enum Layout {

    enum Preview {
        static let thumbnailWidth: CGFloat = 160
        static let thumbnailHeight: CGFloat = 100
        static let cardCornerRadius: CGFloat = 12
        static let thumbnailCornerRadius: CGFloat = 8
        static let containerCornerRadius: CGFloat = 16
        static let cardSpacing: CGFloat = 12
        static let cardPadding: CGFloat = 8
        static let containerPadding: CGFloat = 12
        static let bufferFromDock: CGFloat = 4
    }
}

enum Animation {
    static let hoverDuration: Double = 0.2
    static let previewShowDuration: Double = 0.3
    static let hoverScale: CGFloat = 1.05
    static let borderOpacity: Double = 0.2
}
