import SwiftUI

/// The root view. Switches between the standalone browser and a dedicated
/// uninstall / batch flow based on the coordinator's route, and presents
/// onboarding on first launch.
struct RootView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(UpdateManager.self) private var updateManager
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch coordinator.route {
            case .browser:
                MainWindowView()
            case .uninstall(let model):
                // NavigationStack hosts simulation titles/toolbars without inheriting
                // the browser's searchable NSToolbar (tearing that down mid-IME resign
                // crashes — see AppCoordinator.leaveSearchableChrome).
                NavigationStack {
                    UninstallView(model: model)
                }
            case .batch(let model):
                NavigationStack {
                    BatchUninstallView(model: model)
                }
            case .finderSelection(let apps):
                FinderSelectionView(apps: apps)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .translucentWindowBackground()
        .sheet(isPresented: showOnboarding) {
            OnboardingView { hasOnboarded = true }
        }
        .sheet(item: inspectorBinding) { app in
            NavigationStack { AppInspectorView(app: app) }
        }
        .sheet(isPresented: Binding(
            get: { updateManager.showUpdatePrompt && updateManager.latestVersion != nil },
            set: { updateManager.showUpdatePrompt = $0 }
        )) {
            if case .updateAvailable(let version) = updateManager.status {
                UpdatePromptView(
                    version: version,
                    releaseNotesHTML: updateManager.latestReleaseNotesHTML,
                    onUpdateNow: {
                        updateManager.showUpdatePrompt = false
                        updateManager.checkForUpdates()
                    },
                    onLater: {
                        updateManager.showUpdatePrompt = false
                    }
                )
            }
        }
        .task {
            if !coordinator.launchedFromFinder {
                updateManager.checkForUpdatesInBackground()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, case .browser = coordinator.route,
               !coordinator.browserModel.isScanning {
                Task { await coordinator.browserModel.load() }
            }
        }
    }

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !hasOnboarded && !coordinator.launchedFromFinder },
            set: { if !$0 { hasOnboarded = true } }
        )
    }

    private var inspectorBinding: Binding<AppInfo?> {
        Binding(
            get: { coordinator.inspectorApp },
            set: { coordinator.inspectorApp = $0 }
        )
    }
}
