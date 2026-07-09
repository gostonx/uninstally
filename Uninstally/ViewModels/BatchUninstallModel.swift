import Foundation
import Observation

/// Coordinates a sequential batch uninstall of several applications, aggregating
/// the reclaimed storage and surfacing per-app progress.
@MainActor
@Observable
final class BatchUninstallModel {
    enum Phase: Equatable { case review, running, finished }

    let apps: [AppInfo]
    private(set) var phase: Phase = .review
    private(set) var currentIndex = 0
    private(set) var currentApp: AppInfo?
    private(set) var progress: UninstallProgress?
    private(set) var results: [UninstallResult] = []
    /// Per-app outcomes with pre-captured icon data, for recording history.
    private(set) var completedRecords: [(app: AppInfo, result: UninstallResult, icon: Data?)] = []

    private let scanner = AssociatedFileScanner()
    private let mode = DeletionMode.stored
    /// Icons captured up front, before any bundle is removed.
    private let icons: [AppInfo.ID: Data]

    init(apps: [AppInfo]) {
        self.apps = apps
        var captured: [AppInfo.ID: Data] = [:]
        for app in apps {
            captured[app.id] = IconLoader.shared.pngData(for: app.url)
        }
        self.icons = captured
    }

    var totalEstimatedBytes: Int64 {
        apps.reduce(0) { $0 + $1.sizeBytes }
    }

    var reclaimedBytes: Int64 {
        results.reduce(0) { $0 + $1.reclaimedBytes }
    }

    var removedFileCount: Int {
        results.reduce(0) { $0 + $1.removedFileCount }
    }

    var overallFraction: Double {
        guard !apps.isEmpty else { return 1 }
        let base = Double(currentIndex) / Double(apps.count)
        let inner = (progress?.fractionCompleted ?? 0) / Double(apps.count)
        return min(base + inner, 1)
    }

    var deletionMode: DeletionMode { mode }

    func run() async {
        phase = .running
        let includeSystem = SecurityPreferences.scanSystemLevel
        let validator = DeletionValidator(includeSystem: includeSystem)
        for (index, app) in apps.enumerated() {
            currentIndex = index
            currentApp = app
            let items = await scanner.scan(for: app, includeSystem: includeSystem)
            let plan = validator.buildPlan(app: app, items: items, method: mode)
            for await event in DeletionExecutor().execute(plan: plan) {
                switch event {
                case .progress(let progress):
                    self.progress = progress
                case .finished(let result):
                    results.append(result)
                    completedRecords.append((app, result, icons[app.id]))
                }
            }
        }
        currentIndex = apps.count
        phase = .finished
    }
}
