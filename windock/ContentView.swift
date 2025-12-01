import SwiftUI

struct ContentView: View {
    @Environment(DockViewModel.self) private var viewModel
    @Namespace private var animationNamespace
    
    // Updated to use String keys matching DockApp.id
    @State private var iconAnchors: [String: Anchor<CGRect>] = [:]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // 1. The Dock Bar
            HStack(spacing: 12) {
                ForEach(viewModel.apps) { app in
                    DockIconView(
                        app: app,
                        isHovered: viewModel.hoveredAppId == app.id,
                        namespace: animationNamespace
                    )
                    .onTapGesture {
                        viewModel.handleAppClick(app)
                    }
                    .onHover { isHovering in
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                            viewModel.hoveredAppId = isHovering ? app.id : nil
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                GlassView(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.bottom, 10)
            .onPreferenceChange(BoundsPreferenceKey.self) { preferences in
                self.iconAnchors = preferences
            }
            
            // 2. The Window Preview Overlay
            if let selectedApp = viewModel.selectedAppForPreview,
               let anchor = iconAnchors[selectedApp.id] {
                
                GeometryReader { geometry in
                    let iconFrame = geometry[anchor]
                    
                    WindowPreviewList(app: selectedApp, namespace: animationNamespace)
                        .position(
                            x: iconFrame.midX,
                            y: iconFrame.minY - 70
                        )
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        viewModel.selectedAppForPreview = nil
                    }
                }
            }
        }

        .fixedSize(horizontal: true, vertical: false)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        )
        .ignoresSafeArea()
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
