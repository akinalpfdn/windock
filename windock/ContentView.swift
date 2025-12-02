import SwiftUI

struct ContentView: View {
    @Environment(DockViewModel.self) private var viewModel
    @Namespace private var animationNamespace
    
    var body: some View {
        ZStack {
            // 2. The Window Preview Overlay (always present, hidden when not needed)
            WindowPreviewList(app: viewModel.selectedAppForPreview, namespace: animationNamespace)
                .opacity(viewModel.selectedAppForPreview != nil ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedAppForPreview != nil)
                .frame(width: 800, height: 300)
                .position(x: 400, y: 50) // Much higher position, above the dock

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
                        viewModel.handleHoverChanged(appId: app.id, isHovering: isHovering)
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
            .frame(width: 800, height: 100) // Fixed dock size
        }

        .fixedSize(horizontal: true, vertical: false)
        .ignoresSafeArea()
    }
}
