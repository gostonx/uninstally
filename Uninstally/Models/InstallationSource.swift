import Foundation

enum InstallationSource: String, CaseIterable, Identifiable, Codable, Sendable {
    case homebrewCask = "Homebrew Cask"
    case macAppStore = "Mac App Store"
    case dmgInstaller = "DMG Installer"
    case pkgInstaller = "PKG Installer"
    case unknown = "Unknown Source"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .homebrewCask: return "mug.fill"
        case .macAppStore: return "apple.logo"
        case .dmgInstaller: return "opticaldisc"
        case .pkgInstaller: return "shippingbox.fill"
        case .unknown: return "questionmark.app"
        }
    }
}
