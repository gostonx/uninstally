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
        case .updates: UpdatesContent()
        case .appearance: AppearanceContent()
        case .language: LanguageContent()
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

/// A native grouped container that stacks rows with hairline dividers, matching
/// the grouped sections in System Settings.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        GroupBox {
            VStack(spacing: 0) { content }
                .frame(maxWidth: .infinity)
        }
        .groupBoxStyle(.automatic)
    }
}

private struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 14) }
}

// MARK: - Appearance

private struct AppearanceContent: View {
    @AppStorage(AppSettings.showDockIconKey) private var showDockIcon = true

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

// MARK: - Language

private struct LanguageContent: View {
    @Bindable var manager = LanguageManager.shared

    var body: some View {
        SettingsCard {
            ForEach(LanguageManager.supportedLanguages) { language in
                Button {
                    manager.selectLanguage(language)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .font(.body)
                            .foregroundStyle(Color.accentColor)
                        Text(language.nativeName)
                        Spacer(minLength: 8)
                        if manager.current.code == language.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(language.nativeName)
                .accessibilityAddTraits(manager.current.code == language.code ? .isSelected : [])
            }
        }
        .alert("Restart Required", isPresented: $manager.showRestartAlert) {
            Button("Restart Now") { manager.restartNow() }
            Button("Later", role: .cancel) {}
        } message: {
            Text("The application needs to restart to apply the selected language.")
        }
    }
}

// MARK: - Uninstall Settings

private struct UninstallContent: View {
    @Environment(HistoryStore.self) private var history
    @AppStorage(AppSettings.deletionModeKey) private var deletionModeRaw = DeletionMode.trash.rawValue
    @AppStorage(AppSettings.quitAfterFinderKey) private var quitAfterFinder = true
    @AppStorage(AppSettings.keepHistoryKey) private var keepHistory = true
    @AppStorage(AppSettings.historyRetentionKey) private var retentionRaw = HistoryRetention.forever.rawValue
    @State private var showClearConfirm = false

    private var deletionMode: Binding<DeletionMode> {
        Binding(
            get: { DeletionMode(rawValue: deletionModeRaw) ?? .trash },
            set: { deletionModeRaw = $0.rawValue }
        )
    }

    private var retention: Binding<HistoryRetention> {
        Binding(
            get: { HistoryRetention(rawValue: retentionRaw) ?? .forever },
            set: { retentionRaw = $0.rawValue; history.prune() }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deletion Method")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 2)

            SettingsCard {
                ForEach(Array(DeletionMode.allCases.enumerated()), id: \.element) { index, mode in
                    DeletionModeRow(mode: mode, selection: deletionMode)
                    if index < DeletionMode.allCases.count - 1 { RowDivider() }
                }
            }

            SettingsCard {
                SettingsToggleRow(
                    title: "Quit after a Finder uninstall",
                    subtitle: "Automatically close Uninstally once a right-click uninstall finishes.",
                    isOn: $quitAfterFinder
                )
            }
            .padding(.top, 6)

            Text("Uninstall History")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 2)
                .padding(.top, 8)

            SettingsCard {
                SettingsToggleRow(
                    title: "Keep Uninstall History",
                    subtitle: "Record apps you remove so you can review or restore them from Recently Uninstalled.",
                    isOn: $keepHistory
                )
                RowDivider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("History Retention")
                        Text("Automatically remove entries older than this.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Picker("History Retention", selection: retention) {
                        ForEach(HistoryRetention.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .disabled(!keepHistory)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                RowDivider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear History")
                        Text("Remove every entry from the uninstall history.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button("Clear…", role: .destructive) { showClearConfirm = true }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .confirmationDialog("Clear all uninstall history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { history.clear() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every entry. It does not affect files already in the Trash.")
            }
        }
    }
}

/// A native radio-style row for choosing a `DeletionMode`, with a title, an SF
/// Symbol, a description, and a proper selection ring.
private struct DeletionModeRow: View {
    let mode: DeletionMode
    @Binding var selection: DeletionMode

    private var isSelected: Bool { selection == mode }

    var body: some View {
        Button {
            selection = mode
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.body)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Label(mode.title, systemImage: mode.systemImage)
                        .labelStyle(.titleAndIcon)
                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.title). \(mode.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Scanning

private struct ScanningContent: View {
    @AppStorage(AppSettings.scanSystemLevelKey) private var scanSystem = true
    @AppStorage(AppSettings.autoScanLeftoversKey) private var autoScan = true
    @AppStorage(AppSettings.monitorTrashKey) private var monitorTrash = true

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
            RowDivider()
            SettingsToggleRow(
                title: "Monitor Trash for Deleted Applications",
                subtitle: "When you drag an app to the Trash in Finder, offer to remove its leftover files.",
                isOn: $monitorTrash
            )
            .onChange(of: monitorTrash) { _, _ in
                NotificationCenter.default.post(name: .trashMonitorPreferenceChanged, object: nil)
            }
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
            AppSettings.deletionModeKey,
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
                    .font(.title2).fontWeight(.semibold)
                Text(version).font(.callout).foregroundStyle(.secondary)
                Text("A native macOS uninstaller by Codenta.")
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Link("codenta.us", destination: URL(string: "https://codenta.us/")!)
                    .font(.callout.weight(.medium))
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
