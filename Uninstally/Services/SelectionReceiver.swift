import Foundation

/// Parses inbound selections from Finder into a list of `.app` bundle URLs.
///
/// Handles both the custom `uninstally://uninstall?path=…[&path=…]` scheme emitted
/// by the Finder extension and direct `file://` URLs (e.g. "Open With").
enum SelectionReceiver {
    static func appBundleURLs(from url: URL) -> [URL] {
        if url.isFileURL {
            return url.pathExtension == "app" ? [url.standardizedFileURL] : []
        }
        guard url.scheme == "uninstally",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return []
        }
        return components.queryItems?
            .filter { $0.name == "path" }
            .compactMap(\.value)
            .map { URL(fileURLWithPath: $0) }
            .filter { $0.pathExtension == "app" } ?? []
    }

    static func appBundleURLs(from urls: [URL]) -> [URL] {
        urls.flatMap { appBundleURLs(from: $0) }
    }
}
