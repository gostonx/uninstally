import AppKit

/// Centralises subtle, native trackpad haptics.
///
/// macOS haptics are delivered through `NSHapticFeedbackManager`, which drives the
/// Force Touch trackpad's Taptic Engine. Critically, the system itself only
/// produces feedback on capable hardware (Force Touch trackpads) and is a silent
/// no-op on a mouse, older trackpad or external display — so we get correct device
/// detection for free without probing IOKit.
///
/// Feedback is intentionally reserved for *meaningful* moments (selection, section
/// changes, reaching a list edge, reordering) rather than continuous scrolling, to
/// match the restrained feel of System Settings.
@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let performer = NSHapticFeedbackManager.defaultPerformer

    private init() {}

    /// Whether the user has haptics enabled (defaults to `true`).
    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppSettings.hapticsEnabledKey) as? Bool ?? true
    }

    // MARK: - Semantic feedback

    /// A light tick when the user selects or opens an item.
    func itemSelected() {
        perform(.levelChange)
    }

    /// A soft detent when moving between sidebar sections / tabs.
    func sectionChanged() {
        perform(.generic)
    }

    /// An alignment-style bump when a scroll view reaches its top or bottom edge.
    func edgeReached() {
        perform(.alignment)
    }

    /// A tick as a draggable item snaps into a new position.
    func reorderMoved() {
        perform(.levelChange)
    }

    // MARK: - Core

    private func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard isEnabled else { return }
        performer.perform(pattern, performanceTime: .now)
    }
}
