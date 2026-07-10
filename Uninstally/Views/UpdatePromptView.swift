import SwiftUI

struct UpdatePromptView: View {
    let version: String
    let releaseNotesHTML: String?
    let onUpdateNow: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 84, height: 84)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

            VStack(spacing: 6) {
                Text("Update Available")
                    .font(.title.weight(.bold))
                Text("Uninstally \(version) is available to download.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let html = releaseNotesHTML, !html.isEmpty {
                ScrollView {
                    ReleaseNotesView(html: html)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding(.horizontal, 20)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Later") { onLater() }
                    .controlSize(.large)
                Button("Update Now") { onUpdateNow() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 460, height: 420)
        .background(.regularMaterial)
    }
}

private struct ReleaseNotesView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> NSTextView {
        let view = NSTextView()
        view.isEditable = false
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        if let data = html.data(using: .utf8),
           let attributed = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.html],
               documentAttributes: nil
           ) {
            view.textStorage?.setAttributedString(attributed)
        }
        return view
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {}
}
