import SwiftUI
import Charts

/// Shared chart and visual components for Storage Insights.
enum StorageCharts {

    // MARK: - Storage Usage Bar

    /// A macOS-style horizontal storage bar showing used vs available space,
    /// matching the look of System Settings → General → Storage.
    struct StorageUsageBar: View {
        let total: Int64
        let used: Int64
        let available: Int64

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Storage")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("\(Format.bytes(total)) Total")
                        .font(.callout).foregroundStyle(.secondary)
                }

                GeometryReader { geo in
                    let totalD = Double(total)
                    let usedFrac = totalD > 0 ? Double(used) / totalD : 0
                    let availableFrac = totalD > 0 ? Double(available) / totalD : 0
                    let barWidth = max(geo.size.width, 1)
                    let usedWidth = barWidth * usedFrac
                    let availableWidth = barWidth * availableFrac

                    HStack(spacing: 3) {
                        if usedWidth > 0 {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.accentColor.gradient)
                                .frame(width: max(usedWidth, 4))
                        }
                        if availableWidth > 0 {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: max(availableWidth, 4))
                        }
                    }
                    .animation(.easeInOut(duration: 0.5), value: usedWidth)
                }
                .frame(height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                HStack(spacing: 20) {
                    legendDot(Color.accentColor)
                    Text("\(Format.bytes(used)) Used").font(.callout)
                    Spacer()
                    legendDot(Color.secondary.opacity(0.45))
                    Text("\(Format.bytes(available)) Available").font(.callout)
                }
                .font(.caption)
            }
        }

        private func legendDot(_ color: Color) -> some View {
            Circle().fill(color).frame(width: 8, height: 8)
        }
    }

    // MARK: - Storage by Category (Donut Chart)

    struct StorageByCategory: View {
        let slices: [StorageStatistics.CategorySlice]

        var body: some View {
            ChartCard(title: "Storage by Category", systemImage: "chart.pie.fill") {
                if slices.isEmpty {
                    EmptyChart()
                } else {
                    Chart(slices) { slice in
                        SectorMark(
                            angle: .value("Size", slice.bytes),
                            innerRadius: .ratio(0.58),
                            angularInset: 1.5
                        )
                        .cornerRadius(3)
                        .foregroundStyle(by: .value("Category", slice.category))
                    }
                    .chartLegend(position: .trailing, alignment: .center)
                }
            }
        }
    }

    // MARK: - Storage Category Breakdown List

    struct CategoryBreakdownList: View {
        let items: [StorageStatistics.StorageCategoryBreakdown]

        var body: some View {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: item.category))
                            .foregroundStyle(color(for: item.category))
                            .frame(width: 22)
                        Text(item.category)
                            .font(.callout)
                        Spacer()
                        Text(Format.bytes(item.bytes))
                            .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", item.percentage))
                            .font(.caption).foregroundStyle(.tertiary).frame(width: 44, alignment: .trailing)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    if item.id != items.last?.id { Divider().padding(.leading, 46) }
                }
                if items.isEmpty {
                    Text("No data yet").font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                }
            }
        }

        private func icon(for cat: String) -> String {
            switch cat {
            case "Applications": return "app.fill"
            case "Application Support": return "folder.fill"
            case "Caches": return "tray.full.fill"
            case "Containers": return "shippingbox.fill"
            case "Preferences": return "gearshape.fill"
            case "Logs": return "list.clipboard.fill"
            default: return "doc.fill"
            }
        }

        private func color(for cat: String) -> Color {
            switch cat {
            case "Applications": return .blue
            case "Application Support": return .purple
            case "Caches": return .orange
            case "Containers": return .green
            case "Preferences": return .gray
            case "Logs": return .teal
            default: return .secondary
            }
        }
    }

    // MARK: - Card wrapper

    struct ChartCard<Content: View>: View {
        let title: String
        let systemImage: String
        @ViewBuilder var content: Content

        var body: some View {
            GlassCard(cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                    content
                        .frame(minHeight: 180)
                }
            }
        }
    }

    // MARK: - Empty state

    private struct EmptyChart: View {
        var message = "No data yet"
        var body: some View {
            VStack {
                Spacer()
                Text(message).font(.callout).foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}
