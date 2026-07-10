import Foundation

/// Parses inbound selections from Finder into a list of supported bundle URLs
/// (`.app`, `.component`, `.vst`, `.vst3`, `.aaxplugin`, `.clap`).
///
/// Handles both the custom `uninstally://uninstall?path=…[&path=…]` scheme emitted
/// by the Finder extension and direct `file://` URLs (e.g. "Open With").
enum SelectionReceiver {
    static func appBundleURLs(from url: URL) -> [URL] {
        if url.isFileURL {
            return LibraryPaths.isSupportedBundle(url) ? [url.standardizedFileURL] : []
        }
        guard url.scheme == "uninstally",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return []
        }
        return components.queryItems?
            .filter { $0.name == "path" }
            .compactMap(\.value)
            .map { URL(fileURLWithPath: $0) }
            .filter { LibraryPaths.isSupportedBundle($0) } ?? []
    }

    static func appBundleURLs(from urls: [URL]) -> [URL] {
        urls.flatMap { appBundleURLs(from: $0) }
    }
}
