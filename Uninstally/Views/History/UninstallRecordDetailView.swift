import SwiftUI

/// Full details for a single uninstall history entry, with the available actions.
struct UninstallRecordDetailView: View {
    let record: UninstallRecord
    let onRestore: (UninstallRecord) -> Void
    let onReveal: (UninstallRecord) -> Void

    @Environment(HistoryStore.self) private var history
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            Form {
                LabeledContent("Developer", value: record.developer.isEmpty ? "—" : record.developer)
                LabeledContent("Version", value: record.version.isEmpty ? "—" : record.version)
                LabeledContent("Bundle Identifier", value: record.bundleIdentifier.isEmpty ? "—" : record.bundleIdentifier)
                LabeledContent("Original Location", value: record.originalLocation)
                LabeledContent("Uninstalled") {
                    Text(record.dateUninstalled.formatted(date: .long, time: .shortened))
                }
                LabeledContent("Files Removed", value: "\(record.filesRemoved)")
                LabeledContent("Storage Recovered", value: Format.bytes(Int64(record.storageRecovered)))
                LabeledContent("Deletion Method") {
                    DeletionMethodBadge(mode: record.deletionMethod)
                }
            }
            .formStyle(.grouped)

            footer
        }
        .frame(width: 460, height: 480)
    }

    private var header: some View {
        HStack(spacing: 12) {
            RecordIcon(data: record.iconData, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.appName).font(.title3.weight(.semibold))
                Text("Removed \(Format.relativeDate(record.dateUninstalled))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if record.deletionMethod == .trash {
                Button("Restore from Trash", systemImage: "arrow.uturn.backward") {
                    onRestore(record)
                    dismiss()
                }
                .disabled(record.restorableTrashURL == nil)
                .help(record.restorableTrashURL == nil ? "No longer in the Trash" : "Move the app back to its original location")
            }
            Button("Reveal Location", systemImage: "folder") { onReveal(record) }
            Spacer()
            Button("Remove From History", systemImage: "clock.badge.xmark", role: .destructive) {
                history.remove(record)
                dismiss()
            }
        }
        .padding(16)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
