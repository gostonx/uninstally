import Foundation
import Observation

/// A persisted entry in the main Applications sidebar: which smart filter it
/// points to, whether it's shown, and whether it's pinned to the top. Order is
/// implied by array position.
///
/// Hiding an item only removes it from the sidebar navigation — the underlying
/// data (and the filter itself) remain fully available.
struct AppSidebarItemConfig: Codable, Identifiable, Hashable, Sendable {
    let filter: SmartFilter
    var isVisible: Bool
    var isPinned: Bool

    var id: String { filter.id }

    init(filter: SmartFilter, isVisible: Bool = true, isPinned: Bool = false) {
        self.filter = filter
        self.isVisible = isVisible
        self.isPinned = isPinned
    }
}

/// Owns and persists the **main Applications sidebar**: section order, visibility,
/// pinned favourites and the collapsed/expanded state. Restores defaults on
/// request. Backed by `UserDefaults`, so the layout returns automatically on the
/// next launch.
///
/// This governs the standalone application window's sidebar only; the Settings
/// window uses a fixed navigation order.
@MainActor
@Observable
final class AppSidebarManager {
    /// All sidebar items in the user's chosen order. Mutation persists.
    var items: [AppSidebarItemConfig] {
        didSet { saveItems() }
    }

    /// Whether the sidebar column is collapsed.
    var isCollapsed: Bool {
        didSet { defaults.set(isCollapsed, forKey: AppSettings.appSidebarCollapsedKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = Self.load(from: defaults)
        self.isCollapsed = defaults.bool(forKey: AppSettings.appSidebarCollapsedKey)
    }

    // MARK: - Derived collections

    var visibleItems: [AppSidebarItemConfig] { items.filter(\.isVisible) }

    /// Visible, pinned items in order — rendered in a "Favorites" section.
    var pinnedVisibleItems: [AppSidebarItemConfig] {
        visibleItems.filter(\.isPinned)
    }

    /// Visible, unpinned items in order — rendered in the "Applications" section.
    var unpinnedVisibleItems: [AppSidebarItemConfig] {
        visibleItems.filter { !$0.isPinned }
    }

    var hasPinned: Bool { !pinnedVisibleItems.isEmpty }

    // MARK: - Mutations

    func move(fromOffsets: IndexSet, toOffset: Int) {
        items.move(fromOffsets: fromOffsets, toOffset: toOffset)
        HapticManager.shared.reorderMoved()
    }

    /// Shows/hides an item, refusing to hide the last visible one.
    func setVisible(_ id: AppSidebarItemConfig.ID, _ visible: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if !visible, visibleItems.count <= 1 { return }
        items[index].isVisible = visible
    }

    func togglePin(_ id: AppSidebarItemConfig.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        HapticManager.shared.itemSelected()
    }

    func isPinned(_ filter: SmartFilter) -> Bool {
        items.first(where: { $0.filter == filter })?.isPinned ?? false
    }

    func toggleCollapsed() {
        isCollapsed.toggle()
    }

    /// Restores the default order, visibility and pinning.
    func reset() {
        items = Self.defaultConfiguration()
    }

    // MARK: - Persistence

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: AppSettings.appSidebarKey)
        }
    }

    private static func defaultConfiguration() -> [AppSidebarItemConfig] {
        SmartFilter.allCases.map { AppSidebarItemConfig(filter: $0) }
    }

    /// Loads the saved configuration, reconciling it with the current set of known
    /// filters so newly added filters appear and removed ones drop out.
    private static func load(from defaults: UserDefaults) -> [AppSidebarItemConfig] {
        guard let data = defaults.data(forKey: AppSettings.appSidebarKey),
              let saved = try? JSONDecoder().decode([AppSidebarItemConfig].self, from: data)
        else {
            return defaultConfiguration()
        }
        var reconciled = saved
        let known = Set(reconciled.map(\.filter))
        for filter in SmartFilter.allCases where !known.contains(filter) {
            reconciled.append(AppSidebarItemConfig(filter: filter))
        }
        return reconciled.isEmpty ? defaultConfiguration() : reconciled
    }
}
