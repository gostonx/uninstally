import Foundation

/// A transparent, human-readable summary of a validated `DeletionPlan`, shown to
/// the user before anything is deleted. Also surfaces warnings for administrator
/// privileges, shared resources and excluded items.
struct SecuritySummary: Sendable {
    let applicationCount: Int
    let relatedCount: Int
    let recoverableBytes: Int64
    let userFileCount: Int
    let adminFileCount: Int
    let sharedCount: Int
    let loginItemCount: Int
    let launchAgentCount: Int
    let launchDaemonCount: Int
    let containerCount: Int
    let preferenceCount: Int
    let rejectedCount: Int
    let method: DeletionMode

    struct Warning: Identifiable, Sendable {
        enum Severity: Sendable { case info, caution, danger }
        let id = UUID()
        let text: String
        let systemImage: String
        let severity: Severity
    }

    init(plan: DeletionPlan) {
        method = plan.method
        applicationCount = plan.items(in: .application).count
        relatedCount = plan.items.count - applicationCount
        recoverableBytes = plan.totalBytes
        adminFileCount = plan.items.filter(\.requiresAdmin).count
        userFileCount = plan.items.count - adminFileCount
        sharedCount = plan.items.filter(\.isShared).count
        loginItemCount = plan.items(in: .loginItems).count
        launchAgentCount = plan.items(in: .launchAgents).count
        launchDaemonCount = plan.items(in: .launchDaemons).count
        containerCount = plan.items(in: .containers).count + plan.items(in: .groupContainers).count
        preferenceCount = plan.items(in: .preferences).count
        rejectedCount = plan.rejected.count
    }

    /// Accurate description of what will happen — never implies behaviour that
    /// won't occur.
    var methodDescription: String {
        switch method {
        case .trash:
            return "Applications and related files will be moved to the Trash. You can restore them until the Trash is emptied."
        case .permanent:
            return "Applications and related files will be permanently deleted. This action cannot be undone."
        }
    }

    var warnings: [Warning] {
        var list: [Warning] = []
        if adminFileCount > 0 {
            list.append(Warning(
                text: "\(adminFileCount) item\(adminFileCount == 1 ? "" : "s") require administrator privileges. Uninstally will attempt them and skip any it cannot safely remove — it never runs shell commands.",
                systemImage: "lock.shield.fill", severity: .caution))
        }
        if sharedCount > 0 {
            list.append(Warning(
                text: "\(sharedCount) shared resource\(sharedCount == 1 ? "" : "s") detected that may be used by other software. Review before removing.",
                systemImage: "person.2.fill", severity: .caution))
        }
        if rejectedCount > 0 {
            list.append(Warning(
                text: "\(rejectedCount) item\(rejectedCount == 1 ? "" : "s") were excluded because their path could not be validated as safe.",
                systemImage: "xmark.shield.fill", severity: .info))
        }
        return list
    }
}
