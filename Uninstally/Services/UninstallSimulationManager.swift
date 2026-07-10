import Foundation

@MainActor
struct UninstallSimulationManager {
    private let scanner = AssociatedFileScanner()

    func run(for app: AppInfo, onProgress: @MainActor (String) -> Void) async -> SimulationResult {
        let includeSystem = SecurityPreferences.scanSystemLevel

        onProgress("Scanning application\u{2026}")
        onProgress("Searching containers, caches and preferences\u{2026}")
        let items = await scanner.scan(for: app, includeSystem: includeSystem)

        onProgress("Searching login items, launch agents and services\u{2026}")
        onProgress("Validating every path\u{2026}")
        let validator = DeletionValidator(includeSystem: includeSystem)
        let plan = validator.buildPlan(app: app, items: items, method: DeletionMode.stored)

        let validatedItems = plan.items.map { planned in
            RemovableItem(
                category: planned.category,
                url: planned.canonicalURL,
                sizeBytes: planned.sizeBytes,
                requiresAdmin: planned.requiresAdmin,
                isSelected: true,
                matchReason: planned.matchReason
            )
        }

        onProgress("Calculating storage\u{2026}")
        let result = SimulationResult(app: app, items: validatedItems, rejectedCount: plan.rejected.count)
        result.safetyScore = SafetyScore(from: plan)
        return result
    }
}
