import SwiftUI

/// Container for the full single-app uninstall flow. Switches sub-screens based on
/// the model's phase and hosts the safety confirmation overlay.
struct UninstallView: View {
    @Bindable var model: UninstallModel
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(HistoryStore.self) private var history

    var body: some View {
        ZStack {
            switch model.phase {
            case .scanning:
                ScanningView(app: model.app, step: model.scanStep)
            case .review, .confirming:
                UninstallSimulationView(
                    model: model,
                    onCancel: cancel,
                    onProceed: { Task { await model.proceed() } }
                )
            case .uninstalling:
                UninstallProgressView(app: model.app, progress: model.progress)
            case .finished:
                if let result = model.result {
                    CompletionView(result: result, isDedicated: model.isDedicatedSession) {
                        finish()
                    }
                }
            }

            if model.phase == .confirming {
                SafetyConfirmView(
                    app: model.app,
                    summary: model.securitySummary,
                    onCancel: { model.cancelConfirmation() },
                    onConfirm: { Task { await model.uninstall() } }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.phase)
        .task { await model.scan() }
        .onChange(of: model.phase) { _, phase in
            if phase == .finished {
                if let result = model.result {
                    history.record(app: model.app, result: result,
                                   mode: model.deletionMode, iconData: model.iconData)
                }
                coordinator.uninstallDidFinish(dedicated: model.isDedicatedSession)
            }
        }
    }

    private func cancel() {
        if model.isDedicatedSession {
            NSApplication.shared.terminate(nil)
        } else {
            coordinator.showBrowser()
        }
    }

    private func finish() {
        if model.isDedicatedSession {
            NSApplication.shared.terminate(nil)
        } else {
            let removedID = FileSystemUtil.exists(model.app.url) ? nil : model.app.id
            coordinator.finishedUninstall(removed: removedID)
        }
    }
}

/// Indeterminate scan screen shown while the simulation runs.
struct ScanningView: View {
    let app: AppInfo
    var step: String = "Preparing…"
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 22) {
            AppIconView(url: app.url, size: 96)
                .scaleEffect(pulse ? 1.05 : 0.97)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
            VStack(spacing: 6) {
                Text("Simulating uninstall of \(app.name)")
                    .font(.title2.weight(.semibold))
                Text(step)
                    .foregroundStyle(.secondary)
                    .animation(.default, value: step)
                    .contentTransition(.opacity)
            }
            ProgressView()
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true }
    }
}
