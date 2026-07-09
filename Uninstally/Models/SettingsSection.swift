import Foundation

/// The catalogue of Settings sections shown on the single Settings page.
///
/// Every case is rendered as a section on the page, in declaration order. The
/// sidebar is a fixed table of contents used purely to scroll to a section. This
/// type owns the display metadata (title, icon, subtitle) so the UI never
/// hard-codes strings.
enum SettingsSection: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case general
    case updates
    case appearance
    case uninstall
    case scanning
    case security
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .updates: return "Updates"
        case .appearance: return "Appearance"
        case .uninstall: return "Uninstall Settings"
        case .scanning: return "Scanning"
        case .security: return "Security"
        case .advanced: return "Advanced"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .updates: return "arrow.triangle.2.circlepath"
        case .appearance: return "paintbrush"
        case .uninstall: return "trash"
        case .scanning: return "magnifyingglass"
        case .security: return "lock.shield"
        case .advanced: return "slider.horizontal.3"
        case .about: return "info.circle"
        }
    }

    /// A short, System-Settings-style subtitle shown under each section header.
    var subtitle: String {
        switch self {
        case .general: return "Feedback and everyday behaviour."
        case .updates: return "Keep Uninstally up to date."
        case .appearance: return "How Uninstally looks and where it lives."
        case .uninstall: return "What happens when you remove an app."
        case .scanning: return "How thoroughly Uninstally searches for related files."
        case .security: return "Confirmations and safe-removal safeguards."
        case .advanced: return "Power-user options and resets."
        case .about: return "Version and links."
        }
    }

    /// Tint used for the section's icon badge.
    var accentsRed: Bool { self == .security || self == .uninstall }

    /// Whether the user may hide this section from the navigation sidebar.
    /// General stays available so the sidebar is never empty.
    var canDisable: Bool { self != .general }
}
