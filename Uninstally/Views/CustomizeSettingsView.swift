import SwiftUI

/// The "Customize Settings" screen: a draggable list of every settings tab where
/// the user can reorder (drag), rename, and enable/disable each one. Changes are
/// persisted immediately by `TabManager`.
struct CustomizeSettingsView: View {
    @Environment(TabManager.self) private var tabManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var manager = tabManager

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Customize Settings")
                    .font(.title2.weight(.semibold))
                Text("Drag to reorder, rename, or hide tabs. Changes are saved automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            List {
                ForEach($manager.tabs) { $tab in
                    TabRow(tab: $tab, manager: manager)
                        .listRowSeparator(.visible)
                }
                .onMove { indices, newOffset in
                    manager.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
                       value: manager.tabs)

            HStack {
                Spacer()
                Button("Restore Defaults") { manager.reset() }
                    .controlSize(.regular)
            }
            .padding(20)
        }
        .navigationTitle("Customize Settings")
    }
}

/// A single reorderable, editable row in the customization list.
private struct TabRow: View {
    @Binding var tab: SettingsTabConfig
    let manager: TabManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
                .help("Drag to reorder")

            Image(systemName: tab.section.systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            TextField(
                "Tab name",
                text: $tab.customTitle,
                prompt: Text(tab.section.defaultTitle)
            )
            .textFieldStyle(.plain)
            .accessibilityLabel("Name for \(tab.section.defaultTitle) tab")

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { tab.isEnabled },
                set: { manager.setEnabled(tab.id, $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(!tab.section.canDisable)
            .help(tab.section.canDisable ? "Show or hide this tab" : "This tab can't be hidden")
            .accessibilityLabel("Show \(tab.title) tab")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tab.title) tab, \(tab.isEnabled ? "enabled" : "disabled")")
    }
}
