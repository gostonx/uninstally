import SwiftUI

/// Sidebar routes in the Settings window: one per enabled section, plus the
/// customisation screen.
private enum SettingsRoute: Hashable {
    case section(SettingsSection)
    case customize
}

/// The app's preferences window. A source-list sidebar lists the user's enabled
/// tabs in their chosen order, followed by a "Customize Settings…" entry. Tab
/// order, names and visibility are owned by `TabManager` and persist across
/// launches.
struct SettingsView: View {
    @Environment(TabManager.self) private var tabManager
    @State private var selection: SettingsRoute?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Settings") {
                    ForEach(tabManager.enabledTabs) { tab in
                        Label(tab.title, systemImage: tab.section.systemImage)
                            .tag(SettingsRoute.section(tab.section))
                    }
                }
                Section {
                    Label("Customize Settings…", systemImage: "slider.horizontal.3")
                        .tag(SettingsRoute.customize)
                }
            }
            .navigationSplitViewColumnWidth(210)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 480)
        .onAppear {
            if selection == nil {
                selection = tabManager.enabledTabs.first.map { .section($0.section) } ?? .customize
            }
        }
        .onChange(of: selection) { _, _ in
            HapticManager.shared.sectionChanged()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .section(.general): GeneralSettingsView()
        case .section(.updates): UpdatesSettingsView()
        case .section(.appearance): AppearanceSettingsView()
        case .section(.advanced): AdvancedSettingsView()
        case .section(.about): AboutSettingsView()
        case .customize: CustomizeSettingsView()
        case nil:
            ContentUnavailableView("Settings", systemImage: "gearshape")
        }
    }
}
