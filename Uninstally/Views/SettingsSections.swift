import SwiftUI

// MARK: - Section card shell

/// A single section on the Settings page: a header (icon badge, title, subtitle)
/// followed by the section's content in a translucent rounded card.
struct SettingsSectionCard: View {
    let section: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill((section.accentsRed ? Color.red : Color.accentColor).gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: section.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(section.title)
                    .font(.title2.weight(.bold))
                Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .general: GeneralContent()
        case .updates: UpdatesContent()
        case .appearance: AppearanceContent()
        case .uninstall: UninstallContent()
        case .scanning: ScanningContent()
        case .security: SecurityContent()
        case .advanced: AdvancedContent()
        case .about: AboutContent()
        }
    }
}

// MARK: - Reusable rows

/// A full-width toggle row with an optional subtitle, styled for the settings card.
struct SettingsToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    var disabled = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(disabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// A card container that stacks rows with hairline dividers.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        GlassCard(cornerRadius: 12, padding: 0) {
            VStack(spacing: 0) { content }
        }
    }
}

private struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 14) }
}

// MARK: - General

private struct GeneralContent: View {
    @AppStorage(AppSettings.hapticsEnabledKey) private var haptics = true

    var body: some View {
        SettingsCard {
            SettingsToggleRow(
                title: "Haptic Feedback",
                subtitle: "Subtle trackpad feedback for selections, section changes, list edges and reordering. No effect without a Force Touch trackpad.",
                isOn: $haptics
            )
            .onChange(of: haptics) { _, on in if on { HapticManager.shared.itemSelected() } }
        }
    }
}

// MARK: - Appearance

private struct AppearanceContent: View {
    @AppStorage(AppSettings.showDockIconKey) private var showDockIcon = false

    var body: some View {
        SettingsCard {
            SettingsToggleRow(
                title: "Show icon in Dock",
                subtitle: "When off, Uninstally runs as a lightweight accessory with no Dock or menu-bar presence.",
                isOn: $showDockIcon
            )
            .onChange(of: showDockIcon) { _, newValue in
                DockIconController.apply(showDockIcon: newValue)
            }
        }
    }
}

// MARK: - Uninstall Settings

private struct UninstallContent: View {
    @AppStorage(AppSettings.uninstallMoveToTrashKey) private var moveToTrash = true
    @AppStorage(AppSettings.quitAfterFinderKey) private var quitAfterFinder = true

    var body: some View {
        SettingsCard {
            SettingsToggleRow(
                title: "Move removed files to the Trash",
                subtitle: "User-level files are recoverable from the Trash. System files always require administrator approval.",
                isOn: $moveToTrash
            )
            RowDivider()
            SettingsToggleRow(
                title: "Quit after a Finder uninstall",
                subtitle: "Automatically close Uninstally once a right-click uninstall finishes.",
                isOn: $quitAfterFinder
            )
        }
    }
}

// MARK: - Scanning

private struct ScanningContent: View {
    @AppStorage(AppSettings.scanSystemLevelKey) private var scanSystem = true
    @AppStorage(AppSettings.autoScanLeftoversKey) private var autoScan = true

    var body: some View {
        SettingsCard {
            SettingsToggleRow(
                title: "Include system-level files",
                subtitle: "Also search /Library locations. Removing these requires an administrator password.",
                isOn: $scanSystem
            )
            RowDivider()
            SettingsToggleRow(
                title: "Scan for leftovers automatically",
                subtitle: "Look for orphaned files from removed apps in the background.",
                isOn: $autoScan
            )
        }
    }
}

// MARK: - Security

private struct SecurityContent: View {
    @AppStorage(AppSettings.requireConfirmationKey) private var requireConfirmation = true

    var body: some View {
        SettingsCard {
            SettingsToggleRow(
                title: "Require confirmation before deleting",
                subtitle: "Always show a summary and warning before anything is removed.",
                isOn: $requireConfirmation
            )
            RowDivider()
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verified update source")
                    Text("Updates are only downloaded from the official Uninstally repository on GitHub and verified before installation.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Advanced

private struct AdvancedContent: View {
    @Environment(SidebarManager.self) private var sidebar
    @State private var didReset = false

    var body: some View {
        SettingsCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset Sidebar Layout")
                    Text("Restore the default section order and visibility.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("Reset") {
                    sidebar.reset()
                    withAnimation { didReset = true }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if didReset {
                RowDivider()
                Label("Sidebar restored to defaults.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Updates

private struct UpdatesContent: View {
    private enum Status: Equatable {
        case idle, checking, upToDate, available(String, URL), failed(String)
    }

    @State private var status: Status = .idle
    @State private var lastChecked: Date?

    private static let api = URL(string: "https://api.github.com/repos/gostonx/uninstally/releases/latest")!
    private static let releasesPage = URL(string: "https://github.com/gostonx/uninstally/releases/latest")!

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        SettingsCard {
            infoRow(title: "Current Version", trailing: Text(currentVersion).foregroundStyle(.secondary))
            RowDivider()
            infoRow(title: "Status", trailing: statusView)
            if let lastChecked {
                RowDivider()
                infoRow(
                    title: "Last Checked",
                    trailing: Text(lastChecked.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                )
            }
            RowDivider()
            HStack(spacing: 10) {
                Button {
                    Task { await check() }
                } label: {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(status == .checking)
                Link(destination: Self.releasesPage) {
                    Label("Releases", systemImage: "arrow.up.right.square")
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func infoRow(title: String, trailing: some View) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .idle:
            Text("Not checked yet").foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…") }
        case .upToDate:
            Label("You're up to date", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .available(let version, let url):
            Link(destination: url) {
                Label("Update available: \(version)", systemImage: "arrow.down.circle.fill")
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }

    private func check() async {
        status = .checking
        defer { lastChecked = Date() }
        do {
            var request = URLRequest(url: Self.api)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Uninstally", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                status = .failed("Couldn't reach GitHub"); return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let release = try decoder.decode(GitHubRelease.self, from: data)
            guard let latest = SemanticVersion(release.tagName),
                  let current = SemanticVersion(currentVersion) else {
                status = .failed("Couldn't read version"); return
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

private struct AboutContent: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        SettingsCard {
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 84, height: 84)
                    .accessibilityHidden(true)
                Text("uninstally")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text(version).font(.callout).foregroundStyle(.secondary)
                Text("A native macOS uninstaller by Codenta.")
                    .font(.callout).foregroundStyle(.secondary)
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
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }
}
