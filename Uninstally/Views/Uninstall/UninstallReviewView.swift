import SwiftUI

/// The primary review screen: the app header, a searchable, grouped, selectable
/// list of everything that will be removed, and the action bar.
struct UninstallReviewView: View {
    @Bindable var model: UninstallModel
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let plan = model.plan {
                        AppHeaderView(
                            app: model.app,
                            reclaimBytes: plan.reclaimableBytes,
                            itemCount: plan.selectedCount
                        )
                    }
                    filesSection
                }
                .padding(24)
            }
            .scrollContentBackground(.hidden)

            actionBar
        }
        .navigationTitle("Uninstall \(model.app.name)")
    }

    // MARK: - Files

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Files that will be removed")
                    .font(.title3.weight(.semibold))
                Spacer()
                searchField
            }

            if model.filteredGroups.isEmpty {
                ContentUnavailableView(
                    "No matching files",
                    systemImage: "magnifyingglass",
                    description: Text("No artefacts match “\(model.searchText)”.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(model.filteredGroups, id: \.category) { group in
                    CategorySection(model: model, category: group.category, items: group.items)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search files", text: $model.searchText)
                .textFieldStyle(.plain)
                .frame(width: 180)
            if !model.searchText.isEmpty {
                Button { model.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.4), in: Capsule())
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 16) {
            if let plan = model.plan {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Format.bytes(plan.reclaimableBytes))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("\(plan.selectedCount) of \(plan.items.count) items selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if plan.requiresAdmin {
                    Label("Requires administrator password", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Cancel") { cancel() }
                .buttonStyle(.bordered).controlSize(.large)
                .keyboardShortcut(.cancelAction)
            Button("Uninstall") { model.requestConfirmation() }
                .buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled((model.plan?.selectedCount ?? 0) == 0)
        }
        .padding(16)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func cancel() {
        if model.isDedicatedSession {
            NSApplication.shared.terminate(nil)
        } else {
            coordinator.showBrowser()
        }
    }
}

/// A collapsible category section with a select-all toggle and per-item rows.
private struct CategorySection: View {
    @Bindable var model: UninstallModel
    let category: RemovalCategory
    let items: [RemovableItem]

    @State private var isExpanded = true

    private var totalBytes: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }
    private var allSelected: Bool { items.allSatisfy(\.isSelected) }

    var body: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                header
                if isExpanded {
                    Divider().padding(.horizontal, 12)
                    ForEach(items) { item in
                        RemovableItemRow(item: item) { isOn in
                            model.setSelection(item.id, isSelected: isOn)
                        }
                        if item.id != items.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: category.systemImage)
                .foregroundStyle(category.tint)
                .frame(width: 22)
            Text(category.title)
                .font(.headline)
            Text("\(items.count)")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
            Spacer()
            Text(Format.bytes(totalBytes))
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if category != .application {
                Toggle("Select all in \(category.title)", isOn: Binding(
                    get: { allSelected },
                    set: { model.setSelection(for: category, isSelected: $0) }
                ))
                .labelsHidden()
                .toggleStyle(.checkbox)
            }
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() }
            } label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}
