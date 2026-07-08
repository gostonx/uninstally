import SwiftUI

/// A navigation target in the Settings sidebar: a real section, or the sidebar
/// customisation card (which also lives on the same page).
enum SidebarRoute: Hashable {
    case section(SettingsSection)
    case customize
}

/// One section's on-screen position, reported for scroll-spy highlighting.
private struct SpyEntry: Equatable {
    let route: SidebarRoute
    let minY: CGFloat
}

private struct SpyKey: PreferenceKey {
    static let defaultValue: [SpyEntry] = []
    static func reduce(value: inout [SpyEntry], nextValue: () -> [SpyEntry]) {
        value.append(contentsOf: nextValue())
    }
}

/// The Settings window: a **single continuous page** listing every section, with a
/// customisable sidebar used purely for navigation. Selecting a sidebar item
/// smoothly scrolls to that section and highlights it; scrolling updates the
/// highlight in return (scroll-spy). No extra windows or pages are opened.
struct SettingsView: View {
    @Environment(SidebarManager.self) private var sidebar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: SidebarRoute?
    /// Guards against the scroll-spy and the click-to-scroll fighting each other.
    @State private var spyDriven = false
    @State private var suppressSpyUntil = Date.distantPast

    private let space = "settingsScroll"

    var body: some View {
        NavigationSplitView {
            sidebarList
                .navigationSplitViewColumnWidth(min: 208, ideal: 220, max: 260)
        } detail: {
            page
        }
        .frame(width: 840, height: 580)
        .onAppear {
            if selection == nil { selection = defaultRoute }
        }
    }

    private var defaultRoute: SidebarRoute {
        sidebar.enabledItems.first.map { .section($0.section) } ?? .customize
    }

    // MARK: - Sidebar

    private var sidebarList: some View {
        List(selection: $selection) {
            Section("Settings") {
                ForEach(sidebar.enabledItems) { item in
                    Label(item.section.title, systemImage: item.section.systemImage)
                        .tag(SidebarRoute.section(item.section))
                }
            }
            Section {
                Label("Customize Sidebar…", systemImage: "slider.horizontal.3")
                    .tag(SidebarRoute.customize)
            }
        }
        .listStyle(.sidebar)
        .accessibilityLabel("Settings sections")
    }

    // MARK: - Page

    private var page: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(sidebar.pageOrder, id: \.self) { section in
                        SettingsSectionCard(section: section)
                            .id(SidebarRoute.section(section))
                            .background(spyProbe(.section(section)))
                    }

                    CustomizeSidebarCard()
                        .id(SidebarRoute.customize)
                        .background(spyProbe(.customize))
                }
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(28)
            }
            .coordinateSpace(.named(space))
            .scrollContentBackground(.hidden)
            .background(VibrantBackground())
            .onChange(of: selection) { _, newValue in
                scroll(to: newValue, proxy: proxy)
            }
            .onPreferenceChange(SpyKey.self) { entries in
                updateActiveSection(from: entries)
            }
        }
    }

    private func spyProbe(_ route: SidebarRoute) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: SpyKey.self,
                value: [SpyEntry(route: route, minY: geo.frame(in: .named(space)).minY)]
            )
        }
    }

    // MARK: - Scroll coordination

    private func scroll(to route: SidebarRoute?, proxy: ScrollViewProxy) {
        // If the selection changed because of scrolling, don't scroll again.
        if spyDriven {
            spyDriven = false
            return
        }
        guard let route else { return }
        suppressSpyUntil = Date().addingTimeInterval(0.6)
        if reduceMotion {
            proxy.scrollTo(route, anchor: .top)
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(route, anchor: .top)
            }
        }
    }

    private func updateActiveSection(from entries: [SpyEntry]) {
        guard Date() >= suppressSpyUntil, !entries.isEmpty else { return }
        let threshold: CGFloat = 48
        // The active section is the last one whose top has scrolled past the
        // threshold; if none have, it's the very first section.
        let passed = entries.filter { $0.minY <= threshold }
        let active = passed.max(by: { $0.minY < $1.minY })?.route
            ?? entries.min(by: { $0.minY < $1.minY })?.route

        guard let active, active != selection else { return }
        spyDriven = true
        selection = active
        HapticManager.shared.sectionChanged()
    }
}
