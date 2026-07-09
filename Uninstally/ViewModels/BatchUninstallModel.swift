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

    private let scanner = AssociatedFileScanner()
    private let engine = UninstallEngine()

    init(apps: [AppInfo]) {
        self.apps = apps
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

    func run() async {
        phase = .running
        for (index, app) in apps.enumerated() {
            currentIndex = index
            currentApp = app
            let plan = await scanner.makePlan(for: app)
            for await event in engine.run(plan: plan, mode: DeletionMode.stored) {
                switch event {
                case .progress(let progress):
                    self.progress = progress
                case .finished(let result):
                    results.append(result)
                }
            }
        }
        currentIndex = apps.count
        phase = .finished
    }
}
