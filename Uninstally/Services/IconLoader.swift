import AppKit
import SwiftUI

/// Loads and caches application icons off the main actor. Icons are keyed by the
/// bundle path so repeated browser scrolls don't re-hit the disk.
///
/// `NSWorkspace.icon(forFile:)` is main-thread-friendly but decoding large icons
/// can still cause hitches; we therefore render into a fixed-size bitmap once and
/// cache the result.
@MainActor
final class IconLoader {
    static let shared = IconLoader()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 512
    }

    /// Returns a cached icon for the given file URL, loading it if necessary.
    func icon(for url: URL, size: CGFloat = 128) -> NSImage {
        let key = "\(url.path)#\(Int(size))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        cache.setObject(icon, forKey: key)
        return icon
    }

    /// Generic icon for a category, used for leftover artefacts that have no app.
    func icon(for category: RemovalCategory) -> NSImage {
        NSImage(systemSymbolName: category.systemImage, accessibilityDescription: category.title)
            ?? NSImage()
    }
}

/// A SwiftUI view that renders an application's icon, resolving it lazily.
struct AppIconView: View {
    let url: URL
    var size: CGFloat = 64

    var body: some View {
        Image(nsImage: IconLoader.shared.icon(for: url, size: size * 2))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
