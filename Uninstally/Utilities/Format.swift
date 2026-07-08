import Foundation

/// Centralised, cached formatters. Creating `Formatter` instances is relatively
/// expensive, so we reuse a small set of configured singletons.
enum Format {
    /// Formats a byte count using the file-system convention (e.g. "1.2 GB").
    static func bytes(_ value: Int64) -> String {
        byteFormatter.string(fromByteCount: max(0, value))
    }

    /// A compact, relative description of a date (e.g. "3 days ago"). Returns
    /// "Unknown" when the date is missing.
    static func relativeDate(_ date: Date?) -> String {
        guard let date else { return "Unknown" }
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// An absolute medium-style date (e.g. "7 Jul 2026").
    static func date(_ date: Date?) -> String {
        guard let date else { return "Unknown" }
        return dateFormatter.string(from: date)
    }

    /// Formats a duration in seconds into a friendly string (e.g. "4.2s", "1m 3s").
    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 1 { return String(format: "%.0f ms", seconds * 1000) }
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let minutes = Int(seconds) / 60
        let remainder = Int(seconds) % 60
        return "\(minutes)m \(remainder)s"
    }

    /// Formats an estimated time remaining, tolerating `nil`.
    static func eta(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds > 0 else { return "—" }
        return duration(seconds)
    }

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
