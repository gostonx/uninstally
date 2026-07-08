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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(coordinator)
                .onOpenURL { coordinator.open($0) }
                .onAppear { appDelegate.attach(coordinator) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Refresh Applications") {
                    Task { await coordinator.browserModel.load() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
