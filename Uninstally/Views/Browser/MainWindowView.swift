import SwiftUI

/// Sidebar destinations in the standalone window.
enum SidebarItem: Hashable {
    case filter(SmartFilter)
    case leftovers
    case homebrew
}

/// The standalone experience: a source-list sidebar of smart filters and tools,
/// with a detail pane that shows the application browser, leftover scanner or
/// Homebrew manager.
struct MainWindowView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selection: SidebarItem? = .filter(.all)

    var body: some View {
        @Bindable var browser = coordinator.browserModel

        NavigationSplitView {
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
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        @Bindable var browser = coordinator.browserModel

        return List(selection: $selection) {
            Section("Applications") {
                ForEach(SmartFilter.allCases) { filter in
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
        .safeAreaInset(edge: .top) {
            brandHeader
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
