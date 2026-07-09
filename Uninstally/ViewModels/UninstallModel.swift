import Foundation
import Observation

/// Coordinates the uninstall flow for a single application: scanning for
/// artefacts, letting the user review/deselect them, confirming, then running the
/// engine while surfacing live progress and a final result.
@MainActor
@Observable
final class UninstallModel {

    enum Phase: Equatable {
        case scanning
        case review
        case confirming
        case uninstalling
        case finished
    }

    let app: AppInfo
    private(set) var plan: UninstallPlan?
    private(set) var phase: Phase = .scanning
    private(set) var progress: UninstallProgress?
    private(set) var result: UninstallResult?

    var searchText = ""

    /// When `true`, the app was launched solely to perform this uninstall and
    /// should terminate on completion.
    let isDedicatedSession: Bool

    private let scanner = AssociatedFileScanner()
    private let engine = UninstallEngine()

    init(app: AppInfo, isDedicatedSession: Bool) {
        self.app = app
        self.isDedicatedSession = isDedicatedSession
    }

    // MARK: - Scanning

    func scan() async {
        phase = .scanning
        let plan = await scanner.makePlan(for: app)
        self.plan = plan
        phase = .review
    }

    // MARK: - Selection

    func setSelection(_ id: RemovableItem.ID, isSelected: Bool) {
        guard var plan else { return }
        if let index = plan.items.firstIndex(where: { $0.id == id }) {
            plan.items[index].isSelected = isSelected
            self.plan = plan
        }
    }

    func setSelection(for category: RemovalCategory, isSelected: Bool) {
        guard var plan else { return }
        for index in plan.items.indices where plan.items[index].category == category {
            // The application bundle itself cannot be deselected — removing an app
            // without its bundle makes no sense.
            if plan.items[index].category == .application { continue }
            plan.items[index].isSelected = isSelected
        }
        self.plan = plan
    }

    var filteredGroups: [(category: RemovalCategory, items: [RemovableItem])] {
        guard let plan else { return [] }
        guard !searchText.isEmpty else { return plan.groupedItems }
        let query = searchText
        return plan.groupedItems.compactMap { group in
            let matches = group.items.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.displayPath.localizedCaseInsensitiveContains(query)
                    || group.category.title.localizedCaseInsensitiveContains(query)
            }
            return matches.isEmpty ? nil : (group.category, matches)
        }
    }

    // MARK: - Confirmation

    func requestConfirmation() { phase = .confirming }
    func cancelConfirmation() { phase = .review }

    // MARK: - Uninstall

    /// The user's current deletion behaviour (Trash vs. permanent), read fresh so
    /// it always reflects the latest Settings choice.
    var deletionMode: DeletionMode { DeletionMode.stored }

    func uninstall() async {
        guard let plan else { return }
        phase = .uninstalling
        for await event in engine.run(plan: plan, mode: deletionMode) {
            switch event {
            case .progress(let progress):
                self.progress = progress
            case .finished(let result):
                self.result = result
                phase = .finished
                NotificationService.shared.postUninstallComplete(result)
            }
        }
    }
}
