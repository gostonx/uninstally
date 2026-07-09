import Foundation

struct SafetyFactor: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let severity: Severity
    let detail: String
    let isPositive: Bool

    enum Severity: Sendable, Comparable {
        case info
        case caution
        case warning

        var systemImage: String {
            switch self {
            case .info: return "checkmark.circle.fill"
            case .caution: return "exclamationmark.triangle.fill"
            case .warning: return "xmark.shield.fill"
            }
        }

        var tint: SeverityTint {
            switch self {
            case .info: return .green
            case .caution: return .yellow
            case .warning: return .red
            }
        }
    }

    enum SeverityTint { case green, yellow, red }
}
