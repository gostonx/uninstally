import SwiftUI

struct AppInspectorView: View {
    let app: AppInfo
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var relatedFiles: [RemovableItem] = []
    @State private var isLoading = false
    @State private var hasScanned = false

    private let explainer = FileExplanationEngine()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()
                basicInfo
                Divider()
                datesSection
                Divider()
                storageSection
                if hasScanned || !relatedFiles.isEmpty {
                    Divider()
                    relatedFilesSection
                }
            }
            .padding(24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(VisualEffectView(material: .menu).ignoresSafeArea())
        .navigationTitle(app.name)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    dismiss()
                    coordinator.startUninstall(for: app)
                } label: {
                    Label("Uninstall\u{2026}", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            AppIconView(url: app.url, size: 72)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.title.weight(.semibold))
                if !app.developer.isEmpty {
                    Text(app.developer).font(.title3).foregroundStyle(.secondary)
                }
                if !app.bundleIdentifier.isEmpty {
                    Text(app.bundleIdentifier)
                        .font(.caption).foregroundStyle(.tertiary).textSelection(.enabled)
                }
                HStack(spacing: 6) {
                    Image(systemName: app.installationSource.systemImage)
                        .font(.caption)
                    Text(app.installationSource.rawValue)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.vertical, 2).padding(.horizontal, 8)
                .background(.quaternary.opacity(0.5), in: Capsule())
            }
        }
    }

    // MARK: - Basic info

    private var basicInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            infoRow("Version", app.displayVersion)
            if !app.category.isEmpty, app.category != "Other" {
                infoRow("Category", app.category)
            }
            infoRow("Location", app.location)
            infoRow("Size", Format.bytes(app.sizeBytes))
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.callout).foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.callout).textSelection(.enabled)
        }
    }

    // MARK: - Dates

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let d = app.installDate {
                HStack(alignment: .firstTextBaseline) {
                    Text("Installed")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Format.date(d)).font(.callout)
                        Text(Format.relativeDate(d)).font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            if let d = app.lastUsedDate {
                HStack(alignment: .firstTextBaseline) {
                    Text("Last Opened")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Format.date(d)).font(.callout)
                        Text(Format.relativeDate(d)).font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Storage").font(.headline)
            infoRow("Application", Format.bytes(app.sizeBytes))
            if hasScanned {
                let relatedBytes = relatedFiles.reduce(0) { $0 + $1.sizeBytes }
                infoRow("Related Data", Format.bytes(relatedBytes))
                Divider()
                infoRow("Total", Format.bytes(app.sizeBytes + relatedBytes))
            } else if !isLoading {
                Button {
                    Task { await loadRelatedFiles() }
                } label: {
                    Label("Scan for Related Files", systemImage: "magnifyingglass")
                        .font(.callout)
                }
                .padding(.top, 4)
            }
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Scanning\u{2026}").font(.callout).foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Related files

    private var relatedFilesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Related Files").font(.headline)
                Spacer()
                Text("\(relatedFiles.count) file\(relatedFiles.count == 1 ? "" : "s")")
                    .font(.callout).foregroundStyle(.secondary)
            }

            ForEach(groupedFiles.keys.sorted(by: { $0.order < $1.order }), id: \.self) { category in
                if let files = groupedFiles[category] {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: category.systemImage)
                                .foregroundStyle(category.tint)
                            Text(category.title)
                                .font(.callout.weight(.semibold))
                            Spacer()
                            Text("\(files.count)").font(.caption).foregroundStyle(.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }
                        ForEach(files, id: \.url) { file in
                            fileRow(file)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var groupedFiles: [RemovalCategory: [RemovableItem]] {
        Dictionary(grouping: relatedFiles, by: \.category)
    }

    private func fileRow(_ file: RemovableItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(file.name).font(.caption.weight(.medium)).lineLimit(1)
                Spacer()
                Text(Format.bytes(file.sizeBytes)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text(file.displayPath)
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            Text(explainer.explain(category: file.category, url: file.url, appName: app.name))
                .font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
        .contextMenu {
            Button("Show in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
            Button("Copy Path", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.url.path, forType: .string)
            }
        }
    }

    private func loadRelatedFiles() async {
        isLoading = true
        let scanner = AssociatedFileScanner()
        let files = await scanner.scan(for: app, includeSystem: true)
        relatedFiles = files.sorted { $0.sizeBytes > $1.sizeBytes }
        hasScanned = true
        isLoading = false
    }
}
