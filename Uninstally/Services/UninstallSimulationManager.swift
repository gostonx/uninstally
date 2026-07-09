import Foundation

/// Builds an uninstall simulation for an application: it scans every associated
/// artefact, **validates every path**, and computes storage and risk analysis —
/// all without deleting anything. The resulting `SimulationResult` carries only
/// validated items, so the executor can run later without a second scan.
///
/// Kept intentionally separate from the deletion executor: this only inspects.
@MainActor
struct UninstallSimulationManager {
    private let scanner = AssociatedFileScanner()

    /// Runs a full, non-destructive simulation, reporting progress steps. The heavy
    /// scanning runs off the main thread, keeping the UI responsive. System-level
    /// locations are skipped when the user has disabled that preference.
    func run(for app: AppInfo, onProgress: @MainActor (String) -> Void) async -> SimulationResult {
        let includeSystem = SecurityPreferences.scanSystemLevel

        onProgress("Scanning application…")
        onProgress("Searching containers, caches and preferences…")
        let items = await scanner.scan(for: app, includeSystem: includeSystem)

        onProgress("Searching login items, launch agents and services…")
        onProgress("Validating every path…")
        let validator = DeletionValidator(includeSystem: includeSystem)
        let plan = validator.buildPlan(app: app, items: items, method: DeletionMode.stored)

        // Only validated artefacts are surfaced for review.
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

        onProgress("Calculating storage…")
        return SimulationResult(app: app, items: validatedItems, rejectedCount: plan.rejected.count)
    }
}
