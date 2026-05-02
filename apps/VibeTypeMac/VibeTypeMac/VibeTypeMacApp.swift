import SwiftUI
import AppKit

@main
struct VibeTypeMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(AppState.shared)
                .frame(minWidth: 520, minHeight: 380)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("VibeType 정보") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var coordinator: ActionCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()

        let coordinator = ActionCoordinator(appState: AppState.shared)
        self.coordinator = coordinator
        self.hotkeyManager = HotkeyManager { [weak coordinator] action in
            coordinator?.invoke(action)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager = nil
        coordinator = nil
        menuBarController = nil
    }
}
