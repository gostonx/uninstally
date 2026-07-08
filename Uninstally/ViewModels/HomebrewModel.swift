import Foundation
import Observation

/// Backs the Homebrew screen. Lists installed packages, resolves dependency
/// information on demand, and performs uninstalls.
@MainActor
@Observable
final class HomebrewModel {
    private(set) var packages: [HomebrewPackage] = []
    private(set) var isLoading = false
    private(set) var isInstalled = false
    private(set) var busyPackage: String?

    var searchText = ""

    private let service = HomebrewService()

    var filteredPackages: [HomebrewPackage] {
        guard !searchText.isEmpty else { return packages }
        return packages.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func load() async {
        isInstalled = service.isInstalled
        guard isInstalled else { return }
        isLoading = true
        defer { isLoading = false }
        packages = await service.listPackages()
    }

    func dependencies(of package: HomebrewPackage) async -> [String] {
        await service.dependencies(of: package)
    }

    func dependents(of package: HomebrewPackage) async -> [String] {
        await service.dependents(of: package)
    }

    /// Uninstalls a package. Returns an error message on failure.
    func uninstall(_ package: HomebrewPackage, removeLeftovers: Bool) async -> String? {
        busyPackage = package.name
        defer { busyPackage = nil }
        let error = await service.uninstall(package, removeDependencies: removeLeftovers)
        if error == nil {
            packages.removeAll { $0.id == package.id }
        }
        return error
    }
}
