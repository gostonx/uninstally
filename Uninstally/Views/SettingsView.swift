import SwiftUI

/// The app's preferences window (⌘, or the gear in the browser). Currently hosts
/// the Dock-icon visibility toggle; structured as a `Form` so future settings drop
/// in cleanly.
struct SettingsView: View {
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
                Text("Appearance")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: showDockIcon) { _, newValue in
            DockIconController.apply(showDockIcon: newValue)
        }
    }
}
