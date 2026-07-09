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
                UninstallView(model: model)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            case .batch(let model):
                BatchUninstallView(model: model)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .finderSelection(let apps):
                FinderSelectionView(apps: apps)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: coordinator.route)
        .frame(minWidth: 720, minHeight: 480)
        .translucentWindowBackground()
        .sheet(isPresented: showOnboarding) {
            OnboardingView { hasOnboarded = true }
        }
        .task {
            // Check for updates on launch (standalone sessions only), in addition
            // to Sparkle's own scheduled 24-hour checks.
            if !coordinator.launchedFromFinder {
                updateManager.checkForUpdatesInBackground()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, case .browser = coordinator.route,
               !coordinator.browserModel.apps.isEmpty,
               !coordinator.browserModel.isScanning {
                Task { await coordinator.browserModel.load() }
            }
        }
    }

    /// Onboarding only appears for normal standalone launches, never for a
    /// one-shot Finder uninstall.
    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !hasOnboarded && !coordinator.launchedFromFinder },
            set: { if !$0 { hasOnboarded = true } }
        )
    }
}
