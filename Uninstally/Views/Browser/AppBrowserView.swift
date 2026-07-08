import SwiftUI

/// The application browser detail pane. Presents installed apps as a grid or list,
/// with search, sort, multi-select batch uninstall and drag-and-drop support.
struct AppBrowserView: View {
    let filter: SmartFilter
    @Environment(AppCoordinator.self) private var coordinator
    @State private var isSelecting = false

    private var model: AppBrowserModel { coordinator.browserModel }

    var body: some View {
        @Bindable var model = coordinator.browserModel

        Group {
            if model.isScanning && model.apps.isEmpty {
                loadingState
            } else if model.visibleApps.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle(filter.rawValue)
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search applications")
        .onAppear { model.filter = filter }
        .onChange(of: filter) { _, newValue in
            model.filter = newValue
            model.selection.removeAll()
        }
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) {
            if isSelecting && !model.selection.isEmpty {
                batchBar
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            handleDrop(urls)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch model.layout {
        case .grid: grid
        case .list: list
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 18)],
                spacing: 18
            ) {
                ForEach(model.visibleApps) { app in
                    AppGridCell(
                        app: app,
                        isSelecting: isSelecting,
                        isSelected: model.selection.contains(app.id)
                    )
                    .onTapGesture { handleTap(app) }
                }
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
    }

    private var list: some View {
        List {
            ForEach(model.visibleApps) { app in
                AppListRow(
                    app: app,
                    isSelecting: isSelecting,
                    isSelected: model.selection.contains(app.id)
                )
                .contentShape(Rectangle())
                .onTapGesture { handleTap(app) }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Scanning your applications…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Applications", systemImage: filter.systemImage)
        } description: {
            Text(model.searchText.isEmpty
                 ? "Nothing matches this filter."
                 : "No applications match “\(model.searchText)”.")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(.spring) {
                    isSelecting.toggle()
                    if !isSelecting { model.selection.removeAll() }
                }
            } label: {
                Label(isSelecting ? "Done" : "Select", systemImage: "checklist")
            }
            .help("Select multiple applications to uninstall together")
        }

        ToolbarItem(placement: .primaryAction) {
            Picker("Layout", selection: Binding(
                get: { model.layout },
                set: { model.layout = $0 }
            )) {
                ForEach(BrowserLayout.allCases) { layout in
                    Image(systemName: layout.systemImage).tag(layout)
                }
            }
            .pickerStyle(.segmented)
            .help("Switch between grid and list")
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Sort By", selection: Binding(
                    get: { model.sort },
                    set: { model.sort = $0 }
                )) {
                    ForEach(AppSortOption.allCases) { option in
                        Label(option.rawValue, systemImage: option.systemImage).tag(option)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .help("Change the sort order")
        }
    }

    private var batchBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "trash.fill")
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(model.selection.count) selected")
                    .font(.headline)
                Text("About \(Format.bytes(model.selectedSizeBytes)) reclaimable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") {
                withAnimation(.spring) { model.selection.removeAll(); isSelecting = false }
            }
            .buttonStyle(.quiet)
            Button("Uninstall \(model.selection.count)") {
                coordinator.startBatch(for: model.selectedApps)
            }
            .buttonStyle(.destructiveAction)
        }
        .padding(16)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .transition(.move(edge: .bottom))
    }

    // MARK: - Actions

    private func handleTap(_ app: AppInfo) {
        if isSelecting {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if model.selection.contains(app.id) {
                    model.selection.remove(app.id)
                } else {
                    model.selection.insert(app.id)
                }
            }
        } else {
            coordinator.startUninstall(for: app)
        }
    }

    private func handleDrop(_ urls: [URL]) -> Bool {
        guard let bundle = urls.first(where: { $0.pathExtension == "app" }),
              let app = ApplicationScanner().inspect(bundleURL: bundle) else { return false }
        coordinator.startUninstall(for: app)
        return true
    }
}
