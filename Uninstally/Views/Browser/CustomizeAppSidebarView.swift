import SwiftUI

/// A lightweight sheet for customising the main window sidebar. Two panes:
/// **Sections** (reorder / pin / hide the built-in smart filters) and
/// **Collections** (create, rename, re-icon, reorder and delete user Collections).
/// All edits persist immediately via `AppSidebarManager` / `CustomTabManager`.
struct CustomizeAppSidebarView: View {
    let manager: AppSidebarManager
    let collections: CustomTabManager
    let browser: AppBrowserModel

    private enum Pane: String, CaseIterable, Identifiable {
        case sections = "Sections"
        case collections = "Collections"
        var id: String { rawValue }
    }

    @State private var pane: Pane = .sections
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("", selection: $pane) {
                ForEach(Pane.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            switch pane {
            case .sections: sectionsPane
            case .collections: collectionsPane
            }
        }
        .frame(width: 460, height: 560)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sidebar.squares.left")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Customize Sidebar")
                    .font(.headline)
                Text("Organize the Applications sidebar and your Collections.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Sections pane

    private var sectionsPane: some View {
        @Bindable var manager = manager
        return VStack(spacing: 0) {
            List {
                Section {
                    ForEach($manager.items) { $item in
                        AppSidebarCustomizeRow(
                            item: $item,
                            count: browser.count(for: item.filter),
                            manager: manager
                        )
                        .listRowSeparator(.visible)
                    }
                    .onMove { indices, newOffset in
                        manager.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                Section("Tools") {
                    ToolVisibilityRow(
                        title: "Storage Insights",
                        systemImage: "chart.pie.fill",
                        key: AppSettings.showStorageInsightsKey
                    )
                    ToolVisibilityRow(
                        title: "Recently Uninstalled",
                        systemImage: "clock.arrow.circlepath",
                        key: AppSettings.showRecentlyUninstalledKey
                    )
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
                       value: manager.items)

            footer {
                Text("Hidden sections stay available — they're only removed from the sidebar.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button("Restore Defaults") { manager.reset() }
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Collections pane

    private var collectionsPane: some View {
        @Bindable var collections = collections
        return VStack(spacing: 0) {
            if collections.tabs.isEmpty {
                ContentUnavailableView {
                    Label("No Collections", systemImage: "folder.badge.plus")
                } description: {
                    Text("Create a Collection to group and categorize apps. Add apps by dragging them onto a Collection or right-clicking an app.")
                } actions: {
                    Button("New Collection") { collections.createTab(name: "New Collection") }
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach($collections.tabs) { $tab in
                        CollectionCustomizeRow(
                            tab: $tab,
                            count: browser.count(inCollection: tab),
                            collections: collections
                        )
                        .listRowSeparator(.visible)
                    }
                    .onMove { indices, newOffset in
                        collections.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
                           value: collections.tabs)
            }

            footer {
                Text("Collections only organize apps — they never change what's installed.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button("New Collection", systemImage: "plus") {
                    collections.createTab(name: "New Collection")
                }
                .controlSize(.small)
            }
        }
    }

    private func footer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(content: content)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
    }
}

/// A single reorderable row for a built-in smart-filter section.
private struct AppSidebarCustomizeRow: View {
    @Binding var item: AppSidebarItemConfig
    let count: Int
    let manager: AppSidebarManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
                .help("Drag to reorder")

            Image(systemName: item.filter.systemImage)
                .foregroundStyle(item.filter == .brokenInstalls ? .orange : Color.accentColor)
                .frame(width: 22)

            Text(item.filter.rawValue)
                .lineLimit(1)

            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer(minLength: 8)

            Button {
                manager.togglePin(item.id)
            } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(item.isPinned ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help(item.isPinned ? "Unpin from top" : "Pin to top")
            .accessibilityLabel(item.isPinned ? "Unpin \(item.filter.rawValue)" : "Pin \(item.filter.rawValue)")

            Toggle("", isOn: Binding(
                get: { item.isVisible },
                set: { manager.setVisible(item.id, $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Show or hide in the sidebar")
            .accessibilityLabel("Show \(item.filter.rawValue)")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.filter.rawValue), \(count) items, \(item.isVisible ? "shown" : "hidden")\(item.isPinned ? ", pinned" : "")")
    }
}

/// A single reorderable, editable row for a user Collection.
private struct CollectionCustomizeRow: View {
    @Binding var tab: CustomTab
    let count: Int
    let collections: CustomTabManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
                .help("Drag to reorder")

            Menu {
                ForEach(CollectionSymbol.all, id: \.self) { symbol in
                    Button {
                        collections.setSymbol(tab.id, symbol)
                    } label: {
                        Image(systemName: symbol)
                        Text(symbol.replacingOccurrences(of: ".fill", with: ""))
                    }
                }
            } label: {
                Image(systemName: tab.symbol)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Choose an icon")

            TextField("Collection name", text: $tab.name)
                .textFieldStyle(.plain)

            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer(minLength: 8)

            Button(role: .destructive) {
                collections.delete(tab.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Delete Collection")
            .accessibilityLabel("Delete \(tab.displayName)")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// A show/hide toggle row for a fixed Tools sidebar item.
private struct ToolVisibilityRow: View {
    let title: String
    let systemImage: String
    @AppStorage private var isVisible: Bool

    init(title: String, systemImage: String, key: String) {
        self.title = title
        self.systemImage = systemImage
        _isVisible = AppStorage(wrappedValue: true, key)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(title)
            Spacer(minLength: 8)
            Toggle("", isOn: $isVisible)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel("Show \(title)")
        }
        .padding(.vertical, 4)
    }
}
