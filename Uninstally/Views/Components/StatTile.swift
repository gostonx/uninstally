import SwiftUI

/// A compact key/value tile used in the application header to present metadata
/// (version, size, install date, …) in a consistent, legible grid.
struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A prominent "reclaimable storage" badge with a gradient fill.
struct ReclaimBadge: View {
    let bytes: Int64
    var count: Int?

    var body: some View {
        VStack(spacing: 2) {
            Text(Format.bytes(bytes))
                .font(.system(.title, design: .rounded).weight(.bold))
                .contentTransition(.numericText())
            Text(count.map { "\($0) items • reclaimable" } ?? "reclaimable")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.22), Color.accentColor.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Format.bytes(bytes)) reclaimable")
    }
}
