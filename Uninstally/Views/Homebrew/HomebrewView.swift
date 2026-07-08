import SwiftUI

/// The Homebrew manager: lists installed packages, shows dependency information on
/// demand, and uninstalls with optional leftover removal (`brew uninstall --zap`).
struct HomebrewView: View {
    @State private var model = HomebrewModel()
    @State private var confirming: HomebrewPackage?

    var body: some View {
        @Bindable var model = model
        return Group {
            if !model.isInstalled && !model.isLoading {
                notInstalled
            } else if model.isLoading {
                loading
            } else {
                list
            }
        }
        .navigationTitle("Homebrew")
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search packages")
        .task { await model.load() }
        .sheet(item: $confirming) { package in
            HomebrewConfirmSheet(model: model, package: package)
        }
    }

    private var notInstalled: some View {
        ContentUnavailableView {
            Label("Homebrew Not Found", systemImage: "mug")
        } description: {
            Text("Install Homebrew from brew.sh to manage command-line packages and casks here.")
        }
    }

    private var loading: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text("Reading Homebrew packages…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(model.filteredPackages) { package in
                    GlassCard(cornerRadius: 12, padding: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: package.systemImage)
                                .font(.title3)
                                .foregroundStyle(package.isCask ? Color.accentColor : .orange)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(package.name).font(.body.weight(.medium))
                                Text("\(package.kindLabel) • \(package.version.isEmpty ? "—" : package.version)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.busyPackage == package.name {
                                ProgressView().controlSize(.small)
                            } else {
                                Button("Uninstall") { confirming = package }
                                    .buttonStyle(.quiet)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .scrollContentBackground(.hidden)
    }
}

/// Confirmation sheet that resolves and displays dependency information before
/// removing a Homebrew package.
private struct HomebrewConfirmSheet: View {
    let model: HomebrewModel
    let package: HomebrewPackage

    @Environment(\.dismiss) private var dismiss
    @State private var dependencies: [String] = []
    @State private var dependents: [String] = []
    @State private var removeLeftovers = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: package.systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading) {
                    Text("Uninstall \(package.name)").font(.title2.weight(.bold))
                    Text(package.kindLabel).foregroundStyle(.secondary)
                }
            }

            if isLoading {
                HStack { ProgressView().controlSize(.small); Text("Resolving dependencies…") }
                    .foregroundStyle(.secondary)
            } else {
                if !dependents.isEmpty {
                    dependencyBlock(
                        title: "Required by (will break):",
                        items: dependents,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                }
                if !dependencies.isEmpty {
                    dependencyBlock(
                        title: "Depends on:",
                        items: dependencies,
                        systemImage: "arrow.down.right",
                        tint: .secondary
                    )
                }
                if dependents.isEmpty && dependencies.isEmpty {
                    Text("No dependency relationships detected.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            Toggle("Also remove configuration & leftover files (--zap)", isOn: $removeLeftovers)

            if let errorMessage {
                Label(errorMessage, systemImage: "xmark.octagon.fill")
                    .font(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.quiet)
                    .keyboardShortcut(.cancelAction)
                Button("Uninstall") {
                    Task {
                        if let error = await model.uninstall(package, removeLeftovers: removeLeftovers) {
                            errorMessage = error
                        } else {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.destructiveAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .task {
            async let deps = model.dependencies(of: package)
            async let uses = model.dependents(of: package)
            dependencies = await deps
            dependents = await uses
            isLoading = false
        }
    }

    private func dependencyBlock(title: String, items: [String], systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)
            Text(items.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
