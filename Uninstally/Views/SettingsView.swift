import SwiftUI

/// One section's on-screen position, reported for scroll-spy highlighting.
private struct SpyEntry: Equatable {
    let section: SettingsSection
    let minY: CGFloat
}

private struct SpyKey: PreferenceKey {
    static let defaultValue: [SpyEntry] = []
    static func reduce(value: inout [SpyEntry], nextValue: () -> [SpyEntry]) {
        value.append(contentsOf: nextValue())
    }
}

/// The Settings window: a **single continuous page** listing every section, with a
/// fixed table-of-contents sidebar used purely for navigation. Selecting a sidebar
/// item smoothly scrolls to that section and highlights it; scrolling updates the
/// highlight in return (scroll-spy). The sidebar order is fixed — sidebar
/// customization lives in the main application window, not here.
struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: SettingsSection? = SettingsSection.allCases.first
    /// Guards against the scroll-spy and the click-to-scroll fighting each other.
    @State private var spyDriven = false
    @State private var suppressSpyUntil = Date.distantPast

    private let space = "settingsScroll"

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 208, ideal: 220, max: 260)
            .toolbar(removing: .sidebarToggle)
            .accessibilityLabel("Settings sections")
        } detail: {
            page
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 840, height: 580)
        .translucentWindowBackground()
    }

    private var page: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(SettingsSection.allCases) { section in
                        SettingsSectionCard(section: section)
                            .id(section)
                            .background(spyProbe(section))
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(28)
            }
            .coordinateSpace(.named(space))
            .scrollContentBackground(.hidden)
            .onChange(of: selection) { _, newValue in
                scroll(to: newValue, proxy: proxy)
            }
            .onPreferenceChange(SpyKey.self) { entries in
                updateActiveSection(from: entries)
            }
        }
    }

    private func spyProbe(_ section: SettingsSection) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: SpyKey.self,
                value: [SpyEntry(section: section, minY: geo.frame(in: .named(space)).minY)]
            )
        }
    }

    // MARK: - Scroll coordination

    private func scroll(to section: SettingsSection?, proxy: ScrollViewProxy) {
        if spyDriven {
            spyDriven = false
            return
        }
        guard let section else { return }
        suppressSpyUntil = Date().addingTimeInterval(0.6)
        if reduceMotion {
            proxy.scrollTo(section, anchor: .top)
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(section, anchor: .top)
            }
        }
    }

    private func updateActiveSection(from entries: [SpyEntry]) {
        guard Date() >= suppressSpyUntil, !entries.isEmpty else { return }
        let threshold: CGFloat = 48
        let passed = entries.filter { $0.minY <= threshold }
        let active = passed.max(by: { $0.minY < $1.minY })?.section
            ?? entries.min(by: { $0.minY < $1.minY })?.section

        guard let active, active != selection else { return }
        spyDriven = true
        selection = active
    }
}
