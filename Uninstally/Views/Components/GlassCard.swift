import SwiftUI

/// A rounded, translucent container that adopts the system's material and a
/// hairline border — used for grouped content, echoing the panels in System
/// Settings.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 12
    var material: Material = .regularMaterial
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
    }
}

