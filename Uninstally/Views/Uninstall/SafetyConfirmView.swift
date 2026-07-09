import SwiftUI

/// The final safety confirmation, presented as a focused modal card over a dimmed
/// backdrop. Surfaces the icon, name, reclaimable storage and file count, and the
/// irreversible-action warning before the engine runs.
struct SafetyConfirmView: View {
    let app: AppInfo
    let plan: UninstallPlan
    let mode: DeletionMode
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var appeared = false

    /// A plain-language summary of what will happen, e.g. "Uninstally will move
    /// this app and 37 related files to Trash."
    private var behaviorSummary: String {
        let count = plan.selectedCount
        let items = count == 1 ? "1 item" : "\(count) items"
        switch mode {
        case .trash:
            return "Uninstally will move this app and \(items) to the Trash."
        case .permanent:
            return "Uninstally will permanently delete this app and \(items)."
        }
    }

    private var warning: (text: String, icon: String) {
        switch mode {
        case .trash:
            return ("App and related files will be moved to Trash. You can restore them until Trash is emptied.", "arrow.uturn.backward.circle.fill")
        case .permanent:
            return ("This will permanently delete the application and associated files. This action cannot be undone.", "exclamationmark.triangle.fill")
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            GlassCard(cornerRadius: 22, material: .thickMaterial, padding: 28) {
                VStack(spacing: 18) {
                    AppIconView(url: app.url, size: 84)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    VStack(spacing: 6) {
                        Text("Uninstall \(app.name)?")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(behaviorSummary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 0) {
                        summaryColumn(
                            value: Format.bytes(plan.reclaimableBytes),
                            label: "Reclaimed",
                            systemImage: "internaldrive.fill"
                        )
                        Divider().frame(height: 40)
                        summaryColumn(
                            value: "\(plan.selectedCount)",
                            label: "Items",
                            systemImage: "doc.on.doc.fill"
                        )
                        if plan.requiresAdmin {
                            Divider().frame(height: 40)
                            summaryColumn(
                                value: "Admin",
                                label: "Required",
                                systemImage: "lock.fill"
                            )
                        }
                    }
                    .padding(.vertical, 6)

                    Label(warning.text, systemImage: warning.icon)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(mode == .permanent ? .red : .orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background((mode == .permanent ? Color.red : Color.orange).opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    HStack(spacing: 12) {
                        Button("Cancel", action: onCancel)
                            .buttonStyle(.bordered).controlSize(.large)
                            .keyboardShortcut(.cancelAction)
                        Button(mode.confirmTitle, action: onConfirm)
                            .buttonStyle(.borderedProminent)
                            .tint(mode == .permanent ? .red : .accentColor)
                            .controlSize(.large)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .frame(width: 400)
            }
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { appeared = true }
        }
    }

    private func summaryColumn(value: String, label: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
