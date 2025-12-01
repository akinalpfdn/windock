import SwiftUI

struct DockIconView: View {
    let app: DockApp
    let isHovered: Bool
    let namespace: Namespace.ID
    
    // Constants
    private let baseSize: CGFloat = 50
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Icon Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1)) // Subtle background for real icons
                    .shadow(radius: 2)
                
                // Real App Icon
                if let nsIcon = app.icon {
                    Image(nsImage: nsIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(2) // Slight padding so it doesn't touch edges
                } else {
                    // Fallback
                    Image(systemName: "questionmark.app")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                }
            }
            .frame(width: currentSize, height: currentSize)
            // Matched Geometry for smooth animations
            .matchedGeometryEffect(id: app.id, in: namespace)
            
            // Running Indicator Dot (Always on for running apps)
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 4, height: 4)
                .opacity(app.isRunning ? 1 : 0)
        }
        // Coordinate space for popup positioning
        .anchorPreference(key: BoundsPreferenceKey.self, value: .bounds) { anchor in
            [app.id: anchor] // Ensure ID type matches DockApp.id (String)
        }
    }
    
    private var currentSize: CGFloat {
        isHovered ? baseSize * 1.5 : baseSize
    }
}

// Update Preference Key to use String key
struct BoundsPreferenceKey: PreferenceKey {
    typealias Value = [String: Anchor<CGRect>]
    static var defaultValue: Value = [:]
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}
