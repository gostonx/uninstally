import Foundation
import os

/// A Homebrew-managed package (formula or cask).
struct HomebrewPackage: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let version: String
    let isCask: Bool
    var dependencies: [String] = []

    var kindLabel: String { isCask ? "Cask" : "Formula" }
    var systemImage: String { isCask ? "shippingbox.fill" : "cube.fill" }
}

/// Detects and drives Homebrew. All shell interaction is asynchronous and never
/// blocks the UI. The service degrades gracefully when Homebrew is absent.
struct HomebrewService: Sendable {

    /// Locates the `brew` executable, honouring both Apple-silicon and Intel prefixes.
    func brewURL() -> URL? {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return candidates
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    var isInstalled: Bool { brewURL() != nil }

    /// Lists installed casks and top-level formulae.
    func listPackages() async -> [HomebrewPackage] {
        guard let brew = brewURL() else { return [] }
        async let casks = Shell.lines(brew, ["list", "--cask", "-1"])
        async let formulae = Shell.lines(brew, ["leaves"]) // top-level formulae only
        async let versions = versionMap(brew: brew)

        let (caskList, formulaList, versionLookup) = await (casks, formulae, versions)
        var packages: [HomebrewPackage] = []
        for name in caskList where !name.isEmpty {
            packages.append(HomebrewPackage(name: name, version: versionLookup[name] ?? "", isCask: true))
        }
        for name in formulaList where !name.isEmpty {
            packages.append(HomebrewPackage(name: name, version: versionLookup[name] ?? "", isCask: false))
        }
        return packages.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Returns the reverse dependencies of a formula (packages that would break).
    func dependents(of package: HomebrewPackage) async -> [String] {
        guard let brew = brewURL(), !package.isCask else { return [] }
        return await Shell.lines(brew, ["uses", "--installed", package.name])
            .filter { !$0.isEmpty }
    }

    /// Returns the direct dependencies of a package.
    func dependencies(of package: HomebrewPackage) async -> [String] {
        guard let brew = brewURL() else { return [] }
        let args = package.isCask ? ["deps", "--cask", package.name] : ["deps", package.name]
        return await Shell.lines(brew, args).filter { !$0.isEmpty }
    }

    /// Uninstalls a package. Returns an error message on failure, `nil` on success.
    func uninstall(_ package: HomebrewPackage, removeDependencies: Bool) async -> String? {
        guard let brew = brewURL() else { return "Homebrew is not installed." }
        var args = ["uninstall"]
        if package.isCask { args.append("--cask") }
        if removeDependencies { args.append("--zap") }
        args.append(package.name)
        let result = await Shell.run(brew, args)
        return result.exitCode == 0 ? nil : (result.stderr.isEmpty ? "Uninstall failed." : result.stderr)
    }

    private func versionMap(brew: URL) async -> [String: String] {
        let lines = await Shell.lines(brew, ["list", "--versions"])
        var map: [String: String] = [:]
        for line in lines {
            let parts = line.split(separator: " ", maxSplits: 1)
            if let name = parts.first {
                map[String(name)] = parts.count > 1 ? String(parts[1]) : ""
            }
        }
        return map
    }
}

/// Minimal async wrapper around `Process` for read-only or user-initiated commands.
enum Shell {
    struct Result: Sendable {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    static func run(_ executable: URL, _ arguments: [String]) async -> Result {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments
                // A minimal, predictable environment.
                process.environment = [
                    "HOME": LibraryPaths.home.path,
                    "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
                    "HOMEBREW_NO_AUTO_UPDATE": "1",
                    "HOMEBREW_NO_ANALYTICS": "1",
                ]
                let out = Pipe(), err = Pipe()
                process.standardOutput = out
                process.standardError = err
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: Result(exitCode: -1, stdout: "", stderr: error.localizedDescription))
                    return
                }
                let outData = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: Result(
                    exitCode: process.terminationStatus,
                    stdout: String(decoding: outData, as: UTF8.self),
                    stderr: String(decoding: errData, as: UTF8.self)
                ))
            }
        }
    }

    static func lines(_ executable: URL, _ arguments: [String]) async -> [String] {
        let result = await run(executable, arguments)
        return result.stdout.split(separator: "\n").map(String.init)
    }
}
