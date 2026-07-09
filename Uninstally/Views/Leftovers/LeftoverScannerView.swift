import SwiftUI

/// The Leftover Scanner: finds orphaned artefacts from uninstalled apps and lets
/// the user review and remove them.
struct LeftoverScannerView: View {
    @State private var model = LeftoverModel()
    @State private var showRemoveConfirm = false

    var body: some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            if model.isScanning {
                scanning
            } else if model.items.isEmpty {
                empty
            } else {
                content
            }
        }
        .navigationTitle("Leftover Scanner")
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search leftovers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.scan() }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(model.isScanning)
            }
        }
        .task { if model.items.isEmpty { await model.scan() } }
    }

    private var scanning: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text("Scanning for orphaned files…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var empty: some View {
        ContentUnavailableView(
            "No Leftovers Found",
            systemImage: "sparkles",
            description: Text("Your Mac is tidy — no orphaned files from uninstalled apps were detected.")
        )
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Orphaned Files")
                                .font(.largeTitle.weight(.bold))
                            Text("\(model.items.count) items • \(Format.bytes(model.totalBytes)) total")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Select All") { model.selectAll(true) }
                            .buttonStyle(.bordered).controlSize(.large)
                        Button("Deselect All") { model.selectAll(false) }
                            .buttonStyle(.bordered).controlSize(.large)
                    }

                    ForEach(model.groupedItems, id: \.category) { group in
                        GlassCard(padding: 0) {
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: group.category.systemImage)
                                        .foregroundStyle(group.category.tint)
                                    Text(group.category.title).font(.headline)
                                    Spacer()
                                    Text("\(group.items.count)")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                Divider().padding(.horizontal, 12)
                                ForEach(group.items) { item in
                                    LeftoverRow(item: item) { isOn in
                                        model.setSelection(item.id, isSelected: isOn)
                                    }
                                    if item.id != group.items.last?.id {
                                        Divider().padding(.leading, 44)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .scrollContentBackground(.hidden)
            actionBar
        }
    }

    private var actionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(Format.bytes(model.selectedBytes))
                    .font(.title3.weight(.bold)).monospacedDigit()
                Text("\(model.selectedItems.count) selected")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRemoving {
                ProgressView().controlSize(.small)
            }
            Button("Remove Selected") {
                showRemoveConfirm = true
            }
            .buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
            .disabled(model.selectedItems.isEmpty || model.isRemoving)
            .confirmationDialog(
                "Remove \(model.selectedItems.count) leftover items?",
                isPresented: $showRemoveConfirm, titleVisibility: .visible
            ) {
                Button("Remove \(model.selectedItems.count) Items", role: .destructive) {
                    Task { await model.removeSelected() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(DeletionMode.stored == .permanent
                     ? "\(Format.bytes(model.selectedBytes)) will be permanently deleted. This cannot be undone."
                     : "\(Format.bytes(model.selectedBytes)) will be moved to the Trash.")
            }
        }
        .padding(16)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

private struct LeftoverRow: View {
    let item: LeftoverItem
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Remove \(item.name)", isOn: Binding(get: { item.isSelected }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.checkbox)
            Image(nsImage: IconLoader.shared.icon(for: item.url, size: 32))
                .resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.callout).lineLimit(1).truncationMode(.middle)
                Text(item.displayPath).font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(item.associatedIdentifier)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Text(Format.bytes(item.sizeBytes))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .contextMenu {
            Button("Reveal in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        }
    }
}
