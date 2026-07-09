import SwiftUI
import AppKit

/// A thin wrapper over `NSVisualEffectView` — Apple's own material/vibrancy view
/// (the same primitive that backs SwiftUI's `Material`). Used to give windows a
/// genuine behind-window translucency rather than a custom blur.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var emphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = emphasized
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = emphasized
    }
}

/// Makes the hosting `NSWindow` non-opaque so behind-window materials show the
/// desktop and windows beneath — the standard way to get a translucent macOS
/// window. Also keeps the title bar transparent for the unified look.
private struct TranslucentWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    /// Applies a translucent, behind-window material as the window's background.
    func translucentWindowBackground(_ material: NSVisualEffectView.Material = .underWindowBackground) -> some View {
        background(VisualEffectView(material: material).ignoresSafeArea())
            .background(TranslucentWindowConfigurator())
    }
}
