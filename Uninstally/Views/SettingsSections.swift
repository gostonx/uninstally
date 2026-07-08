import SwiftUI

// MARK: - General

/// General preferences, including the haptic-feedback toggle.
struct GeneralSettingsView: View {
    @AppStorage(AppSettings.hapticsEnabledKey) private var hapticsEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $hapticsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Haptic Feedback")
                        Text("Subtle trackpad feedback when selecting items, changing sections and reaching the edge of a list. Has no effect on hardware without a Force Touch trackpad.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .accessibilityHint("Turns trackpad haptic feedback on or off")
                .onChange(of: hapticsEnabled) { _, isOn in
                    if isOn { HapticManager.shared.itemSelected() }
                }
            } header: {
                Text("Feedback")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

// MARK: - Appearance

/// Appearance preferences: Dock-icon visibility.
struct AppearanceSettingsView: View {
    @AppStorage(AppSettings.showDockIconKey) private var showDockIcon = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $showDockIcon) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show icon in Dock")
                        Text("When off, Uninstally runs as a lightweight accessory with no Dock or menu-bar presence.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .accessibilityHint("Shows or hides the Uninstally icon in the Dock")
            } header: {
                Text("Dock")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
        .onChange(of: showDockIcon) { _, newValue in
            DockIconController.apply(showDockIcon: newValue)
        }
    }
}

// MARK: - Advanced

/// Advanced preferences: restore the Settings customisation.
struct AdvancedSettingsView: View {
    @Environment(TabManager.self) private var tabManager
    @State private var didReset = false

    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Settings Layout")
                        Text("Restore the default tab order, names and visibility.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset") {
                        tabManager.reset()
                        withAnimation { didReset = true }
                    }
                }
                if didReset {
                    Label("Settings layout restored to defaults.", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            } header: {
                Text("Customization")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Advanced")
    }
}

// MARK: - Updates

/// A lightweight update check against the official GitHub repository. Uses the
/// shared `GitHubRelease` / `SemanticVersion` models; heavier download/install
/// logic lives in the dedicated update pipeline.
struct UpdatesSettingsView: View {
    private enum Status: Equatable {
        case idle, checking, upToDate, available(String, URL), failed(String)
    }

    @State private var status: Status = .idle
    @State private var lastChecked: Date?

    private static let repoAPI = URL(string: "https://api.github.com/repos/gostonx/uninstally/releases/latest")!
    private static let releasesPage = URL(string: "https://github.com/gostonx/uninstally/releases/latest")!

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Current Version", value: currentVersion)
                statusRow
                if let lastChecked {
                    LabeledContent("Last Checked", value: lastChecked.formatted(date: .abbreviated, time: .shortened))
                }
            } header: {
                Text("Software Update")
            }

            Section {
                Button {
                    Task { await check() }
                } label: {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(status == .checking)
                Link(destination: Self.releasesPage) {
                    Label("View Releases on GitHub", systemImage: "arrow.up.right.square")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Updates")
    }

    @ViewBuilder
    private var statusRow: some View {
        switch status {
        case .idle:
            LabeledContent("Status", value: "Not checked yet")
        case .checking:
            LabeledContent("Status") {
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…") }
            }
        case .upToDate:
            LabeledContent("Status") {
                Label("You're up to date", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        case .available(let version, let url):
            LabeledContent("Status") {
                Link(destination: url) {
                    Label("Update available: \(version)", systemImage: "arrow.down.circle.fill")
                }
            }
        case .failed(let message):
            LabeledContent("Status") {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func check() async {
        status = .checking
        defer { lastChecked = Date() }
        do {
            var request = URLRequest(url: Self.repoAPI)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Uninstally", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                status = .failed("Couldn't reach GitHub")
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let release = try decoder.decode(GitHubRelease.self, from: data)
            guard let latest = SemanticVersion(release.tagName),
                  let current = SemanticVersion(currentVersion) else {
                status = .failed("Couldn't read version")
                return
            }
            if latest > current {
                status = .available(release.tagName, release.htmlURL)
                HapticManager.shared.itemSelected()
            } else {
                status = .upToDate
            }
        } catch {
            status = .failed("Check failed")
        }
    }
}

// MARK: - About

/// About screen with the app identity and Codenta links.
struct AboutSettingsView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("uninstally")
                .font(.system(.title, design: .rounded).weight(.bold))
            Text(version)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("A native macOS uninstaller by Codenta.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Link(destination: URL(string: "https://codenta.us/")!) {
                    Label("Website", systemImage: "safari")
                }
                Link(destination: URL(string: "https://github.com/gostonx/uninstally")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)

            Spacer()
            Text("© 2026 Codenta")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .navigationTitle("About")
    }
}
