import SwiftUI

/// SwiftUI content displayed inside the PreviewPanel
struct PreviewPanelContent: View {
    let dockPosition: DockPosition
    let app: DockApp
    let windows: [WindowInfo]
    let onWindowClick: (WindowInfo) -> Void
    let onWindowClose: (WindowInfo) -> Void
    let onWindowHover: (WindowInfo?) -> Void
    let onHoverChanged: (Bool) -> Void

    private var isVertical: Bool { dockPosition != .bottom }

    var body: some View {
        let content = ForEach(windows) { window in
            WindowPreviewCard(window: window, onTap: {
                onWindowClick(window)
            }, onClose: {
                onWindowClose(window)
            }, onHover: { isHovered in
                onWindowHover(isHovered ? window : nil)
            })
        }

        Group {
            if isVertical {
                VStack(spacing: Layout.Preview.cardSpacing) { content }
            } else {
                HStack(spacing: Layout.Preview.cardSpacing) { content }
            }
        }
        .padding(Layout.Preview.containerPadding)
        .background(
            GlassView(material: .hudWindow, blendingMode: .withinWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: Layout.Preview.containerCornerRadius))
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.Preview.containerCornerRadius)
                .stroke(.white.opacity(Animation.borderOpacity), lineWidth: 1)
        )
        .onHover(perform: onHoverChanged)
    }
}

// MARK: - Window Preview Card

private struct WindowPreviewCard: View {
    let window: WindowInfo
    let onTap: () -> Void
    let onClose: () -> Void
    let onHover: (Bool) -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let thumbnail = window.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: Layout.Preview.thumbnailCornerRadius)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "macwindow")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: Layout.Preview.thumbnailWidth, height: Layout.Preview.thumbnailHeight)
            .clipShape(RoundedRectangle(cornerRadius: Layout.Preview.thumbnailCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.Preview.thumbnailCornerRadius)
                    .stroke(.white.opacity(Animation.borderOpacity), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if isHovered {
                    CloseButton(action: onClose)
                        .padding(4)
                        .transition(.opacity)
                }
            }
            .shadow(radius: 4)

            Text(window.title)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: Layout.Preview.thumbnailWidth)
        }
        .padding(Layout.Preview.cardPadding)
        .background(isHovered ? Color.white.opacity(0.1) : .clear)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Layout.Preview.cardCornerRadius))
        .scaleEffect(isHovered ? Animation.hoverScale : 1.0)
        .animation(.easeInOut(duration: Animation.hoverDuration * 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            onHover(hovering)
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Close Button

private struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(Color.red.opacity(0.8))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
