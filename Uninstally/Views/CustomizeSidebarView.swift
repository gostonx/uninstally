import SwiftUI

/// The "Customize Sidebar" card shown on the Settings page. Presents every section
/// in a draggable list where the user can reorder items, toggle their visibility
/// in the navigation sidebar, and restore the default layout. Reordering uses
/// native SwiftUI drag-and-drop (with drop indicator and lift animation), fires a
/// haptic on move, and respects Reduce Motion.
struct CustomizeSidebarCard: View {
    @Environment(SidebarManager.self) private var sidebar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var manager = sidebar

        VStack(alignment: .leading, spacing: 12) {
            header

            SettingsCard {
                List {
                    ForEach($manager.items) { $item in
                        SidebarItemRow(item: $item, manager: manager)
                    }
                    .onMove { indices, newOffset in
                        manager.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(manager.items.count) * 44 + 8)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
                           value: manager.items)

                Divider().padding(.leading, 14)

                HStack {
                    Text("Hidden sections still appear on this page — the sidebar only controls navigation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button("Restore Defaults") { manager.reset() }
                        .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.accentColor.gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Customize Sidebar")
                    .font(.title2.weight(.bold))
                Text("Reorder, show or hide navigation sections.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A reorderable, toggleable row representing one sidebar section.
private struct SidebarItemRow: View {
    @Binding var item: SidebarItemConfig
    let manager: SidebarManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
                .help("Drag to reorder")

            Image(systemName: item.section.systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            Text(item.section.title)

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { manager.setEnabled(item.id, $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(!item.section.canDisable)
            .help(item.section.canDisable ? "Show or hide in the sidebar" : "Always shown")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.section.title), \(item.isEnabled ? "shown" : "hidden")")
        .accessibilityHint("Toggle to show or hide in the sidebar")
    }
}
