import SwiftUI

struct WindowPreviewList: View {
    let app: DockApp?
    let namespace: Namespace.ID
    @Environment(DockViewModel.self) private var viewModel

    var body: some View {
        Group {
            if let app = app {
                HStack(spacing: 12) {
                    ForEach(app.openWindows) { window in
                        VStack(spacing: 8) {
                            // Mock Window Thumbnail
                            RoundedRectangle(cornerRadius: 8)
                                .fill(window.previewColor.gradient)
                                .frame(width: 120, height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(radius: 4)

                            // Window Title
                            Text(window.title)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .frame(maxWidth: 100)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial) // Frost effect behind individual item
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        // Hover effect for the preview card
                        .onHover { isHovering in
                            if isHovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .onTapGesture {
                            viewModel.handleWindowClick(window, in: app)
                        }
                    }
                }
                .padding(12)
                .background(
                    GlassView(material: .hudWindow, blendingMode: .withinWindow)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}