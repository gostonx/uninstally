import AppKit
import Foundation
import os

/// Enumerates installed applications and extracts the metadata required by the UI.
///
/// The scan is fully asynchronous and performed off the main actor. Each `.app`
/// bundle is inspected via `Bundle`/`Info.plist`; sizes are computed with the
/// shared `FileSystemUtil`. Nothing here mutates the file system.
struct ApplicationScanner: Sendable {

    /// Scans all known application directories and returns the discovered apps.
    func scan() async -> [AppInfo] {
        let directories = LibraryPaths.applicationDirectories
        return await withTaskGroup(of: [AppInfo].self) { group in
            for directory in directories {
                group.addTask { Self.scanDirectory(directory) }
            }
            var results: [AppInfo] = []
            for await apps in group {
                results.append(contentsOf: apps)
            }
            // De-duplicate by resolved path but keep duplicates across *different* volumes.
            var seen = Set<String>()
            return results.filter { seen.insert($0.url.standardizedFileURL.path).inserted }
        }
    }

    /// Builds an `AppInfo` for a single bundle URL, used by the Finder launch path.
    func inspect(bundleURL: URL) -> AppInfo? {
        Self.makeAppInfo(from: bundleURL)
    }

    // MARK: - Private

    private static func scanDirectory(_ directory: URL) -> [AppInfo] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isApplicationKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return [] }

        var apps: [AppInfo] = []
        for entry in entries where entry.pathExtension == "app" {
            if let info = makeAppInfo(from: entry) {
                apps.append(info)
            }
        }
        // Also inspect one level of nesting (e.g. /Applications/Utilities live in a
        // separate directory already, but some vendors nest their apps in a folder).
        for entry in entries where entry.pathExtension != "app" {
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                  let nested = try? fm.contentsOfDirectory(
                      at: entry,
                      includingPropertiesForKeys: nil,
                      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                  ) else { continue }
            for candidate in nested where candidate.pathExtension == "app" {
                if let info = makeAppInfo(from: candidate) { apps.append(info) }
            }
        }
        return apps
    }

    private static func makeAppInfo(from url: URL) -> AppInfo? {
        guard let bundle = Bundle(url: url) else { return nil }
        let info = bundle.infoDictionary ?? [:]

        let bundleID = bundle.bundleIdentifier ?? ""
        let name = bundle.localizedDisplayName
            ?? (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let version = (info["CFBundleShortVersionString"] as? String) ?? ""
        let build = (info["CFBundleVersion"] as? String) ?? ""

        let executableExists: Bool = {
            guard let exec = bundle.executableURL else { return false }
            return FileManager.default.fileExists(atPath: exec.path)
        }()

        let size = FileSystemUtil.size(of: url)
        let installDate = FileSystemUtil.creationDate(of: url)
        let lastUsed = FileSystemUtil.lastUsedDate(of: url)
        let volume = FileSystemUtil.volumeName(of: url)

        let developer = Self.developerName(bundleID: bundleID, info: info)
        let auxIdentifiers = Self.auxiliaryIdentifiers(in: bundle)

        return AppInfo(
            url: url,
            name: name,
            bundleIdentifier: bundleID,
            version: version,
            buildVersion: build,
            developer: developer,
            sizeBytes: size,
            installDate: installDate,
            lastUsedDate: lastUsed,
            volumeName: volume,
            isBrokenInstall: !executableExists || bundleID.isEmpty,
            extraBundleIdentifiers: auxIdentifiers
        )
    }

    /// Derives a friendly developer name. Prefers an explicit copyright string,
    /// then falls back to the organisation component of the reverse-DNS bundle id.
    private static func developerName(bundleID: String, info: [String: Any]) -> String {
        if let copyright = info["NSHumanReadableCopyright"] as? String {
            // Strip years and boilerplate to leave the organisation name.
            let cleaned = copyright
                .replacingOccurrences(of: "Copyright", with: "")
                .replacingOccurrences(of: "©", with: "")
                .replacingOccurrences(of: "(c)", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let withoutYears = cleaned.split(whereSeparator: { $0 == "," || $0 == "." })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { component in
                    !component.isEmpty && Int(component.prefix(4)) == nil && component.count > 2
                }
            if let org = withoutYears, !org.isEmpty { return org }
        }

        let components = bundleID.split(separator: ".")
        if components.count >= 2 {
            let org = String(components[1])
            return org.prefix(1).uppercased() + org.dropFirst()
        }
        return ""
    }

    /// Harvests auxiliary bundle identifiers from embedded helpers, XPC services,
    /// login items and app extensions so the scanner can find their support files.
    private static func auxiliaryIdentifiers(in bundle: Bundle) -> [String] {
        var ids = Set<String>()
        let searchRoots = [
            "Contents/Library/LoginItems",
            "Contents/Library/LaunchServices",
            "Contents/XPCServices",
            "Contents/PlugIns",
            "Contents/Library/SystemExtensions",
            "Contents/Library/QuickLook",
            "Contents/Library/Spotlight",
        ]
        for relative in searchRoots {
            let root = bundle.bundleURL.appending(path: relative)
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            for entry in entries {
                if let child = Bundle(url: entry), let cid = child.bundleIdentifier {
                    ids.insert(cid)
                }
            }
        }
        return Array(ids)
    }
}

private extension Bundle {
    /// Localised display name via LaunchServices, falling back to `nil`.
    var localizedDisplayName: String? {
        (localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? (localizedInfoDictionary?["CFBundleName"] as? String)
    }
}
