import SwiftUI

/// The app's primary call-to-action button style: a filled, rounded capsule with
/// a spring press animation. Supports a destructive tint.
struct ProminentButtonStyle: ButtonStyle {
    var tint: Color = .accentColor
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(
                (isDestructive ? Color.red : tint)
                    .opacity(configuration.isPressed ? 0.8 : 1),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A quiet, bordered secondary button.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(configuration.isPressed ? 0.6 : 0.3),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ProminentButtonStyle {
    static var prominentAction: ProminentButtonStyle { ProminentButtonStyle() }
    static var destructiveAction: ProminentButtonStyle { ProminentButtonStyle(isDestructive: true) }
}

extension ButtonStyle where Self == QuietButtonStyle {
    static var quiet: QuietButtonStyle { QuietButtonStyle() }
}
