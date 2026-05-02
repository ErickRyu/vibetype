import AppKit
import SwiftUI

/// LSUIElement(액세서리) 앱에서 SwiftUI `Settings` scene이 메뉴바에서
/// 안정적으로 안 열리는 케이스를 우회하기 위해, 직접 NSWindow를 만들고
/// SwiftUI 뷰를 호스팅한다.
@MainActor
final class SettingsWindowController {
    private var windowController: NSWindowController?

    func show() {
        if let wc = windowController, let window = wc.window, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        if windowController == nil {
            createWindow()
        }
        NSApp.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func createWindow() {
        let hosting = NSHostingController(
            rootView: SettingsView()
                .environment(AppState.shared)
                .frame(minWidth: 540, minHeight: 420)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "VibeType 설정"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        windowController = NSWindowController(window: window)
    }
}
