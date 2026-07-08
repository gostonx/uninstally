import Foundation

/// Sort strategies offered in the standalone application browser.
enum AppSortOption: String, CaseIterable, Identifiable, Sendable {
    case name = "Name"
    case size = "Size"
    case developer = "Developer"
    case installDate = "Install Date"
    case recentlyUsed = "Recently Used"
    case unused = "Unused"
    case largest = "Largest Apps"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .name: return "textformat"
        case .size: return "arrow.up.arrow.down"
        case .developer: return "person.fill"
        case .installDate: return "calendar"
        case .recentlyUsed: return "clock.fill"
        case .unused: return "moon.zzz.fill"
        case .largest: return "chart.bar.fill"
        }
    }

    /// Returns a comparator closure implementing the sort.
    func sorted(_ apps: [AppInfo]) -> [AppInfo] {
        switch self {
        case .name:
            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size, .largest:
            return apps.sorted { $0.sizeBytes > $1.sizeBytes }
        case .developer:
            return apps.sorted {
                let lhs = $0.developer.isEmpty ? "zzz" : $0.developer
                let rhs = $1.developer.isEmpty ? "zzz" : $1.developer
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
        case .installDate:
            return apps.sorted { ($0.installDate ?? .distantPast) > ($1.installDate ?? .distantPast) }
        case .recentlyUsed:
            return apps.sorted { ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast) }
        case .unused:
            return apps.sorted { ($0.lastUsedDate ?? .distantPast) < ($1.lastUsedDate ?? .distantPast) }
        }
    }
}

/// Presentation modes for the browser.
enum BrowserLayout: String, CaseIterable, Identifiable, Sendable {
    case grid, list
    var id: String { rawValue }
    var systemImage: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
}

/// Curated collections surfaced as smart filters in the browser sidebar.
enum SmartFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "All Applications"
    case largest = "Largest"
    case recentlyInstalled = "Recently Installed"
    case recentlyOpened = "Recently Opened"
    case neverOpened = "Never Opened"
    case withLeftovers = "With Leftover Files"
    case brokenInstalls = "Broken Installs"
    case duplicated = "Duplicated Across Drives"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .largest: return "chart.bar.fill"
        case .recentlyInstalled: return "sparkles"
        case .recentlyOpened: return "clock.fill"
        case .neverOpened: return "moon.zzz.fill"
        case .withLeftovers: return "trash.slash.fill"
        case .brokenInstalls: return "bandage.fill"
        case .duplicated: return "doc.on.doc.fill"
        }
    }
}
