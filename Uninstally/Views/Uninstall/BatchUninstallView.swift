import SwiftUI

/// The batch uninstall flow: reviews the selected apps and their combined size,
/// then runs them sequentially while showing aggregate progress, and finally a
/// summary.
struct BatchUninstallView: View {
    @Bindable var model: BatchUninstallModel
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .review: reviewList
            case .running: runningView
            case .finished: summaryView
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.phase)
    }

    // MARK: - Review

    private var reviewList: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    ForEach(model.apps) { app in
                        GlassCard(cornerRadius: 12, padding: 12) {
                            HStack(spacing: 12) {
                                AppIconView(url: app.url, size: 40)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(app.name).font(.body.weight(.medium))
                                    Text(app.developer.isEmpty ? app.bundleIdentifier : app.developer)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Format.bytes(app.sizeBytes))
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Batch Uninstall")
                .font(.largeTitle.weight(.bold))
            Text("\(model.apps.count) applications • about \(Format.bytes(model.totalEstimatedBytes)) reclaimable")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionBar: some View {
        let mode = DeletionMode.stored
        return HStack {
            Label(mode == .permanent
                    ? "This will permanently delete the selected apps. This action cannot be undone."
                    : "The selected apps and their files will be moved to the Trash.",
                  systemImage: mode == .permanent ? "exclamationmark.triangle.fill" : "arrow.uturn.backward.circle.fill")
                .font(.caption)
                .foregroundStyle(mode == .permanent ? .red : .secondary)
            Spacer()
            Button("Cancel") { coordinator.showBrowser() }
                .buttonStyle(.bordered).controlSize(.large)
                .keyboardShortcut(.cancelAction)
            Button(mode == .permanent ? "Delete \(model.apps.count) Apps" : "Uninstall \(model.apps.count) Apps") {
                Task { await model.run() }
            }
            .buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Running

    private var runningView: some View {
        VStack(spacing: 24) {
            if let current = model.currentApp {
                AppIconView(url: current.url, size: 80)
                Text("Removing \(current.name)")
                    .font(.title2.weight(.semibold))
                Text("\(model.currentIndex + 1) of \(model.apps.count)")
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: model.overallFraction)
                .progressViewStyle(.linear)
                .frame(width: 360)
            Text(model.progress?.currentPath ?? "")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Summary

    private var summaryView: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 90))
                .foregroundStyle(.green)
            Text("Batch Complete")
                .font(.title.weight(.semibold))
            Text("Removed \(model.results.count) applications")
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                summaryStat(Format.bytes(model.reclaimedBytes), "Reclaimed")
                Divider().frame(height: 44)
                summaryStat("\(model.removedFileCount)", "Files Removed")
            }
            .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button("Done") {
                // Optimistically drop every app that was actually removed, with no
                // full rescan, so the browser reflects the changes instantly.
                let removed = Set(model.apps.filter { !FileSystemUtil.exists($0.url) }.map(\.id))
                coordinator.browserModel.remove(ids: removed)
                coordinator.showBrowser()
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func summaryStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(minWidth: 120)
    }
}
