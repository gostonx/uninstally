import SwiftUI

/// The **Uninstall Simulation** — a complete, non-destructive preview of exactly
/// what an uninstall will remove: identity, a summary checklist, a storage
/// breakdown bar, risk indicators for shared resources, an expandable per-file
/// breakdown with live selection, search, a statistics report, and a clear
/// "nothing has been deleted" confirmation footer.
struct UninstallSimulationView: View {
    @Bindable var model: UninstallModel
    let onCancel: () -> Void
    let onProceed: () -> Void

    @State private var expanded: Set<RemovalCategory> = [.application]

    private var simulation: SimulationResult? { model.simulation }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let simulation {
                        header(simulation)
                        if let score = simulation.safetyScore {
                            SafetyScoreCard(score: score)
                        }
                        SummaryCard(simulation: simulation)
                        StorageAnalysisCard(simulation: simulation)
                        if !simulation.riskFiles.isEmpty {
                            RiskCard(files: simulation.riskFiles)
                        }
                        breakdownSection(simulation)
                        ReportCard(simulation: simulation)
                    }
                }
                .padding(24)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            footer
        }
        .navigationTitle("Uninstall Simulation")
    }

    // MARK: - Header

    private func header(_ simulation: SimulationResult) -> some View {
        HStack(alignment: .top, spacing: 16) {
            AppIconView(url: model.app.url, size: 72)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.app.name).font(.title.weight(.semibold))
                if !model.app.developer.isEmpty {
                    Text(model.app.developer).font(.title3).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    metaChip("Version", model.app.displayVersion)
                    if !model.app.bundleIdentifier.isEmpty {
                        metaChip("Identifier", model.app.bundleIdentifier)
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }

    private func metaChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(.secondary)
            Text(value).foregroundStyle(.primary)
        }
        .font(.caption)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(.quaternary.opacity(0.4), in: Capsule())
        .textSelection(.enabled)
    }

    // MARK: - Breakdown

    private func breakdownSection(_ simulation: SimulationResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Detailed Breakdown").font(.headline)
                Spacer()
                searchField
            }

            let categories = model.filteredCategories
            if categories.isEmpty {
                ContentUnavailableView("No matching files", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                ForEach(categories) { category in
                    CategorySection(
                        category: category,
                        isExpanded: expanded.contains(category.removalCategory),
                        isProtected: category.removalCategory == .application,
                        appName: simulation.app.name,
                        onToggleExpand: { toggleExpand(category.removalCategory) }
                    )
                }
            }
        }
    }

    private func toggleExpand(_ category: RemovalCategory) {
        withAnimation(.snappy(duration: 0.22)) {
            if expanded.contains(category) { expanded.remove(category) } else { expanded.insert(category) }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search files", text: $model.searchText)
                .textFieldStyle(.plain)
                .frame(width: 180)
            if !model.searchText.isEmpty {
                Button { model.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.quaternary.opacity(0.4), in: Capsule())
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 14) {
                Label("This simulation has not deleted any files.", systemImage: "checkmark.shield.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
                Spacer()
                if let simulation {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Format.bytes(simulation.selectedBytes))
                            .font(.headline.monospacedDigit())
                            .contentTransition(.numericText())
                        Text("\(simulation.totalSelected) of \(simulation.totalFiles) items")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button("Cancel", action: onCancel)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                Button("Proceed with Uninstall", action: onProceed)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled((simulation?.totalSelected ?? 0) == 0)
            }
            .padding(16)
            .background(.bar)
        }
    }
}

// MARK: - Summary card

private struct SummaryCard: View {
    let simulation: SimulationResult

    private var lines: [(String, Int)] {
        [
            ("Application", simulation.applicationCount),
            ("Related Files", simulation.relatedFileCount),
            ("Login Items Removed", simulation.loginItemCount),
            ("Launch Agents Removed", simulation.launchAgentCount),
            ("Background Services Removed", simulation.backgroundComponentCount),
            ("Finder Extensions Removed", simulation.extensionCount),
            ("Cache Folders Removed", simulation.cacheFolderCount),
            ("Preference Files Removed", simulation.prefFileCount),
            ("Saved State Removed", simulation.savedStateCount),
        ].filter { $0.1 > 0 }
    }

    var body: some View {
        GlassCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Uninstall Summary").font(.headline)
                    Spacer()
                    Text(Format.bytes(simulation.selectedBytes) + " recoverable")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], alignment: .leading, spacing: 6) {
                    ForEach(lines, id: \.0) { line in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("\(line.1) \(line.0)")
                                .font(.callout)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Storage analysis

private struct StorageAnalysisCard: View {
    let simulation: SimulationResult

    private func color(_ bucket: SimulationResult.StorageBucket) -> Color {
        switch bucket {
        case .application: return .accentColor
        case .support: return .blue
        case .caches: return .orange
        case .preferences: return .green
        case .other: return .gray
        }
    }

    var body: some View {
        GlassCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Storage Analysis").font(.headline)
                    Spacer()
                    Text(Format.bytes(simulation.totalBytes))
                        .font(.headline.monospacedDigit())
                }

                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(SimulationResult.StorageBucket.allCases) { bucket in
                            let bytes = simulation.bucketBytes(bucket)
                            if bytes > 0 {
                                Rectangle()
                                    .fill(color(bucket))
                                    .frame(width: max(2, geo.size.width * CGFloat(bytes) / CGFloat(max(1, simulation.totalBytes))))
                            }
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 12)

                VStack(spacing: 4) {
                    ForEach(SimulationResult.StorageBucket.allCases) { bucket in
                        let bytes = simulation.bucketBytes(bucket)
                        if bytes > 0 {
                            HStack(spacing: 8) {
                                Circle().fill(color(bucket)).frame(width: 8, height: 8)
                                Text(bucket.title).font(.callout)
                                Spacer()
                                Text(Format.bytes(bytes)).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Divider()
                    HStack {
                        Text("Total Recoverable Storage").font(.callout.weight(.semibold))
                        Spacer()
                        Text(Format.bytes(simulation.totalBytes)).font(.callout.weight(.semibold).monospacedDigit())
                    }
                }
            }
        }
    }
}

// MARK: - Risk card

private struct RiskCard: View {
    let files: [SimulationFile]

    var body: some View {
        GlassCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Shared Resources", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(.orange)
                Text("These items may be used by other software. Review them before removing — deselect any you want to keep.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(files) { file in
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill").foregroundStyle(.orange).font(.caption)
                        Text(file.name).font(.callout).lineLimit(1)
                        Spacer()
                        Text(Format.bytes(file.sizeBytes)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.orange.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Report card

private struct ReportCard: View {
    let simulation: SimulationResult

    var body: some View {
        GlassCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Simulation Report").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(simulation.reportStats, id: \.label) { stat in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(stat.value).font(.callout.weight(.semibold).monospacedDigit())
                            Text(stat.label).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Category section

private struct CategorySection: View {
    @Bindable var category: SimulationCategory
    let isExpanded: Bool
    let isProtected: Bool
    let appName: String
    let onToggleExpand: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 12, padding: 0) {
            VStack(spacing: 0) {
                header
                if isExpanded {
                    Divider().padding(.horizontal, 12)
                    ForEach(category.files) { file in
                        SimFileRow(file: file, isProtected: isProtected, appName: appName)
                        if file.id != category.files.last?.id {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { category.isSelected },
                set: { category.isSelected = $0 }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(isProtected)

            Image(systemName: category.removalCategory.systemImage)
                .foregroundStyle(category.removalCategory.tint)
                .frame(width: 22)

            Text(category.removalCategory.title).font(.headline)
            if category.isRisk {
                Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
            }
            Text("\(category.files.count)")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(.quaternary, in: Capsule())

            Spacer()
            Text(Format.bytes(category.totalBytes))
                .font(.callout.weight(.medium)).foregroundStyle(.secondary).monospacedDigit()
            Button(action: onToggleExpand) {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggleExpand)
    }
}

// MARK: - File row

private struct SimFileRow: View {
    @Bindable var file: SimulationFile
    let isProtected: Bool
    let appName: String
    @State private var hovering = false

    private let explainer = FileExplanationEngine()

    private var explanation: String {
        explainer.explain(category: file.category, url: file.url, appName: appName)
    }

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { file.isSelected }, set: { file.isSelected = $0 }))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .disabled(isProtected)

            Image(nsImage: IconLoader.shared.icon(for: file.url, size: 32))
                .resizable().frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(file.name).font(.callout).lineLimit(1).truncationMode(.middle)
                    if file.isShared {
                        Image(systemName: "person.2.fill").font(.caption2).foregroundStyle(.orange)
                    }
                }
                Text(file.displayPath)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Text(explanation)
                    .font(.caption2).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 8)
            if file.requiresAdmin {
                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                    .help("Requires administrator privileges")
            }
            Text(Format.bytes(file.sizeBytes))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            if hovering {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                } label: { Image(systemName: "arrow.forward.circle") }
                    .buttonStyle(.plain).help("Reveal in Finder")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(hovering ? Color.primary.opacity(0.04) : .clear)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Reveal in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
            Button("Copy Path", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.url.path, forType: .string)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(file.name), \(Format.bytes(file.sizeBytes)), \(file.matchReason)")
    }
}

// MARK: - Safety Score Card

private struct SafetyScoreCard: View {
    let score: SafetyScore
    @State private var isExpanded = false

    private var levelColor: Color {
        switch score.level {
        case .safeToRemove: return .green
        case .reviewRecommended: return .orange
        case .highRisk: return .red
        }
    }

    var body: some View {
        GlassCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: { withAnimation(.snappy(duration: 0.22)) { isExpanded.toggle() } }) {
                    HStack(spacing: 12) {
                        Image(systemName: score.level.systemImage)
                            .font(.title2)
                            .foregroundStyle(levelColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(score.level.rawValue)
                                .font(.headline)
                            Text(score.level.headerDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider()

                    VStack(spacing: 8) {
                        ForEach(score.factors) { factor in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: factor.severity.systemImage)
                                    .font(.callout)
                                    .foregroundStyle(factorTint(factor))
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(factor.name)
                                        .font(.callout.weight(.medium))
                                    Text(factor.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 2)
                        }

                        Divider()

                        VStack(spacing: 6) {
                            detailRow("Files analyzed", "\(score.filesAnalyzed)", "doc.text.magnifyingglass")
                            detailRow("Files to remove", "\(score.filesToRemove)", "trash")
                            if score.sharedFilesFound > 0 {
                                detailRow("Shared files", "\(score.sharedFilesFound)", "person.2.fill")
                            }
                            if score.systemFilesFound > 0 {
                                detailRow("System files", "\(score.systemFilesFound)", "gearshape.2.fill")
                            }
                            if score.adminFilesFound > 0 {
                                detailRow("Admin files", "\(score.adminFilesFound)", "lock.shield.fill")
                            }
                            if score.backgroundComponentsCount > 0 {
                                detailRow("Background components", "\(score.backgroundComponentsCount)", "arrow.triangle.2.circlepath")
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private func factorTint(_ factor: SafetyFactor) -> Color {
        switch factor.severity.tint {
        case .green: return .green
        case .yellow: return .orange
        case .red: return .red
        }
    }

    private func detailRow(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(.secondary)
            Text(label).font(.callout).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.callout.weight(.medium).monospacedDigit())
        }
    }
}
