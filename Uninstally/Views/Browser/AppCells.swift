import SwiftUI

/// A single application cell in the grid layout, with hover elevation, a selection
/// affordance and a Quick Look / reveal context menu.
struct AppGridCell: View {
    let app: AppInfo
    var isSelecting: Bool
    var isSelected: Bool
    var collectionID: UUID?

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                AppIconView(url: app.url, size: 72)
                    .shadow(color: .black.opacity(isHovering ? 0.22 : 0.12),
                            radius: isHovering ? 10 : 5, y: isHovering ? 5 : 2)
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, isSelected ? Color.accentColor : .secondary)
                        .background(Circle().fill(.background).padding(2))
                        .offset(x: 6, y: -6)
                }
            }

            VStack(spacing: 2) {
                Text(app.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let format = app.pluginFormat {
                    Text(format)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
                Text(Format.bytes(app.sizeBytes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if let prev = app.previousSizeBytes, prev != app.sizeBytes {
                    Text(app.sizeBytes > prev ? "+\(Format.bytes(app.sizeBytes - prev))" : "-\(Format.bytes(prev - app.sizeBytes))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : (isHovering ? Color.primary.opacity(0.06) : .clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
        )
        .scaleEffect(isHovering && !isSelecting ? 1.03 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onHover { isHovering = $0 }
        .draggable(app.collectionKey)
        .contextMenu { AppContextMenu(app: app, collectionID: collectionID) }
        .help("\(app.name) — \(app.developer.isEmpty ? app.bundleIdentifier : app.developer)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name), \(Format.bytes(app.sizeBytes))")
        .accessibilityAddTraits(.isButton)
    }
}

/// A single application row in the list layout.
struct AppListRow: View {
    let app: AppInfo
    var isSelecting: Bool
    var isSelected: Bool
    var collectionID: UUID?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            AppIconView(url: app.url, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).font(.body.weight(.medium))
                HStack(spacing: 6) {
                    if let format = app.pluginFormat {
                        Text(format)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                    if !app.developer.isEmpty {
                        Text(app.developer)
                    }
                    if app.isBrokenInstall {
                        Label("Broken", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(Format.bytes(app.sizeBytes))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                if let prev = app.previousSizeBytes, prev != app.sizeBytes {
                    Text(app.sizeBytes > prev ? "+\(Format.bytes(app.sizeBytes - prev))" : "-\(Format.bytes(prev - app.sizeBytes))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
                Text(Format.relativeDate(app.installDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : (isHovering ? Color.primary.opacity(0.05) : .clear))
        )
        .onHover { isHovering = $0 }
        .draggable(app.collectionKey)
        .contextMenu { AppContextMenu(app: app, collectionID: collectionID) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name), \(Format.bytes(app.sizeBytes)), \(app.developer)")
    }
}

/// Shared context menu for an application, offering reveal / Quick Look /
/// Collection filing / uninstall.
struct AppContextMenu: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(CustomTabManager.self) private var collections
    let app: AppInfo
    /// When non-nil, the app is being shown inside this Collection, enabling a
    /// "Remove from Collection" action.
    var collectionID: UUID?

    var body: some View {
        Button(app.isPlugin ? "Uninstall Plugin…" : "Uninstall…", systemImage: "trash") {
            coordinator.startUninstall(for: app)
        }
        Divider()
        collectionMenu
        Divider()
        Button("Show in Finder", systemImage: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting([app.url])
        }
        Button("Open", systemImage: "arrow.up.forward.app") {
            NSWorkspace.shared.open(app.url)
        }
        Divider()
        Button("Show Details", systemImage: "info.circle") {
            coordinator.showInspector(for: app)
        }
        .keyboardShortcut("i", modifiers: .command)
    }

    @ViewBuilder
    private var collectionMenu: some View {
        Menu("Add to Collection", systemImage: "folder.badge.plus") {
            ForEach(collections.tabs) { tab in
                Button {
                    collections.add(app.collectionKey, to: tab.id)
                } label: {
                    Label(tab.displayName, systemImage: tab.symbol)
                }
                .disabled(tab.contains(app.collectionKey))
            }
            if !collections.tabs.isEmpty { Divider() }
            Button("New Collection…", systemImage: "plus") {
                collections.createTab(name: "New Collection", initialKey: app.collectionKey)
            }
        }

        if let collectionID, collections.tab(id: collectionID)?.contains(app.collectionKey) == true {
            Button("Remove from Collection", systemImage: "folder.badge.minus") {
                collections.remove(app.collectionKey, from: collectionID)
            }
        }
    }
}
