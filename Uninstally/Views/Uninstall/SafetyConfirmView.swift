import SwiftUI

/// The final safety confirmation, shown before any deletion. Presents the
/// **Security Summary** — exactly what will be removed, how much storage will be
/// recovered, and any warnings (administrator privileges, shared resources,
/// excluded items) — plus an accurate description of the deletion method.
struct SafetyConfirmView: View {
    let app: AppInfo
    let summary: SecuritySummary
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var appeared = false

    private var mode: DeletionMode { summary.method }

    private var counts: [(String, String)] {
        var rows: [(String, String)] = [
            ("Application", "\(summary.applicationCount)"),
            ("Related Files", "\(summary.relatedCount)"),
            ("Recoverable Storage", Format.bytes(summary.recoverableBytes)),
            ("User Files", "\(summary.userFileCount)"),
        ]
        if summary.adminFileCount > 0 { rows.append(("Administrator Files", "\(summary.adminFileCount)")) }
        if summary.sharedCount > 0 { rows.append(("Shared Components", "\(summary.sharedCount)")) }
        if summary.loginItemCount > 0 { rows.append(("Login Items", "\(summary.loginItemCount)")) }
        if summary.launchAgentCount > 0 { rows.append(("Launch Agents", "\(summary.launchAgentCount)")) }
        if summary.containerCount > 0 { rows.append(("Containers", "\(summary.containerCount)")) }
        if summary.preferenceCount > 0 { rows.append(("Preference Files", "\(summary.preferenceCount)")) }
        rows.append(("Deletion Method", mode.title))
        return rows
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: onCancel)

            GlassCard(cornerRadius: 22, material: .thickMaterial, padding: 24) {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        AppIconView(url: app.url, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Uninstall \(app.name)?").font(.title3.weight(.bold))
                            Text(summary.methodDescription)
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }

                    GroupBox("Security Summary") {
                        VStack(spacing: 0) {
                            ForEach(Array(counts.enumerated()), id: \.offset) { index, row in
                                HStack {
                                    Text(row.0).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(row.1).monospacedDigit()
                                }
                                .font(.callout)
                                .padding(.vertical, 5)
                                if index < counts.count - 1 { Divider() }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if !summary.warnings.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(summary.warnings) { warning in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: warning.systemImage)
                                        .foregroundStyle(color(for: warning.severity))
                                    Text(warning.text).font(.caption)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    HStack(spacing: 12) {
                        Button("Cancel", action: onCancel)
                            .controlSize(.large)
                            .keyboardShortcut(.cancelAction)
                        Button(mode.confirmTitle, action: onConfirm)
                            .buttonStyle(.borderedProminent)
                            .tint(mode == .permanent ? .red : .accentColor)
                            .controlSize(.large)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .frame(width: 430)
            }
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { appeared = true }
        }
    }

    private func color(for severity: SecuritySummary.Warning.Severity) -> Color {
        switch severity {
        case .info: return .secondary
        case .caution: return .orange
        case .danger: return .red
        }
    }
}
