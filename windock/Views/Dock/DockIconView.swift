import SwiftUI

struct DockIconView: View {
    let app: DockApp
    let isHovered: Bool
    let namespace: Namespace.ID
    
    // Constants
    private let baseSize: CGFloat = 50
    private let maxMagnification: CGFloat = 1.5
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Icon Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.9))
                    .shadow(radius: 2)
                
                // Icon Image
                Image(systemName: app.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(8)
            }
            .frame(width: currentSize, height: currentSize)
            // Matched Geometry for smooth animations if we were dragging
            .matchedGeometryEffect(id: app.id, in: namespace)
            
            // Running Indicator Dot
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 4, height: 4)
                .opacity(app.isRunning ? 1 : 0)
        }
        // Coordinate space for popup positioning
        .anchorPreference(key: BoundsPreferenceKey.self, value: .bounds) { anchor in
            [app.id: anchor]
        }
    }
    
    // Simple magnification logic (mocking the complex sine wave dock effect)
    private var currentSize: CGFloat {
        isHovered ? baseSize * 1.2 : baseSize
    }
}

// Preference Key to track screen positions of icons for the popup
struct BoundsPreferenceKey: PreferenceKey {
    typealias Value = [UUID: Anchor<CGRect>]
    static var defaultValue: Value = [:]
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}
