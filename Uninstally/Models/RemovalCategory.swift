import Foundation
import SwiftUI

/// The category of a removable artefact. Each case carries a human readable title
/// and an SF Symbol used consistently throughout the UI.
enum RemovalCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case application
    case applicationSupport
    case caches
    case preferences
    case savedState
    case logs
    case containers
    case groupContainers
    case cookies
    case webKit
    case httpStorage
    case temporary
    case launchAgents
    case launchDaemons
    case loginItems
    case extensions
    case crashReports
    case spotlight
    case quickLook
    case privilegedHelper
    case widgets
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .application: return "Application"
        case .applicationSupport: return "Application Support"
        case .caches: return "Caches"
        case .preferences: return "Preferences"
        case .savedState: return "Saved State"
        case .logs: return "Logs"
        case .containers: return "Containers"
        case .groupContainers: return "Group Containers"
        case .cookies: return "Cookies"
        case .webKit: return "WebKit Data"
        case .httpStorage: return "HTTP Storage"
        case .temporary: return "Temporary Files"
        case .launchAgents: return "Launch Agents"
        case .launchDaemons: return "Launch Daemons"
        case .loginItems: return "Login Items"
        case .extensions: return "Extensions"
        case .crashReports: return "Crash Reports"
        case .spotlight: return "Spotlight Metadata"
        case .quickLook: return "QuickLook Plugins"
        case .privilegedHelper: return "Privileged Helpers"
        case .widgets: return "Widgets"
        case .other: return "Other Support Files"
        }
    }

    var systemImage: String {
        switch self {
        case .application: return "app.dashed"
        case .applicationSupport: return "folder.fill"
        case .caches: return "internaldrive.fill"
        case .preferences: return "slider.horizontal.3"
        case .savedState: return "clock.arrow.circlepath"
        case .logs: return "doc.text.fill"
        case .containers: return "shippingbox.fill"
        case .groupContainers: return "square.stack.3d.up.fill"
        case .cookies: return "circle.grid.cross.fill"
        case .webKit: return "globe"
        case .httpStorage: return "network"
        case .temporary: return "hourglass"
        case .launchAgents: return "bolt.badge.clock.fill"
        case .launchDaemons: return "bolt.horizontal.fill"
        case .loginItems: return "person.badge.key.fill"
        case .extensions: return "puzzlepiece.extension.fill"
        case .crashReports: return "exclamationmark.triangle.fill"
        case .spotlight: return "magnifyingglass"
        case .quickLook: return "eye.fill"
        case .privilegedHelper: return "lock.shield.fill"
        case .widgets: return "square.grid.2x2.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// Sort weight so the most important categories appear first.
    var order: Int {
        RemovalCategory.allCases.firstIndex(of: self) ?? .max
    }

    var tint: Color {
        switch self {
        case .application: return .accentColor
        case .caches, .temporary: return .orange
        case .logs, .crashReports: return .red
        case .launchAgents, .launchDaemons, .privilegedHelper, .loginItems: return .purple
        case .containers, .groupContainers: return .teal
        default: return .secondary
        }
    }
}
