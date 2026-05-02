import SwiftUI
import AppKit

@main
struct VibeTypeMacApp: App {
    @State private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appState)
                .frame(minWidth: 480, minHeight: 360)
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController = nil
    }
}
