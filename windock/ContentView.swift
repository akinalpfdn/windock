import SwiftUI

struct ContentView: View {
    @Environment(DockViewModel.self) private var viewModel
    @Namespace private var animationNamespace
    
    // We store the icon positions here
    @State private var iconAnchors: [UUID: Anchor<CGRect>] = [:]
    
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
            .padding(.bottom, 20)
            // Capture the positions of the icons
            .onPreferenceChange(BoundsPreferenceKey.self) { preferences in
                self.iconAnchors = preferences
            }
            
            // 2. The Window Preview Overlay
            // This sits logically above the dock in the ZStack
            if let selectedApp = viewModel.selectedAppForPreview,
               let anchor = iconAnchors[selectedApp.id] {
                
                GeometryReader { geometry in
                    let iconFrame = geometry[anchor]
                    
                    WindowPreviewList(app: selectedApp, namespace: animationNamespace)
                        // Position the preview horizontally centered to the icon
                        // and vertically above the icon
                        .position(
                            x: iconFrame.midX,
                            y: iconFrame.minY - 70 // Offset upwards
                        )
                }
                // Allow clicks to pass through empty areas to close
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        viewModel.selectedAppForPreview = nil
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
