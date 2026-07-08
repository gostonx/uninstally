import SwiftUI

/// A single removable artefact row: a selection checkbox, file icon, path, the
/// match reason, and its size. Supports Quick Look and Reveal-in-Finder.
struct RemovableItemRow: View {
    let item: RemovableItem
    let onToggle: (Bool) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Remove \(item.name)", isOn: Binding(
                get: { item.isSelected },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(item.category == .application)

            Image(nsImage: IconLoader.shared.icon(for: item.url, size: 32))
                .resizable()
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.displayPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(item.matchReason)
            }

            Spacer()

            if item.requiresAdmin {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help("Requires administrator privileges")
            }

            Text(Format.bytes(item.sizeBytes))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            if isHovering {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                } label: {
                    Image(systemName: "arrow.forward.circle")
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isHovering ? Color.primary.opacity(0.04) : .clear)
        .onHover { hovering in withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering } }
        .contextMenu {
            Button("Reveal in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Button("Copy Path", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(Format.bytes(item.sizeBytes)), \(item.matchReason)")
    }
}
