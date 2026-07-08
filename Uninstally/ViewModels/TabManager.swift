import Foundation
import Observation

/// The set of built-in Settings sections. Each maps to a content view; users can
/// reorder, rename and enable/disable them, but the underlying set is fixed so
/// every configuration always resolves to real content.
enum SettingsSection: String, Codable, CaseIterable, Identifiable, Sendable {
    case general
    case updates
    case appearance
    case advanced
    case about

    var id: String { rawValue }

    var defaultTitle: String {
        switch self {
        case .general: return "General"
        case .updates: return "Updates"
        case .appearance: return "Appearance"
        case .advanced: return "Advanced"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .updates: return "arrow.triangle.2.circlepath"
        case .appearance: return "paintbrush"
        case .advanced: return "slider.horizontal.3"
        case .about: return "info.circle"
        }
    }

    /// Whether the user is allowed to hide this tab. General is always available so
    /// the Settings window can never end up empty.
    var canDisable: Bool { self != .general }
}

/// A persisted, user-customisable tab: which section it is, an optional custom
/// name, and whether it's shown.
struct SettingsTabConfig: Codable, Identifiable, Hashable, Sendable {
    let section: SettingsSection
    var customTitle: String
    var isEnabled: Bool

    var id: String { section.id }

    /// The name to display (custom name if set, otherwise the default).
    var title: String {
        let trimmed = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? section.defaultTitle : trimmed
    }

    init(section: SettingsSection, customTitle: String = "", isEnabled: Bool = true) {
        self.section = section
        self.customTitle = customTitle
        self.isEnabled = isEnabled
    }
}

/// Stores and persists the Settings tab configuration (order, names, enabled
/// state) and notifies SwiftUI of changes. Backed by `UserDefaults`.
@MainActor
@Observable
final class TabManager {
    /// The tabs in their user-defined order. Mutating this persists automatically.
    var tabs: [SettingsTabConfig] {
        didSet { save() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.tabs = Self.load(from: defaults)
    }

    /// The enabled tabs, in order — what the Settings sidebar renders.
    var enabledTabs: [SettingsTabConfig] {
        tabs.filter(\.isEnabled)
    }

    // MARK: - Mutations

    func move(fromOffsets: IndexSet, toOffset: Int) {
        tabs.move(fromOffsets: fromOffsets, toOffset: toOffset)
        HapticManager.shared.reorderMoved()
    }

    /// Enables/disables a tab, refusing to disable the last remaining enabled tab.
    func setEnabled(_ id: SettingsTabConfig.ID, _ enabled: Bool) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        if !enabled {
            guard tabs[index].section.canDisable else { return }
            if enabledTabs.count <= 1 { return }
        }
        tabs[index].isEnabled = enabled
    }

    func rename(_ id: SettingsTabConfig.ID, to newName: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].customTitle = newName
    }

    /// Restores the default order, names and enabled state.
    func reset() {
        tabs = Self.defaultConfiguration()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(tabs) {
            defaults.set(data, forKey: AppSettings.settingsTabsKey)
        }
    }

    private static func defaultConfiguration() -> [SettingsTabConfig] {
        SettingsSection.allCases.map { SettingsTabConfig(section: $0) }
    }

    /// Loads the saved configuration, reconciling it with the current set of known
    /// sections so newly added sections appear and removed ones are dropped.
    private static func load(from defaults: UserDefaults) -> [SettingsTabConfig] {
        guard let data = defaults.data(forKey: AppSettings.settingsTabsKey),
              let saved = try? JSONDecoder().decode([SettingsTabConfig].self, from: data)
        else {
            return defaultConfiguration()
        }

        var reconciled = saved.filter { SettingsSection(rawValue: $0.section.rawValue) != nil }
        let known = Set(reconciled.map(\.section))
        for section in SettingsSection.allCases where !known.contains(section) {
            reconciled.append(SettingsTabConfig(section: section))
        }
        return reconciled.isEmpty ? defaultConfiguration() : reconciled
    }
}
