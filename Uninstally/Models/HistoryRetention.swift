import Foundation

/// How long uninstall history is kept before automatic pruning.
enum HistoryRetention: String, CaseIterable, Identifiable, Sendable {
    case days30
    case days90
    case year
    case forever

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days30: return "30 Days"
        case .days90: return "90 Days"
        case .year: return "1 Year"
        case .forever: return "Forever"
        }
    }

    /// Number of days to retain, or `nil` for "keep forever".
    var days: Int? {
        switch self {
        case .days30: return 30
        case .days90: return 90
        case .year: return 365
        case .forever: return nil
        }
    }

    /// The cutoff date before which records should be pruned, or `nil` for forever.
    var cutoffDate: Date? {
        guard let days else { return nil }
        return Calendar.current.date(byAdding: .day, value: -days, to: .now)
    }

    static var stored: HistoryRetention {
        HistoryRetention(rawValue: UserDefaults.standard.string(forKey: AppSettings.historyRetentionKey) ?? "")
            ?? .forever
    }
}

/// Time/method filters offered on the Recently Uninstalled page.
enum HistoryFilter: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case week = "Last 7 Days"
    case month = "Last 30 Days"
    case all = "All Time"
    case trash = "Trash"
    case permanent = "Permanent Delete"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .week: return "calendar"
        case .month: return "calendar"
        case .all: return "infinity"
        case .trash: return "trash"
        case .permanent: return "trash.slash"
        }
    }

    /// Whether a record matches this filter.
    func matches(_ record: UninstallRecord) -> Bool {
        switch self {
        case .all: return true
        case .today:
            return Calendar.current.isDateInToday(record.dateUninstalled)
        case .week:
            return record.dateUninstalled >= Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        case .month:
            return record.dateUninstalled >= Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        case .trash:
            return record.deletionMethod == .trash
        case .permanent:
            return record.deletionMethod == .permanent
        }
    }
}
