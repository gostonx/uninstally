import SwiftUI

/// A rounded, translucent container that adopts the system's material and a
/// hairline border — the workhorse surface used across Uninstally, echoing the
/// panels in System Settings.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
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

/// A subtle vibrancy background layer used behind primary content areas.
struct VibrantBackground: View {
    var body: some View {
        Rectangle()
            .fill(.background)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.08), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
            }
            .ignoresSafeArea()
    }
}
