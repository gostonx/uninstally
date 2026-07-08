import SwiftUI

/// Sidebar destinations in the standalone window.
enum SidebarItem: Hashable {
    case filter(SmartFilter)
    case leftovers
    case homebrew
}

/// The standalone experience: a customisable source-list sidebar of smart filters
/// (plus static tools), with a detail pane that shows the application browser,
/// leftover scanner or Homebrew manager. Sidebar order, visibility, pinned
/// favourites and collapsed state are owned by `AppSidebarManager`.
struct MainWindowView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppSidebarManager.self) private var sidebarManager
    @State private var selection: SidebarItem? = .filter(.all)
    @State private var showCustomize = false

    private var browser: AppBrowserModel { coordinator.browserModel }

    var body: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            detail
                .navigationSplitViewColumnWidth(min: 480, ideal: 720)
        }
        .task {
            if browser.apps.isEmpty { await browser.load() }
        }
        .onChange(of: selection) { _, _ in
            HapticManager.shared.sectionChanged()
        }
        .sheet(isPresented: $showCustomize) {
            CustomizeAppSidebarView(manager: sidebarManager, browser: browser)
        }
    }

    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { sidebarManager.isCollapsed ? .detailOnly : .all },
            set: { sidebarManager.isCollapsed = ($0 == .detailOnly) }
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            if sidebarManager.hasPinned {
                Section("Favorites") {
                    ForEach(sidebarManager.pinnedVisibleItems) { item in
                        filterRow(item.filter)
                    }
                }
            }

            Section("Applications") {
                ForEach(sidebarManager.unpinnedVisibleItems) { item in
                    filterRow(item.filter)
                }
            }

            Section("Tools") {
                Label("Leftover Scanner", systemImage: "trash.slash.fill")
                    .tag(SidebarItem.leftovers)
                Label("Homebrew", systemImage: "mug.fill")
                    .tag(SidebarItem.homebrew)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) { brandHeader }
        .safeAreaInset(edge: .bottom) { customizeBar }
    }

    private func filterRow(_ filter: SmartFilter) -> some View {
        Label {
            HStack {
                Text(filter.rawValue)
                Spacer()
                Text("\(browser.count(for: filter))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: filter.systemImage)
                .foregroundStyle(filter == .brokenInstalls ? .orange : Color.accentColor)
        }
        .tag(SidebarItem.filter(filter))
        .contextMenu {
            Button(sidebarManager.isPinned(filter) ? "Unpin from Top" : "Pin to Top",
                   systemImage: sidebarManager.isPinned(filter) ? "pin.slash" : "pin") {
                sidebarManager.togglePin(filter.id)
            }
            Button("Hide from Sidebar", systemImage: "eye.slash") {
                sidebarManager.setVisible(filter.id, false)
            }
            Divider()
            Button("Customize Sidebar…", systemImage: "slider.horizontal.3") {
                showCustomize = true
            }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 0) {
                Text("uninstally")
                    .font(.headline)
                Text("by Codenta")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Open Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var customizeBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                showCustomize = true
            } label: {
                Label("Customize Sidebar…", systemImage: "slider.horizontal.3")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .help("Reorder, pin, or hide sidebar sections")
        }
        .background(.bar)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .filter(let filter):
            AppBrowserView(filter: filter)
        case .leftovers:
            LeftoverScannerView()
        case .homebrew:
            HomebrewView()
        case nil:
            ContentUnavailableView("Select a Category", systemImage: "sidebar.left")
        }
    }
}
