import SwiftUI

/// The completion screen: a spring-animated green checkmark, the reclaimed
/// storage, item count and elapsed time, plus a Done action. If any items failed
/// to remove, they are listed for transparency.
struct CompletionView: View {
    let result: UninstallResult
    let isDedicated: Bool
    let onDone: () -> Void

    @State private var checkScale: CGFloat = 0.2
    @State private var checkOpacity: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: result.succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(result.succeeded ? .green : .orange)
                    .scaleEffect(checkScale)
                    .opacity(checkOpacity)
            }

            VStack(spacing: 6) {
                Text(result.succeeded ? "Successfully Removed" : "Removed with Issues")
                    .font(.title.weight(.semibold))
                Text(result.appName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                stat(value: Format.bytes(result.reclaimedBytes), label: "Reclaimed", systemImage: "internaldrive.fill")
                Divider().frame(height: 46)
                stat(value: "\(result.removedFileCount)", label: "Files Removed", systemImage: "doc.on.doc.fill")
                Divider().frame(height: 46)
                stat(value: Format.duration(result.duration), label: "Time Taken", systemImage: "clock.fill")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !result.failures.isEmpty {
                failureList
            }

            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent).controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)

            if isDedicated {
                Text("This window will close automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                checkScale = 1
                checkOpacity = 1
            }
        }
    }

    private func stat(value: String, label: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage).foregroundStyle(Color.accentColor)
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minWidth: 100)
    }

    private var failureList: some View {
        GlassCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("\(result.failures.count) items could not be removed",
                      systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
                ForEach(result.failures) { failure in
                    Text(failure.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: 380, alignment: .leading)
        }
    }
}
