import SwiftUI

/// The final safety confirmation, presented as a focused modal card over a dimmed
/// backdrop. Surfaces the icon, name, reclaimable storage and file count, and the
/// irreversible-action warning before the engine runs.
struct SafetyConfirmView: View {
    let app: AppInfo
    let plan: UninstallPlan
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var appeared = false

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
                        Text("Uninstally will remove the application and all of its associated files.")
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

                    Label("This action cannot be undone.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.orange.opacity(0.12), in: Capsule())

                    HStack(spacing: 12) {
                        Button("Cancel", action: onCancel)
                            .buttonStyle(.quiet)
                            .keyboardShortcut(.cancelAction)
                        Button("Uninstall", action: onConfirm)
                            .buttonStyle(.destructiveAction)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .frame(width: 380)
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
