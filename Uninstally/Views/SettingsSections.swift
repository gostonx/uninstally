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
    @AppStorage(AppSettings.hapticsEnabledKey) private var haptics = true
    @State private var didReset = false

    var body: some View {
        SettingsCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset All Preferences")
                    Text("Restore Uninstally's settings, sidebar layout and collections to their defaults. Takes effect on next launch.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("Reset") {
                    resetAll()
                    withAnimation { didReset = true }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if didReset {
                RowDivider()
                Label("Preferences reset. Relaunch to see all changes.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .transition(.opacity)
            }
        }
    }

    private func resetAll() {
        let defaults = UserDefaults.standard
        for key in [
            AppSettings.showDockIconKey,
            AppSettings.hapticsEnabledKey,
            AppSettings.uninstallMoveToTrashKey,
            AppSettings.quitAfterFinderKey,
            AppSettings.scanSystemLevelKey,
            AppSettings.autoScanLeftoversKey,
            AppSettings.requireConfirmationKey,
            AppSettings.appSidebarKey,
            AppSettings.appSidebarCollapsedKey,
            AppSettings.customTabsKey,
            AppSettings.updateChannelKey,
            AppSettings.receiveBetaUpdatesKey,
        ] {
            defaults.removeObject(forKey: key)
        }
        haptics = true
    }
}

// MARK: - Updates

/// The Updates section, backed by the Sparkle-powered `UpdateManager`. The actual
/// download / release-notes / install experience is Sparkle's native UI; this
/// screen surfaces status and the user preferences.
private struct UpdatesContent: View {
    @Environment(UpdateManager.self) private var updater

    var body: some View {
        @Bindable var updater = updater

        VStack(spacing: 14) {
            SettingsCard {
                infoRow("Current Version", trailing: Text(updater.currentVersion).foregroundStyle(.secondary))
                RowDivider()
                infoRow("Latest Version", trailing: Text(updater.latestVersion ?? "—").foregroundStyle(.secondary))
                RowDivider()
                infoRow("Last Checked", trailing: Text(lastCheckedText).foregroundStyle(.secondary))
                RowDivider()
                infoRow("Status", trailing: statusView)
            }

            SettingsCard {
                channelRow($updater.channel, betaEnabled: updater.receiveBetaUpdates)
                RowDivider()
                SettingsToggleRow(
                    title: "Automatically Check for Updates",
                    isOn: $updater.automaticallyChecksForUpdates
                )
                RowDivider()
                SettingsToggleRow(
                    title: "Automatically Download Updates",
                    isOn: $updater.automaticallyDownloadsUpdates
                )
                RowDivider()
                SettingsToggleRow(
                    title: "Receive Beta Updates",
                    subtitle: "Include pre-release builds from the selected channel.",
                    isOn: $updater.receiveBetaUpdates
                )
            }

            SettingsCard {
                HStack(spacing: 10) {
                    Button {
                        updater.checkForUpdates()
                    } label: {
                        Label("Check Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(updater.status == .checking)

                    Spacer()

                    Button("Clear Ignored Version") { updater.clearIgnoredVersion() }
                        .controlSize(.small)
                    Button("Reset Update Preferences") { updater.resetUpdatePreferences() }
                        .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    private var lastCheckedText: String {
        guard let date = updater.lastChecked else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func infoRow(_ title: String, trailing: some View) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func channelRow(_ selection: Binding<UpdateChannel>, betaEnabled: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Update Channel")
                if !betaEnabled {
                    Text("Enable beta updates to choose a pre-release channel.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Picker("Update Channel", selection: selection) {
                ForEach(UpdateChannel.allCases) { channel in
                    Text(channel.title).tag(channel)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .disabled(!betaEnabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var statusView: some View {
        switch updater.status {
        case .idle:
            Text("Not checked yet").foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…") }
        case .upToDate:
            Label("You're up to date", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .updateAvailable(let version):
            Label("Update available: \(version)", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(Color.accentColor)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
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
