import SwiftUI

struct GlassView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(view)
        
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView.subviews.first as? NSVisualEffectView else { return }
        if view.material != material {
            view.material = material
        }
        if view.blendingMode != blendingMode {
            view.blendingMode = blendingMode
        }
    }
}
