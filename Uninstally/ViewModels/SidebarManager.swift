import Foundation
import Observation

/// A persisted sidebar entry: which section it points to and whether it appears in
/// the navigation list. It never affects whether the section exists on the page —
/// only its navigation visibility and position.
struct SidebarItemConfig: Codable, Identifiable, Hashable, Sendable {
    let section: SettingsSection
    var isEnabled: Bool

    var id: String { section.id }

    init(section: SettingsSection, isEnabled: Bool = true) {
        self.section = section
        self.isEnabled = isEnabled
    }
}

/// Owns and persists the Settings navigation sidebar: the order of sections and
/// which ones are visible. Restores defaults on request. Backed by `UserDefaults`.
///
/// Disabling an item only hides it from the sidebar; the corresponding section is
/// still rendered on the single Settings page.
@MainActor
@Observable
final class SidebarManager {
    /// All sidebar items in the user's chosen order. Mutation persists automatically.
    var items: [SidebarItemConfig] {
        didSet { save() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = Self.load(from: defaults)
    }

    /// Visible sidebar items, in order — what the navigation list renders.
    var enabledItems: [SidebarItemConfig] {
        items.filter(\.isEnabled)
    }

    /// The section order used to lay out the single Settings page (all sections,
    /// enabled or not, in the user's order).
    var pageOrder: [SettingsSection] {
        items.map(\.section)
    }

    // MARK: - Mutations

    func move(fromOffsets: IndexSet, toOffset: Int) {
        items.move(fromOffsets: fromOffsets, toOffset: toOffset)
        HapticManager.shared.reorderMoved()
    }

    /// Enables/disables an item, refusing to hide the last visible one or a section
    /// that must always be available.
    func setEnabled(_ id: SidebarItemConfig.ID, _ enabled: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if !enabled {
            guard items[index].section.canDisable else { return }
            if enabledItems.count <= 1 { return }
        }
        items[index].isEnabled = enabled
    }

    /// Restores the default order and visibility.
    func reset() {
        items = Self.defaultConfiguration()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: AppSettings.settingsSidebarKey)
        }
    }

    private static func defaultConfiguration() -> [SidebarItemConfig] {
        SettingsSection.allCases.map { SidebarItemConfig(section: $0) }
    }

    /// Loads the saved configuration, reconciling it with the current known
    /// sections so newly added sections appear and removed ones drop out.
    private static func load(from defaults: UserDefaults) -> [SidebarItemConfig] {
        guard let data = defaults.data(forKey: AppSettings.settingsSidebarKey),
              let saved = try? JSONDecoder().decode([SidebarItemConfig].self, from: data)
        else {
            return defaultConfiguration()
        }
        var reconciled = saved
        let known = Set(reconciled.map(\.section))
        for section in SettingsSection.allCases where !known.contains(section) {
            reconciled.append(SidebarItemConfig(section: section))
        }
        return reconciled.isEmpty ? defaultConfiguration() : reconciled
    }
}
