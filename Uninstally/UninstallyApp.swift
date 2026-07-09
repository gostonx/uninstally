import SwiftUI

/// Uninstally — a native macOS uninstaller by Codenta.
///
/// The app deliberately runs as an *accessory* (no Dock icon, no menu-bar item):
/// it appears only when launched directly or from Finder. The single
/// `WindowGroup` hosts either the standalone browser or a dedicated uninstall
/// flow, decided by the `AppCoordinator`.
@main
struct UninstallyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = AppCoordinator()
    @State private var appSidebarManager = AppSidebarManager()
    @State private var customTabManager = CustomTabManager()
    @State private var updateManager = UpdateManager()
    @State private var historyStore = HistoryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(coordinator)
                .environment(appSidebarManager)
                .environment(customTabManager)
                .environment(updateManager)
                .environment(historyStore)
                .onOpenURL { coordinator.open($0) }
                .onAppear {
                    appDelegate.attach(coordinator)
                    historyStore.prune()
                }
        }
        .modelContainer(historyStore.container)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1000, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
            SidebarCommands()
            CommandGroup(after: .toolbar) {
                Button("Refresh Applications") {
                    Task { await coordinator.browserModel.load() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(updateManager)
                .environment(historyStore)
        }
        .modelContainer(historyStore.container)
    }
}
