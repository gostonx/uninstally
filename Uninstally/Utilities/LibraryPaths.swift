import Foundation

/// Well-known file-system locations searched by the scanners. Paths are resolved
/// relative to the current user's home directory and the system root, and are
/// split by the privilege required to modify them.
enum LibraryPaths {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    /// Bundle extensions recognised as removable items by the scanners, Finder
    /// extension, and Trash monitor. Includes applications and audio plugin formats.
    static let supportedBundleExtensions: Set<String> = [
        "app", "component", "vst", "vst3", "aaxplugin", "clap",
    ]

    /// `true` when `url` has one of the supported bundle extensions.
    static func isSupportedBundle(_ url: URL) -> Bool {
        supportedBundleExtensions.contains(url.pathExtension)
    }

    /// Directories where `.app` bundles are commonly installed.
    static var applicationDirectories: [URL] {
        var dirs: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appending(path: "Applications", directoryHint: .isDirectory),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
        ]
        // External / secondary volumes.
        if let volumes = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes", isDirectory: true),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for volume in volumes {
                let candidate = volume.appending(path: "Applications", directoryHint: .isDirectory)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    dirs.append(candidate)
                }
            }
        }
        return dirs
    }

    // MARK: - Audio plug-in directories

    /// Directories where audio plug-in bundles are commonly installed.
    static var pluginDirectories: [URL] {
        var dirs: [URL] = [
            sys("Audio", "Plug-Ins", "Components"),
            sys("Audio", "Plug-Ins", "VST"),
            sys("Audio", "Plug-Ins", "VST3"),
            sys("Audio", "Plug-Ins", "CLAP"),
            sys("Application Support", "Avid", "Audio", "Plug-Ins"),
            lib("Audio", "Plug-Ins", "Components"),
            lib("Audio", "Plug-Ins", "VST"),
            lib("Audio", "Plug-Ins", "VST3"),
            lib("Audio", "Plug-Ins", "CLAP"),
        ]
        return dirs.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: - User Library (no admin required)

    private static func lib(_ components: String...) -> URL {
        var url = home.appending(path: "Library", directoryHint: .isDirectory)
        for component in components {
            url = url.appending(path: component, directoryHint: .isDirectory)
        }
        return url
    }

    /// User-writable containers keyed by the category they map to.
    static var userCategoryRoots: [(RemovalCategory, URL)] {
        [
            (.applicationSupport, lib("Application Support")),
            (.caches, lib("Caches")),
            (.preferences, lib("Preferences")),
            (.savedState, lib("Saved Application State")),
            (.logs, lib("Logs")),
            (.containers, lib("Containers")),
            (.groupContainers, lib("Group Containers")),
            (.cookies, lib("Cookies")),
            (.webKit, lib("WebKit")),
            (.httpStorage, lib("HTTPStorages")),
            (.crashReports, lib("Application Support", "CrashReporter")),
            (.crashReports, lib("Logs", "DiagnosticReports")),
            (.launchAgents, lib("LaunchAgents")),
            (.loginItems, lib("Application Support", "com.apple.backgroundtaskmanagementagent")),
            (.quickLook, lib("QuickLook")),
            (.spotlight, lib("Metadata", "CoreSpotlight")),
            (.extensions, lib("Application Scripts")),
            (.containers, lib("Containers", "Data")),
        ]
    }

    // MARK: - System Library (admin required)

    private static func sys(_ components: String...) -> URL {
        var url = URL(fileURLWithPath: "/Library", isDirectory: true)
        for component in components {
            url = url.appending(path: component, directoryHint: .isDirectory)
        }
        return url
    }

    /// System-level containers keyed by category. Removing anything here needs admin rights.
    static var systemCategoryRoots: [(RemovalCategory, URL)] {
        [
            (.applicationSupport, sys("Application Support")),
            (.caches, sys("Caches")),
            (.preferences, sys("Preferences")),
            (.logs, sys("Logs")),
            (.launchAgents, sys("LaunchAgents")),
            (.launchDaemons, sys("LaunchDaemons")),
            (.privilegedHelper, sys("PrivilegedHelperTools")),
            (.extensions, sys("Extensions")),
            (.quickLook, sys("QuickLook")),
        ]
    }

    /// Temporary directories that may hold app-scoped scratch data.
    static var temporaryRoots: [URL] {
        var dirs: [URL] = []
        if let tmp = try? FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: home,
            create: false
        ) {
            dirs.append(tmp.deletingLastPathComponent())
        }
        dirs.append(URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true))
        return dirs
    }
}
