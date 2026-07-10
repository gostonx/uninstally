import Foundation

struct InstallationSourceDetector: Sendable {

    func detect(for url: URL, bundleIdentifier: String) async -> InstallationSource {
        if isHomebrewCask(bundleID: bundleIdentifier, appURL: url) { return .homebrewCask }
        if isMacAppStore(appURL: url) { return .macAppStore }
        if isPKGInstalled(bundleID: bundleIdentifier) { return .pkgInstaller }
        if isDMGInstalled(appURL: url) { return .dmgInstaller }
        return .unknown
    }

    private func isHomebrewCask(bundleID: String, appURL: URL) -> Bool {
        guard let casks = try? listHomebrewCasks() else { return false }
        return casks.contains { cask in
            let caskBundleID = caskBundleIdentifier(for: cask)
            if !caskBundleID.isEmpty, caskBundleID == bundleID { return true }
            let caskPath = "/opt/homebrew/Caskroom/\(cask)"
            return appURL.path.hasPrefix(caskPath)
                || appURL.path.hasPrefix("/usr/local/Caskroom/\(cask)")
        }
    }

    private func listHomebrewCasks() throws -> [String] {
        let brewURLs = [
            URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            URL(fileURLWithPath: "/usr/local/bin/brew"),
        ]
        for brewURL in brewURLs {
            let result = try runSync(brewURL, ["list", "--cask", "--full-name"])
            if result.exitCode == 0, !result.stdout.isEmpty {
                return result.stdout.components(separatedBy: "\n").filter { !$0.isEmpty }
            }
        }
        return []
    }

    private func caskBundleIdentifier(for cask: String) -> String {
        let caskroom = "/opt/homebrew/Caskroom/\(cask)"
        let alt = "/usr/local/Caskroom/\(cask)"
        let base = FileManager.default.fileExists(atPath: caskroom) ? caskroom : alt
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: base) else { return "" }
        for version in versions {
            let appPath = "\(base)/\(version)"
            guard let apps = try? FileManager.default.contentsOfDirectory(atPath: appPath) else { continue }
            for entry in apps where LibraryPaths.supportedBundleExtensions.contains((entry as NSString).pathExtension) {
                if let bundle = Bundle(url: URL(fileURLWithPath: "\(appPath)/\(entry)")),
                   let id = bundle.bundleIdentifier {
                    return id
                }
            }
        }
        return ""
    }

    private func runSync(_ exec: URL, _ arguments: [String]) throws -> (exitCode: Int32, stdout: String) {
        let process = Process()
        process.executableURL = exec
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    private func isMacAppStore(appURL: URL) -> Bool {
        let receiptURL = appURL.appendingPathComponent("Contents/_MASReceipt/receipt")
        return FileManager.default.fileExists(atPath: receiptURL.path)
    }

    private func isDMGInstalled(appURL: URL) -> Bool {
        guard let metadata = try? appURL.resourceValues(forKeys: [.quarantinePropertiesKey]),
              let quarantine = metadata.quarantineProperties,
              let origin = quarantine["LSQuarantineAgentName"] as? String else { return false }
        return origin.contains("DiskImageMounter") || origin.contains("hdiutil")
    }

    private func isPKGInstalled(bundleID: String) -> Bool {
        let receiptsDir = "/var/db/receipts"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: receiptsDir) else { return false }
        let normalized = bundleID.lowercased()
        return files.contains { $0.lowercased().contains(normalized) }
    }
}
