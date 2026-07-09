import SwiftUI

/// The application "hero" header shown at the top of the uninstall review screen:
/// a large icon, identity, a metadata grid and the reclaim badge.
struct AppHeaderView: View {
    let app: AppInfo
    let reclaimBytes: Int64
    let itemCount: Int

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                AppIconView(url: app.url, size: 96)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.largeTitle.weight(.bold))
                        .lineLimit(2)
                    if !app.developer.isEmpty {
                        Text(app.developer)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    if app.isBrokenInstall {
                        Label("This install appears to be broken or incomplete",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
                ReclaimBadge(bytes: reclaimBytes, count: itemCount)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                StatTile(title: "Version", value: app.displayVersion, systemImage: "number")
                StatTile(title: "Size", value: Format.bytes(app.sizeBytes), systemImage: "internaldrive")
                StatTile(title: "Installed", value: Format.date(app.installDate), systemImage: "calendar")
                StatTile(title: "Last Used", value: Format.relativeDate(app.lastUsedDate), systemImage: "clock")
                StatTile(title: "Identifier",
                         value: app.bundleIdentifier.isEmpty ? "—" : app.bundleIdentifier,
                         systemImage: "barcode")
                StatTile(title: "Location", value: app.location, systemImage: "folder")
                if let volume = app.volumeName {
                    StatTile(title: "Volume", value: volume, systemImage: "externaldrive")
                }
            }
        }
    }
}
