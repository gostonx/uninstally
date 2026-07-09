import Foundation

/// How Uninstally disposes of an application and its associated files.
///
/// `trash` is the safe default: user-domain files are moved to the Trash via the
/// native `FileManager.trashItem` API and can be recovered until the Trash is
/// emptied. `permanent` removes them outright. (System/administrator-owned files
/// always require an elevated removal and are deleted permanently in both modes,
/// since root-owned items cannot be placed in the user's Trash.)
enum DeletionMode: String, CaseIterable, Identifiable, Sendable {
    case trash
    case permanent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trash: return "Move to Trash"
        case .permanent: return "Permanently Delete"
        }
    }

    var subtitle: String {
        switch self {
        case .trash: return "Safer option. Files can be recovered from the Trash."
        case .permanent: return "Removes files immediately and cannot be undone."
        }
    }

    var systemImage: String {
        switch self {
        case .trash: return "trash"
        case .permanent: return "trash.slash"
        }
    }

    /// The confirmation action's verb.
    var confirmTitle: String {
        switch self {
        case .trash: return "Move to Trash"
        case .permanent: return "Delete Permanently"
        }
    }

    /// The persisted preference, defaulting to `.trash`.
    static var stored: DeletionMode {
        DeletionMode(rawValue: UserDefaults.standard.string(forKey: AppSettings.deletionModeKey) ?? "")
            ?? .trash
    }
}
