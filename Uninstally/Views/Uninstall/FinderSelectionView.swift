import SwiftUI

/// Presented when several `.app` bundles are selected from Finder. Simulates all
/// of them (non-destructively), shows the combined totals, and lets the user
/// **Uninstall All**, **Review Individually**, or **Cancel**.
struct FinderSelectionView: View {
    let apps: [AppInfo]
    @Environment(AppCoordinator.self) private var coordinator

    @State private var rows: [Row] = []
    @State private var isScanning = true
    @State private var scanTask: Task<Void, Never>?

    private struct Row: Identifiable {
        let app: AppInfo
        var fileCount: Int
        var bytes: Int64
        var id: String { app.id }
    }

    private var totalFiles: Int { rows.reduce(0) { $0 + $1.fileCount } }
    private var totalBytes: Int64 { rows.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        VStack(spacing: 0) {
            header
            list
            footer
        }
        .task { scanTask = Task { await simulateAll() } }
        .onDisappear { scanTask?.cancel() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
            Text("\(apps.count) Applications Selected")
                .font(.title2.weight(.semibold))
            Text("Uninstally simulated each app. Nothing has been deleted.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28).padding(.bottom, 16)
    }

    private var list: some View {
        List {
            ForEach(rows) { row in
                HStack(spacing: 12) {
                    AppIconView(url: row.app.url, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.app.name).font(.body.weight(.medium))
                        Text(row.app.developer.isEmpty ? row.app.bundleIdentifier : row.app.developer)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Format.bytes(row.bytes)).font(.callout.monospacedDigit())
                            Text("\(row.fileCount) files").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Format.bytes(totalBytes)).font(.headline.monospacedDigit())
                    Text("\(totalFiles) files across \(apps.count) apps")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    scanTask?.cancel()
                    coordinator.cancelFinderSelection()
                }
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                Button("Review Individually") { coordinator.reviewIndividually(apps) }
                    .controlSize(.large)
                Button("Uninstall All") { coordinator.uninstallAllSelected(apps) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(.bar)
        }
    }

    private func simulateAll() async {
        rows = apps.map { Row(app: $0, fileCount: 0, bytes: 0) }
        let scanner = AssociatedFileScanner()
        for (index, app) in apps.enumerated() {
            if Task.isCancelled { return }
            let items = await scanner.scan(for: app)
            let bytes = items.reduce(Int64(0)) { $0 + $1.sizeBytes }
            if index < rows.count {
                rows[index] = Row(app: app, fileCount: items.count, bytes: bytes)
            }
        }
        isScanning = false
    }
}
