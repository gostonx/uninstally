import Foundation

// MARK: - Semantic Version

/// A minimal, dependency-free semantic-version implementation supporting the
/// `MAJOR.MINOR.PATCH[-prerelease]` subset used by GitHub release tags. Tolerates
/// an optional leading `v` and missing minor/patch components.
struct SemanticVersion: Comparable, Hashable, CustomStringConvertible, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
    /// Dot-separated pre-release identifiers (empty for a normal release).
    let prerelease: [String]

    var isPrerelease: Bool { !prerelease.isEmpty }

    init?(_ raw: String) {
        var string = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("v") || string.hasPrefix("V") { string.removeFirst() }
        guard !string.isEmpty else { return nil }

        // Split off build metadata (ignored) then pre-release.
        string = string.split(separator: "+", maxSplits: 1).first.map(String.init) ?? string
        let coreAndPre = string.split(separator: "-", maxSplits: 1)
        let core = coreAndPre[0]
        self.prerelease = coreAndPre.count > 1
            ? coreAndPre[1].split(separator: ".").map(String.init)
            : []

        let parts = core.split(separator: ".").map { Int($0) }
        guard let first = parts.first, let major = first else { return nil }
        self.major = major
        self.minor = parts.count > 1 ? (parts[1] ?? 0) : 0
        self.patch = parts.count > 2 ? (parts[2] ?? 0) : 0
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        // Per SemVer: a version with a pre-release has lower precedence than the
        // associated normal version.
        switch (lhs.prerelease.isEmpty, rhs.prerelease.isEmpty) {
        case (true, true): return false
        case (true, false): return false   // lhs normal > rhs prerelease
        case (false, true): return true    // lhs prerelease < rhs normal
        case (false, false): break
        }

        for (l, r) in zip(lhs.prerelease, rhs.prerelease) where l != r {
            switch (Int(l), Int(r)) {
            case let (li?, ri?): return li < ri
            case (_?, nil): return true         // numeric < alphanumeric
            case (nil, _?): return false
            default: return l < r
            }
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }

    var description: String {
        let core = "\(major).\(minor).\(patch)"
        return prerelease.isEmpty ? core : core + "-" + prerelease.joined(separator: ".")
    }
}

// MARK: - GitHub Releases API

/// A release as returned by `GET /repos/{owner}/{repo}/releases`.
struct GitHubRelease: Codable, Sendable {
    let tagName: String
    let name: String?
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let htmlURL: URL
    let publishedAt: Date?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case draft
        case prerelease
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

/// A downloadable asset attached to a release.
struct GitHubAsset: Codable, Sendable {
    let name: String
    let browserDownloadURL: URL
    let size: Int
    let contentType: String?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
        case contentType = "content_type"
    }
}

// MARK: - Update domain models

/// A resolved, actionable update: a newer release plus its validated DMG asset.
struct UpdateInfo: Identifiable, Sendable {
    var id: String { tag }
    let version: SemanticVersion
    let tag: String
    let name: String
    let releaseNotes: String
    let htmlURL: URL
    let dmgURL: URL
    let dmgSize: Int
    let isPrerelease: Bool
    let publishedAt: Date?
}

/// Live download progress.
struct DownloadProgress: Sendable {
    var bytesReceived: Int64
    var totalBytes: Int64

    var fraction: Double {
        totalBytes > 0 ? min(Double(bytesReceived) / Double(totalBytes), 1) : 0
    }
}

/// Errors surfaced by the update pipeline, each with a user-readable description.
enum UpdateError: LocalizedError {
    case network(String)
    case decoding
    case rateLimited
    case noAsset
    case untrustedSource
    case mountFailed
    case appNotFoundInImage
    case verificationFailed(String)
    case replaceFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .network(let m): return "Network error: \(m)"
        case .decoding: return "Couldn't read the release information from GitHub."
        case .rateLimited: return "GitHub rate limit reached. Please try again later."
        case .noAsset: return "The latest release has no downloadable DMG."
        case .untrustedSource: return "The update came from an untrusted source and was blocked."
        case .mountFailed: return "Couldn't mount the downloaded disk image."
        case .appNotFoundInImage: return "The disk image didn't contain Uninstally."
        case .verificationFailed(let m): return "Update verification failed: \(m)"
        case .replaceFailed(let m): return "Couldn't install the update: \(m)"
        case .cancelled: return "The update was cancelled."
        }
    }
}
