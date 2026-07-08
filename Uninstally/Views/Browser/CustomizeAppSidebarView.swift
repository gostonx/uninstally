import SwiftUI

/// A lightweight sheet for customising the main Applications sidebar. Presents
/// every available section in a single draggable list where the user can reorder
/// (native drag-and-drop with drop indicator + auto-scroll), pin favourites, and
/// toggle visibility. Reordering fires a haptic on success. Changes persist
/// immediately via `AppSidebarManager`.
struct CustomizeAppSidebarView: View {
    let manager: AppSidebarManager
    let browser: AppBrowserModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var manager = manager

        VStack(spacing: 0) {
            header

            List {
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
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
                       value: manager.items)

            footer
        }
        .frame(width: 440, height: 540)
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
                Text("Drag to reorder, pin favourites, or hide sections.")
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

    private var footer: some View {
        HStack {
            Text("Hidden sections stay available — they're only removed from the sidebar.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Restore Defaults") { manager.reset() }
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

/// A single reorderable row in the customize sheet.
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
