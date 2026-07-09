import SwiftUI
import SwiftData
import AppKit

/// The **Recently Uninstalled** page: an uninstall history (not a recycle bin)
/// showing apps removed through Uninstally, with statistics, search, filters, a
/// native list, per-row actions and a details sheet. Backed by SwiftData.
struct RecentlyUninstalledView: View {
    @Environment(HistoryStore.self) private var history
    @Query(sort: \UninstallRecord.dateUninstalled, order: .reverse)
    private var records: [UninstallRecord]

    @State private var searchText = ""
    @State private var filter: HistoryFilter = .all
    @State private var selection: PersistentIdentifier?
    @State private var detailRecord: UninstallRecord?
    @State private var showClearConfirm = false
    @State private var errorMessage: String?
    @State private var isSelecting = false
    @State private var selectedIDs: Set<PersistentIdentifier> = []

    private var filtered: [UninstallRecord] {
        records.filter { filter.matches($0) }.filter { matchesSearch($0) }
    }

    private func matchesSearch(_ record: UninstallRecord) -> Bool {
        guard !searchText.isEmpty else { return true }
        return record.appName.localizedCaseInsensitiveContains(searchText)
            || record.developer.localizedCaseInsensitiveContains(searchText)
            || record.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
    }

    var body: some View {
        Group {
            if records.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Recently Uninstalled")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search history")
        .toolbar { toolbarContent }
        .sheet(item: $detailRecord) { record in
            UninstallRecordDetailView(record: record, onRestore: restore, onReveal: reveal)
        }
        .confirmationDialog("Clear all uninstall history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { history.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every entry from the history. It does not affect files already in the Trash.")
        }
        .alert("Couldn't Restore", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            StatisticsHeader(records: records)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)

            if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(filtered) { record in
                        HistoryRow(record: record, isSelecting: isSelecting, isSelected: selectedIDs.contains(record.persistentModelID))
                            .tag(record.persistentModelID)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
                    if let record = record(for: ids) {
                        rowMenu(record)
                    }
                } primaryAction: { ids in
                    if let record = record(for: ids) { detailRecord = record }
                }
            }
        }
    }

    private func record(for ids: Set<PersistentIdentifier>) -> UninstallRecord? {
        guard let id = ids.first else { return nil }
        return records.first { $0.persistentModelID == id }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Uninstall History", systemImage: "clock.arrow.circlepath")
        } description: {
            Text("Apps you remove with Uninstally will appear here, so you can review or restore them.")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Filter", selection: $filter) {
                    ForEach(HistoryFilter.allCases) { option in
                        Label(option.rawValue, systemImage: option.systemImage).tag(option)
                    }
                }
            } label: {
                Label(filter == .all ? "Filter" : filter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
            }
            .help("Filter history")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                exportHistory()
            } label: {
                Label("Export History", systemImage: "square.and.arrow.up")
            }
            .disabled(records.isEmpty)
            .help("Export history as a text file")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation { isSelecting.toggle(); if !isSelecting { selectedIDs.removeAll() } }
            } label: {
                Label(isSelecting ? "Done" : "Select", systemImage: "checklist")
            }
        }
        if isSelecting && !selectedIDs.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    restoreSelected()
                } label: {
                    Label("Restore \(selectedIDs.count)", systemImage: "arrow.uturn.backward")
                }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("Clear History", systemImage: "trash")
            }
            .disabled(records.isEmpty)
            .help("Clear all history")
        }
    }

    @ViewBuilder
    private func rowMenu(_ record: UninstallRecord) -> some View {
        if record.deletionMethod == .trash {
            Button("Restore from Trash", systemImage: "arrow.uturn.backward") { restore(record) }
                .disabled(record.restorableTrashURL == nil)
        }
        Button("View Details", systemImage: "info.circle") { detailRecord = record }
        Button("Reveal Original Location", systemImage: "folder") { reveal(record) }
        Divider()
        Button("Remove From History", systemImage: "clock.badge.xmark", role: .destructive) {
            history.remove(record)
        }
    }

    // MARK: - Actions

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.title = "Export Uninstall History"
        panel.nameFieldStringValue = "Uninstally History.txt"
        panel.allowedContentTypes = [.plainText]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let lines = records.map { record in
                "\(Format.date(record.dateUninstalled))  \(record.appName)  \(record.developer)  v\(record.version)  \(Format.bytes(Int64(record.storageRecovered)))  \(record.deletionMethod.title)"
            }
            let header = "Uninstally  Uninstall History  \(Format.date(Date()))\n\n"
            try? (header + lines.joined(separator: "\n")).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func restoreSelected() {
        let selected = records.filter { selectedIDs.contains($0.persistentModelID) }
        for record in selected where record.deletionMethod == .trash {
            restore(record)
        }
        selectedIDs.removeAll()
        isSelecting = false
    }

    private func restore(_ record: UninstallRecord) {
        guard let source = record.restorableTrashURL else {
            errorMessage = "This item is no longer in the Trash."
            return
        }
        let destination = URL(fileURLWithPath: record.originalLocation)
            .appendingPathComponent(source.lastPathComponent)
        do {
            try FileManager.default.moveItem(at: source, to: destination)
            record.trashedAppPath = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reveal(_ record: UninstallRecord) {
        let dir = URL(fileURLWithPath: record.originalLocation)
        NSWorkspace.shared.activateFileViewerSelecting([dir])
    }

    private func reinstallViaHomebrew(_ record: UninstallRecord) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        task.arguments = ["reinstall", "--cask", record.bundleIdentifier]
        try? task.run()
    }
}

// MARK: - Statistics header

private struct StatisticsHeader: View {
    let records: [UninstallRecord]

    private var totalStorage: Int { records.reduce(0) { $0 + $1.storageRecovered } }
    private var average: Int { records.isEmpty ? 0 : totalStorage / records.count }
    private var last: Date? { records.first?.dateUninstalled }

    var body: some View {
        HStack(spacing: 0) {
            stat("Apps Uninstalled", "\(records.count)", "app.badge.checkmark")
            Divider().frame(height: 34)
            stat("Storage Recovered", Format.bytes(Int64(totalStorage)), "internaldrive")
            Divider().frame(height: 34)
            stat("Last Uninstall", last.map { Format.relativeDate($0) } ?? "—", "clock")
            Divider().frame(height: 34)
            stat("Average Recovered", Format.bytes(Int64(average)), "chart.bar")
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func stat(_ label: String, _ value: String, _ symbol: String) -> some View {
        VStack(spacing: 3) {
            Label(value, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Row

private struct HistoryRow: View {
    let record: UninstallRecord
    var isSelecting = false
    var isSelected = false

    var body: some View {
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.title3)
            }
            RecordIcon(data: record.iconData, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(record.appName).font(.body.weight(.medium)).lineLimit(1)
                Text(record.developer.isEmpty ? record.bundleIdentifier : record.developer)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            DeletionMethodBadge(mode: record.deletionMethod)
            VStack(alignment: .trailing, spacing: 1) {
                Text(Format.bytes(Int64(record.storageRecovered)))
                    .font(.callout.weight(.medium)).monospacedDigit()
                Text(record.dateUninstalled.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.appName), \(record.developer), removed \(Format.relativeDate(record.dateUninstalled)), \(Format.bytes(Int64(record.storageRecovered))) recovered, \(record.deletionMethod.title)")
    }
}

/// Renders a stored icon PNG, falling back to a generic app glyph.
struct RecordIcon: View {
    let data: Data?
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary)
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A small capsule badge indicating how the app was removed.
struct DeletionMethodBadge: View {
    let mode: DeletionMode

    var body: some View {
        Label(mode == .trash ? "Trash" : "Deleted", systemImage: mode.systemImage)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(mode == .trash ? Color.accentColor : .red)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((mode == .trash ? Color.accentColor : .red).opacity(0.12), in: Capsule())
    }
}
