import Foundation
import Observation

/// A small, curated palette of SF Symbols users can assign to a Collection.
enum CollectionSymbol {
    static let all: [String] = [
        "folder.fill", "star.fill", "tag.fill", "gamecontroller.fill",
        "hammer.fill", "paintbrush.fill", "briefcase.fill", "music.note",
        "camera.fill", "terminal.fill", "cart.fill", "heart.fill",
        "graduationcap.fill", "airplane", "bolt.fill", "flame.fill",
    ]
    static let `default` = "folder.fill"
}

/// A user-created Collection: a named, icon-tagged group of applications the user
/// has manually placed together to categorise them. Membership is stored by each
/// app's stable `collectionKey` (bundle identifier, or path as a fallback).
///
/// Collections are purely organisational — they never change what's installed;
/// removing an app from a Collection only unfiles it.
struct CustomTab: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var symbol: String
    /// Member app keys, in insertion order.
    var appKeys: [String]

    init(id: UUID = UUID(), name: String, symbol: String = CollectionSymbol.default, appKeys: [String] = []) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.appKeys = appKeys
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Collection" : trimmed
    }

    func contains(_ key: String) -> Bool { appKeys.contains(key) }
}

/// Owns and persists user Collections for the main application sidebar. Backed by
/// `UserDefaults`, so Collections and their membership return automatically on the
/// next launch.
@MainActor
@Observable
final class CustomTabManager {
    /// All collections in the user's chosen order. Mutation persists automatically.
    var tabs: [CustomTab] {
        didSet { save() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.tabs = Self.load(from: defaults)
    }

    // MARK: - Lookup

    func tab(id: UUID) -> CustomTab? {
        tabs.first { $0.id == id }
    }

    /// Collections that currently contain the given app key.
    func collections(containing key: String) -> Set<UUID> {
        Set(tabs.filter { $0.contains(key) }.map(\.id))
    }

    // MARK: - Mutations

    @discardableResult
    func createTab(name: String = "New Collection", symbol: String = CollectionSymbol.default,
                   initialKey: String? = nil) -> CustomTab {
        var tab = CustomTab(name: name, symbol: symbol)
        if let initialKey { tab.appKeys = [initialKey] }
        tabs.append(tab)
        return tab
    }

    func rename(_ id: UUID, to newName: String) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[i].name = newName
    }

    func setSymbol(_ id: UUID, _ symbol: String) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[i].symbol = symbol
    }

    func delete(_ id: UUID) {
        tabs.removeAll { $0.id == id }
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        tabs.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func add(_ key: String, to id: UUID) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        guard !tabs[i].appKeys.contains(key) else { return }
        tabs[i].appKeys.append(key)
    }

    func add(_ keys: [String], to id: UUID) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        for key in keys where !tabs[i].appKeys.contains(key) {
            tabs[i].appKeys.append(key)
        }
    }

    func remove(_ key: String, from id: UUID) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[i].appKeys.removeAll { $0 == key }
    }

    /// Drops membership entries whose apps are no longer installed, keeping the
    /// Collections tidy after uninstalls.
    func prune(installedKeys: Set<String>) {
        var changed = false
        for i in tabs.indices {
            let filtered = tabs[i].appKeys.filter { installedKeys.contains($0) }
            if filtered.count != tabs[i].appKeys.count {
                tabs[i].appKeys = filtered
                changed = true
            }
        }
        // Assigning triggers save via didSet only if the array identity changes;
        // force a save when we mutated in place.
        if changed { save() }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(tabs) {
            defaults.set(data, forKey: AppSettings.customTabsKey)
        }
    }

    private static func load(from defaults: UserDefaults) -> [CustomTab] {
        guard let data = defaults.data(forKey: AppSettings.customTabsKey),
              let saved = try? JSONDecoder().decode([CustomTab].self, from: data)
        else {
            return []
        }
        return saved
    }
}
