import SwiftUI
import AppKit

@main
struct VibeTypeMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // LSUIElement 앱이라 SwiftUI Scene은 형식적으로만 둔다.
    // 실제 설정 윈도우는 SettingsWindowController가 NSWindow로 띄운다.
    var body: some Scene {
        Settings { EmptyView() }
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
