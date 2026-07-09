import SwiftUI
import SwiftData

/// The **Storage Insights** dashboard: a macOS-style storage overview with a
/// usage bar, category breakdown, focused summary cards, largest installed
/// apps (sortable), and the largest leftover files — all searchable.
struct StorageInsightsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Query(sort: \UninstallRecord.dateUninstalled, order: .reverse) private var records: [UninstallRecord]
    @State private var manager = StorageInsightsManager()
    @State private var searchText = ""
    @State private var appSort: AppSortOption = .size

    private var browser: AppBrowserModel { coordinator.browserModel }
    private var stats: StorageStatistics { manager.statistics }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                storageOverview
                statsGrid
                largestAppsSection
                largestLeftoversSection
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Storage Insights")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search apps and leftovers")
        .task { rebuild(force: true) }
        .onChange(of: browser.apps.count) { _, _ in rebuild() }
        .onChange(of: records.count) { _, _ in rebuild(force: true) }
    }

    private func rebuild(force: Bool = false) {
        manager.rebuild(apps: browser.apps, records: records, forceLeftovers: force)
    }

    // MARK: - Storage overview

    private var storageOverview: some View {
        GlassCard(cornerRadius: 12) {
            VStack(spacing: 16) {
                StorageCharts.StorageUsageBar(
                    total: stats.totalDiskCapacity,
                    used: stats.totalDiskUsed,
                    available: stats.totalDiskAvailable
                )

                Divider()

                StorageCharts.CategoryBreakdownList(items: stats.storageCategoryBreakdown)
            }
        }
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
            statCard("Installed Applications", "\(stats.totalApps)", "app.badge")
            statCard("Total App Storage", Format.bytes(stats.totalInstalledSize), "internaldrive")
            statCard("Total Space Recovered", Format.bytes(stats.totalRecovered), "trash")
            statCard("Largest Installed App", stats.largestApp?.name ?? "\u{2014}", "arrow.up.circle",
                     detail: stats.largestApp.map { Format.bytes($0.sizeBytes) })
            statCard("Largest Leftover Files", Format.bytes(manager.largestLeftovers.reduce(0) { $0 + $1.sizeBytes }),
                     "folder.badge.questionmark", detail: "\(manager.largestLeftovers.count) files")
        }
    }

    private func statCard(_ title: String, _ value: String, _ symbol: String, detail: String? = nil) -> some View {
        GlassCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: symbol)
                    .font(.caption).foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let detail {
                    Text(detail).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Largest apps

    private var filteredApps: [AppInfo] {
        var apps = appSort.sorted(stats.largestApps)
        if !searchText.isEmpty {
            apps = apps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.developer.localizedCaseInsensitiveContains(searchText)
            }
        }
        return Array(apps.prefix(searchText.isEmpty ? 15 : 100))
    }

    private var largestAppsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Largest Applications").font(.headline)
                Spacer()
                Picker("Sort", selection: $appSort) {
                    ForEach([AppSortOption.size, .name, .recentlyUsed, .installDate]) { option in
                        Label(option.rawValue, systemImage: option.systemImage).tag(option)
                    }
                }
                .pickerStyle(.menu).fixedSize()
            }
            GlassCard(cornerRadius: 12, padding: 0) {
                VStack(spacing: 0) {
                    ForEach(filteredApps) { app in
                        appRow(app)
                        if app.id != filteredApps.last?.id { Divider().padding(.leading, 52) }
                    }
                    if filteredApps.isEmpty {
                        Text("No matching applications").foregroundStyle(.secondary)
                            .padding(.vertical, 24)
                    }
                }
            }
        }
    }

    private func appRow(_ app: AppInfo) -> some View {
        HStack(spacing: 12) {
            AppIconView(url: app.url, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).font(.callout.weight(.medium)).lineLimit(1)
                HStack(spacing: 4) {
                    Text(app.developer.isEmpty ? app.bundleIdentifier : app.developer)
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    if !app.displayVersion.isEmpty, app.displayVersion != "\u{2014}" {
                        Text("\u{2022} \(app.displayVersion)").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.bytes(app.sizeBytes)).font(.callout.monospacedDigit())
                HStack(spacing: 8) {
                    Text("Installed \(Format.relativeDate(app.installDate))").font(.caption2).foregroundStyle(.secondary)
                    Text("Opened \(Format.relativeDate(app.lastUsedDate))").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { coordinator.startUninstall(for: app) }
    }

    // MARK: - Largest leftovers

    private var filteredLeftovers: [LeftoverItem] {
        guard !searchText.isEmpty else { return manager.largestLeftovers }
        return manager.largestLeftovers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.associatedIdentifier.localizedCaseInsensitiveContains(searchText)
                || $0.displayPath.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var largestLeftoversSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Largest Leftover Files").font(.headline)
                if manager.isScanningLeftovers { ProgressView().controlSize(.small) }
                Spacer()
                Button("Remove Leftovers") { coordinator.showBrowser() }
                    .controlSize(.small)
                    .disabled(manager.largestLeftovers.isEmpty)
                    .help("Open the Leftover Scanner to review and remove orphaned files")
            }
            GlassCard(cornerRadius: 12, padding: 0) {
                VStack(spacing: 0) {
                    if filteredLeftovers.isEmpty {
                        Text(manager.isScanningLeftovers ? "Scanning for leftovers\u{2026}" : "No orphaned files found")
                            .foregroundStyle(.secondary).padding(.vertical, 24)
                    } else {
                        ForEach(filteredLeftovers) { item in
                            leftoverRow(item)
                            if item.id != filteredLeftovers.last?.id { Divider().padding(.leading, 46) }
                        }
                    }
                }
            }
        }
    }

    private func leftoverRow(_ item: LeftoverItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.systemImage).foregroundStyle(item.category.tint).frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.callout).lineLimit(1).truncationMode(.middle)
                Text(item.displayPath).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(item.category.title).font(.caption2).foregroundStyle(.tertiary)
            Text(Format.bytes(item.sizeBytes)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
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
