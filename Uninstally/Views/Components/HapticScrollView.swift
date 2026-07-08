import SwiftUI

/// Metrics reported by the scroll content for edge detection.
private struct ScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentHeight: CGFloat = 0
}

private struct ScrollMetricsKey: PreferenceKey {
    static let defaultValue = ScrollMetrics()
    static func reduce(value: inout ScrollMetrics, nextValue: () -> ScrollMetrics) {
        value = nextValue()
    }
}

/// A drop-in replacement for `ScrollView` that fires a subtle alignment haptic the
/// moment the content reaches its top or bottom edge — mirroring the restrained
/// feel of System Settings. Edge feedback fires once per arrival (never
/// continuously) and only when the content is actually scrollable.
struct HapticScrollView<Content: View>: View {
    var showsIndicators: Bool = true
    @ViewBuilder var content: Content

    private let space = "hapticScroll"
    @State private var atTop = true
    @State private var atBottom = false

    var body: some View {
        GeometryReader { outer in
            ScrollView(showsIndicators: showsIndicators) {
                content
                    .background(
                        GeometryReader { inner in
                            Color.clear.preference(
                                key: ScrollMetricsKey.self,
                                value: ScrollMetrics(
                                    offset: inner.frame(in: .named(space)).minY,
                                    contentHeight: inner.size.height
                                )
                            )
                        }
                    )
            }
            .coordinateSpace(.named(space))
            .onPreferenceChange(ScrollMetricsKey.self) { metrics in
                evaluate(metrics, viewportHeight: outer.size.height)
            }
        }
    }

    private func evaluate(_ metrics: ScrollMetrics, viewportHeight: CGFloat) {
        let scrollable = metrics.contentHeight - viewportHeight
        guard scrollable > 4 else {
            atTop = true
            atBottom = false
            return
        }
        let reachedTop = metrics.offset >= -2
        let reachedBottom = metrics.offset <= -(scrollable - 2)

        if reachedTop, !atTop { HapticManager.shared.edgeReached() }
        if reachedBottom, !atBottom { HapticManager.shared.edgeReached() }

        atTop = reachedTop
        atBottom = reachedBottom
    }
}
