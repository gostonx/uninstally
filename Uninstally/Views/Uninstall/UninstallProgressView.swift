import SwiftUI

/// Live progress screen: an animated ring, the current file, percentage complete,
/// counts and an ETA. Driven purely by the streamed `UninstallProgress`.
struct UninstallProgressView: View {
    let app: AppInfo
    let progress: UninstallProgress?
    var onCancel: () -> Void = {}

    private var fraction: Double { progress?.fractionCompleted ?? 0 }

    var body: some View {
        VStack(spacing: 26) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        AngularGradient(
                            colors: [.accentColor, .accentColor.opacity(0.6), .accentColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: fraction)
                VStack(spacing: 2) {
                    Text("\(Int(fraction * 100))")
                        .font(.system(size: 40, weight: .semibold))
                        .contentTransition(.numericText())
                        .monospacedDigit()
                    Text("percent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)

            VStack(spacing: 6) {
                Text("Removing \(app.name)")
                    .font(.title2.weight(.semibold))
                Text(progress?.currentPath ?? "Preparing…")
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 420)
                    .animation(.default, value: progress?.currentPath)
            }

            HStack(spacing: 26) {
                metric(value: "\(progress?.completedCount ?? 0)/\(progress?.totalCount ?? 0)",
                       label: "Items")
                metric(value: Format.bytes(progress?.bytesRemoved ?? 0), label: "Removed")
                metric(value: Format.eta(progress?.estimatedTimeRemaining), label: "Remaining")
            }

            Button("Cancel", action: onCancel)
                .controlSize(.large)
                .padding(.top, 12)
                .keyboardShortcut(.cancelAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Removing \(app.name), \(Int(fraction * 100)) percent complete")
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }
}
