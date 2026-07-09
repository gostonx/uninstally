import Foundation
import os

/// Turns a set of scanner-discovered artefacts into a **validated** `DeletionPlan`.
///
/// Every candidate is put through two independent checks:
/// 1. `PathValidator` — canonicalises the path and confirms it lives strictly
///    inside an approved root and is not a protected/system/volume location.
/// 2. A belongs-to-application check — the path must be attributable to the target
///    app (its bundle identifier / helper namespace / name, or the bundle itself).
///
/// Anything that fails either check is excluded and recorded as `rejected` so the
/// user and the log can see exactly what was skipped and why.
struct DeletionValidator {
    let includeSystem: Bool
    /// When `true`, each artefact must be attributable to the target application.
    /// Leftover cleanup sets this to `false` (orphans have no owning app), relying
    /// solely on `PathValidator`'s approved-root guarantees.
    var requireAppOwnership: Bool = true

    func buildPlan(app: AppInfo, items: [RemovableItem], method: DeletionMode) -> DeletionPlan {
        var planned: [PlannedDeletion] = []
        var rejected: [RejectedDeletion] = []

        let appPath = app.url.resolvingSymlinksInPath().standardizedFileURL.path

        for item in items {
            switch PathValidator.validate(item.url, includeSystem: includeSystem) {
            case .failure(let rejection):
                rejected.append(RejectedDeletion(path: rejection.path, reason: rejection.reason))
                Logger.engine.log("Rejected \(rejection.path, privacy: .public): \(rejection.reason, privacy: .public)")

            case .success(let canonical):
                let isBundle = canonical.path == appPath || item.category == .application
                if requireAppOwnership, !isBundle, !belongsToApp(canonical, app: app) {
                    rejected.append(RejectedDeletion(
                        path: canonical.path,
                        reason: "Could not confirm this belongs to \(app.name)"
                    ))
                    continue
                }
                planned.append(PlannedDeletion(
                    id: item.id,
                    originalURL: item.url,
                    canonicalURL: canonical,
                    category: item.category,
                    sizeBytes: item.sizeBytes,
                    requiresAdmin: item.requiresAdmin,
                    isShared: item.isShared,
                    matchReason: item.matchReason
                ))
            }
        }

        return DeletionPlan(app: app, method: method, items: planned, rejected: rejected)
    }

    /// Confirms the path is attributable to the application via its identifiers or
    /// name appearing somewhere in the path.
    private func belongsToApp(_ url: URL, app: AppInfo) -> Bool {
        let lowerPath = url.path.lowercased()
        for identifier in IdentifierMatcher.exactIdentifiers(for: app) where !identifier.isEmpty {
            if lowerPath.contains(identifier.lowercased()) { return true }
        }
        for prefix in IdentifierMatcher.prefixes(for: app) {
            if lowerPath.contains(prefix.lowercased()) { return true }
        }
        if app.name.count > 3, lowerPath.contains(app.name.lowercased()) { return true }
        let bundleName = app.url.lastPathComponent.lowercased()
        if bundleName.count > 3, lowerPath.contains(bundleName) { return true }
        return false
    }
}
