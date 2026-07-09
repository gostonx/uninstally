import SwiftUI
import SwiftData

/// Sidebar destinations in the standalone window.
enum SidebarItem: Hashable {
    case filter(SmartFilter)
    case customTab(UUID)
    case recentlyUninstalled
    case storageInsights
    case leftovers
    case homebrew
}

/// The standalone experience: a customisable source-list sidebar of smart filters,
/// user-created Collections, and static tools, with a detail pane that shows the
/// application browser, leftover scanner or Homebrew manager. Sidebar order,
/// visibility, pinned favourites and collapsed state are owned by
/// `AppSidebarManager`; Collections by `CustomTabManager`.
struct MainWindowView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppSidebarManager.self) private var sidebarManager
    @Environment(CustomTabManager.self) private var collections
    @AppStorage(AppSettings.showRecentlyUninstalledKey) private var showRecentlyUninstalled = true
    @AppStorage(AppSettings.showStorageInsightsKey) private var showStorageInsights = true
    @Query private var historyRecords: [UninstallRecord]
    @State private var selection: SidebarItem? = .filter(.all)
    @State private var showCustomize = false
    @State private var renamingTabID: UUID?
    @State private var renameText = ""

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
            collections.prune(installedKeys: browser.installedKeys)
        }
        .sheet(isPresented: $showCustomize) {
            CustomizeAppSidebarView(manager: sidebarManager, collections: collections, browser: browser)
        }
        .alert("Rename Collection", isPresented: Binding(
            get: { renamingTabID != nil },
            set: { if !$0 { renamingTabID = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingTabID = nil }
            Button("Rename") {
                if let id = renamingTabID {
                    collections.rename(id, to: renameText.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                renamingTabID = nil
            }
        } message: {
            Text("Enter a new name for this collection.")
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

            Section {
                ForEach(collections.tabs) { tab in
                    collectionRow(tab)
                }
                Button {
                    createCollection()
                } label: {
                    Label("New Collection", systemImage: "plus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } header: {
                Text("Collections")
            }

            Section("Tools") {
                if showStorageInsights {
                    Label("Storage Insights", systemImage: "chart.pie.fill")
                        .tag(SidebarItem.storageInsights)
                        .contextMenu {
                            Button("Hide from Sidebar", systemImage: "eye.slash") {
                                if selection == .storageInsights { selection = .filter(.all) }
                                showStorageInsights = false
                            }
                        }
                }
                if showRecentlyUninstalled {
                    Label {
                        HStack {
                            Text("Recently Uninstalled")
                            Spacer()
                            Text("\(historyRecords.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(Color.accentColor)
                    }
                    .tag(SidebarItem.recentlyUninstalled)
                    .contextMenu {
                        Button("Hide from Sidebar", systemImage: "eye.slash") {
                            if selection == .recentlyUninstalled { selection = .filter(.all) }
                            showRecentlyUninstalled = false
                        }
                        Button("Customize Sidebar…", systemImage: "slider.horizontal.3") {
                            showCustomize = true
                        }
                    }
                }
                Label("Leftover Scanner", systemImage: "trash.slash.fill")
                    .tag(SidebarItem.leftovers)
                Label("Homebrew", systemImage: "mug.fill")
                    .tag(SidebarItem.homebrew)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { sidebarFooter }
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

    private func collectionRow(_ tab: CustomTab) -> some View {
        Label {
            HStack {
                Text(tab.displayName)
                Spacer()
                Text("\(browser.count(inCollection: tab))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: tab.symbol)
                .foregroundStyle(Color.accentColor)
        }
        .tag(SidebarItem.customTab(tab.id))
        .dropDestination(for: String.self) { keys, _ in
            collections.add(keys, to: tab.id)
            return true
        }
        .contextMenu {
            Button("Rename…", systemImage: "pencil") {
                renameText = tab.displayName
                renamingTabID = tab.id
            }
            Button("Customize Collections…", systemImage: "slider.horizontal.3") {
                showCustomize = true
            }
            Divider()
            Button("Delete Collection", systemImage: "trash", role: .destructive) {
                if selection == .customTab(tab.id) { selection = .filter(.all) }
                collections.delete(tab.id)
            }
        }
    }

    private var sidebarFooter: some View {
        HStack(spacing: 2) {
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .accessibilityLabel("Open Settings")

            Button {
                createCollection()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("New Collection")
            .accessibilityLabel("New Collection")

            Spacer()

            Button {
                showCustomize = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help("Customize sidebar and Collections")
            .accessibilityLabel("Customize Sidebar")
        }
        .font(.body)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func createCollection() {
        let tab = collections.createTab(name: "New Collection")
        selection = .customTab(tab.id)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .filter(let filter):
            AppBrowserView(scope: .filter(filter))
        case .customTab(let id):
            if let tab = collections.tab(id: id) {
                AppBrowserView(scope: .collection(tab))
            } else {
                ContentUnavailableView("Collection Not Found", systemImage: "folder.badge.questionmark")
            }
        case .leftovers:
            LeftoverScannerView()
        case .homebrew:
            HomebrewView()
        case .recentlyUninstalled:
            RecentlyUninstalledView()
        case .storageInsights:
            StorageInsightsView()
        case nil:
            ContentUnavailableView("Select a Category", systemImage: "sidebar.left")
        }
    }
}
