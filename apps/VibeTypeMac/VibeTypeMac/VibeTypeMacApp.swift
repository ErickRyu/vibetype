import SwiftUI
import AppKit

@main
struct VibeTypeMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var dictation: DictationCoordinator?
    private var textRewrite: ActionCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()

        let dictation = DictationCoordinator(appState: AppState.shared)
        let textRewrite = ActionCoordinator(appState: AppState.shared)
        self.dictation = dictation
        self.textRewrite = textRewrite

        // 메뉴바 인디케이터를 dictation 상태에 연결
        dictation.onStateChange = { [weak self] state in
            self?.menuBarController?.updateDictationState(state)
        }

        self.hotkeyManager = HotkeyManager(
            onDictationToggle: { [weak dictation] in
                guard let dictation else { return }
                if dictation.state == .recording {
                    dictation.stopRecordingAndProcess()
                } else if dictation.state == .idle {
                    dictation.startRecording()
                }
            },
            onTextAction: { [weak textRewrite] action in
                textRewrite?.invoke(action)
            }
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager = nil
        dictation = nil
        textRewrite = nil
        menuBarController = nil
    }
}
