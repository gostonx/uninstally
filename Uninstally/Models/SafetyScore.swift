import Foundation

struct SafetyScore: Sendable {
    enum Level: String, Sendable {
        case safeToRemove = "Safe to Remove"
        case reviewRecommended = "Review Recommended"
        case highRisk = "High Risk"

        var systemImage: String {
            switch self {
            case .safeToRemove: return "checkmark.shield.fill"
            case .reviewRecommended: return "exclamationmark.shield.fill"
            case .highRisk: return "xmark.shield.fill"
            }
        }

        var headerDescription: String {
            switch self {
            case .safeToRemove:
                return "Only application-specific files were detected. No shared resources, system locations, or elevated permissions are needed."
            case .reviewRecommended:
                return "Some files may affect other applications or require additional permissions. Review before continuing."
            case .highRisk:
                return "System-level files, shared components, or ambiguous ownership were detected. Proceed with caution."
            }
        }
    }

    let level: Level
    let factors: [SafetyFactor]
    let filesAnalyzed: Int
    let filesToRemove: Int
    let sharedFilesFound: Int
    let systemFilesFound: Int
    let adminFilesFound: Int
    let backgroundComponentsCount: Int

    init(from plan: DeletionPlan) {
        filesAnalyzed = plan.items.count + plan.rejected.count
        filesToRemove = plan.items.count
        adminFilesFound = plan.items.filter(\.requiresAdmin).count
        sharedFilesFound = plan.items.filter(\.isShared).count

        let systemCategories: Set<RemovalCategory> = [
            .launchAgents, .launchDaemons, .privilegedHelper, .extensions
        ]
        systemFilesFound = plan.items.filter { systemCategories.contains($0.category) }.count

        let backgroundCategories: Set<RemovalCategory> = [
            .launchAgents, .launchDaemons, .privilegedHelper, .loginItems, .extensions
        ]
        backgroundComponentsCount = plan.items.filter { backgroundCategories.contains($0.category) }.count

        factors = SafetyScore.buildFactors(from: plan)
        level = SafetyScore.computeLevel(factors: factors)
    }

    private static func buildFactors(from plan: DeletionPlan) -> [SafetyFactor] {
        var list: [SafetyFactor] = []

        let adminCount = plan.items.filter(\.requiresAdmin).count
        let sharedCount = plan.items.filter(\.isShared).count
        let rejectedCount = plan.rejected.count
        let appOnly = plan.items.filter { $0.category == .application }.count
        let relatedCount = plan.items.count - appOnly
        let systemCount = plan.items.filter {
            [RemovalCategory.launchAgents, .launchDaemons, .privilegedHelper, .extensions].contains($0.category)
        }.count

        // Positive factors
        list.append(SafetyFactor(
            name: "Application files only",
            severity: .info,
            detail: relatedCount == 0
                ? "Only the application bundle itself was found — no supporting files detected."
                : "\(relatedCount) supporting file\(relatedCount == 1 ? "" : "s") detected in standard locations.",
            isPositive: relatedCount <= 3
        ))

        if sharedCount == 0 {
            list.append(SafetyFactor(
                name: "No shared resources",
                severity: .info,
                detail: "No files that could affect other applications were found.",
                isPositive: true
            ))
        }

        if systemCount == 0 {
            list.append(SafetyFactor(
                name: "No system files affected",
                severity: .info,
                detail: "No launch agents, daemons, extensions, or system-level components were found.",
                isPositive: true
            ))
        }

        if adminCount == 0 {
            list.append(SafetyFactor(
                name: "No elevated permissions needed",
                severity: .info,
                detail: "All files are in your user domain — no administrator password is required.",
                isPositive: true
            ))
        }

        list.append(SafetyFactor(
            name: "No protected files detected",
            severity: .info,
            detail: rejectedCount == 0
                ? "All discovered files passed path validation."
                : "\(rejectedCount) file\(rejectedCount == 1 ? "" : "s") excluded by safety validation.",
            isPositive: rejectedCount == 0
        ))

        // Self-uninstall warning
        if plan.app.bundleIdentifier == "com.codenta.uninstally"
            || plan.app.url.path.contains(Bundle.main.bundleURL.path) {
            list.append(SafetyFactor(
                name: "Uninstalling the uninstaller",
                severity: .caution,
                detail: "You are about to remove Uninstally itself. This will not affect your other applications.",
                isPositive: false
            ))
        }

        // Negative factors
        if sharedCount > 0 {
            list.append(SafetyFactor(
                name: "Shared resources detected",
                severity: .caution,
                detail: "\(sharedCount) file\(sharedCount == 1 ? "" : "s") may be used by other applications. Review before removing.",
                isPositive: false
            ))
        }

        if adminCount > 0 {
            list.append(SafetyFactor(
                name: "Administrator privileges required",
                severity: .caution,
                detail: "\(adminCount) file\(adminCount == 1 ? "" : "s") are outside your user domain and need administrator access to remove.",
                isPositive: false
            ))
        }

        if systemCount > 0 {
            list.append(SafetyFactor(
                name: "System-level components detected",
                severity: .warning,
                detail: "\(systemCount) background component\(systemCount == 1 ? "" : "s") (launch agents, extensions) were found. Removing these may affect functionality.",
                isPositive: false
            ))
        }

        if rejectedCount > 0 {
            list.append(SafetyFactor(
                name: "Excluded items",
                severity: .info,
                detail: "\(rejectedCount) discovered item\(rejectedCount == 1 ? "" : "s") failed safety validation and will not be removed.",
                isPositive: false
            ))
        }

        return list
    }

    private static func computeLevel(factors: [SafetyFactor]) -> Level {
        let negativeCount = factors.filter { !$0.isPositive }.count
        let hasWarning = factors.contains { $0.severity == .warning }

        if hasWarning { return .highRisk }
        if negativeCount >= 2 { return .reviewRecommended }
        return .safeToRemove
    }
}
