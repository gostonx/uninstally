import Foundation
import Observation

/// Coordinates the uninstall flow for a single application: running an uninstall
/// **simulation** (a non-destructive scan + analysis), letting the user review and
/// deselect artefacts, confirming, then running the engine on the *already
/// simulated* plan while surfacing live progress and a final result.
@MainActor
@Observable
final class UninstallModel: Identifiable {

    enum Phase: Equatable {
        case scanning
        case review
        case confirming
        case uninstalling
        case finished
    }

    let app: AppInfo
    nonisolated var id: String { app.id }

    private(set) var simulation: SimulationResult?
    private(set) var phase: Phase = .scanning
    private(set) var progress: UninstallProgress?
    private(set) var result: UninstallResult?
    /// Human-readable step shown while the simulation scans.
    private(set) var scanStep: String = "Preparing…"

    var searchText = ""

    /// When `true`, the app was launched solely to perform this uninstall and
    /// should terminate on completion.
    let isDedicatedSession: Bool

    /// PNG snapshot of the app icon, captured before removal for the history.
    private(set) var iconData: Data?

    private let simulator = UninstallSimulationManager()
    private var scanTask: Task<Void, Never>?
    private var deletionTask: Task<Void, Never>?

    init(app: AppInfo, isDedicatedSession: Bool) {
        self.app = app
        self.isDedicatedSession = isDedicatedSession
        self.iconData = IconLoader.shared.pngData(for: app.url)
    }

    // MARK: - Simulation

    func startScan() {
        scanTask = Task { await scan() }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
    }

    private func scan() async {
        phase = .scanning
        let result = await simulator.run(for: app) { [weak self] step in
            self?.scanStep = step
        }
        guard !Task.isCancelled else { return }
        self.simulation = result
        phase = .review
    }

    // MARK: - Selection helpers

    /// Categories filtered by the current search text.
    var filteredCategories: [SimulationCategory] {
        guard let simulation else { return [] }
        guard !searchText.isEmpty else { return simulation.categories }
        let query = searchText
        return simulation.categories.compactMap { category in
            let matches = category.files.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.displayPath.localizedCaseInsensitiveContains(query)
                    || category.removalCategory.title.localizedCaseInsensitiveContains(query)
                    || app.bundleIdentifier.localizedCaseInsensitiveContains(query)
            }
            guard !matches.isEmpty else { return nil }
            let filtered = SimulationCategory(removalCategory: category.removalCategory, files: matches)
            return filtered
        }
    }

    // MARK: - Confirmation

    func requestConfirmation() { phase = .confirming }
    func cancelConfirmation() { phase = .review }

    /// Advances from review, enforcing the "Require Confirmation Before Uninstall"
    /// preference: when enabled, the confirmation must be accepted; when disabled,
    /// the uninstall proceeds directly.
    func proceed() async {
        if SecurityPreferences.requireConfirmation {
            phase = .confirming
        } else {
            await uninstall()
        }
    }

    /// The validated deletion plan for the current selection (no rescan).
    var deletionPlan: DeletionPlan {
        let selected = simulation?.asRemovableItems.filter(\.isSelected) ?? []
        let validator = DeletionValidator(includeSystem: SecurityPreferences.scanSystemLevel)
        return validator.buildPlan(app: app, items: selected, method: deletionMode)
    }

    /// Security summary shown before uninstalling.
    var securitySummary: SecuritySummary { SecuritySummary(plan: deletionPlan) }

    // MARK: - Uninstall

    /// The user's current deletion behaviour, read fresh from Settings.
    var deletionMode: DeletionMode { DeletionMode.stored }

    func startUninstall() {
        deletionTask = Task { await uninstall() }
    }

    func startProceed() {
        deletionTask = Task { await proceed() }
    }

    func cancelUninstall() {
        deletionTask?.cancel()
        deletionTask = nil
    }

    func uninstall() async {
        guard simulation != nil else { return }
        let plan = deletionPlan
        phase = .uninstalling
        for await event in DeletionExecutor().execute(plan: plan) {
            switch event {
            case .progress(let progress):
                self.progress = progress
            case .finished(let result):
                guard !Task.isCancelled else { return }
                self.result = result
                phase = .finished
                NotificationService.shared.postUninstallComplete(result)
            }
        }
    }
}
