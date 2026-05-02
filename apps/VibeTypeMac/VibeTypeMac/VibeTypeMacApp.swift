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
    private var fnMonitor: FnKeyMonitor?
    private var dictation: DictationCoordinator?
    private var textRewrite: ActionCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()

        let dictation = DictationCoordinator(appState: AppState.shared)
        let textRewrite = ActionCoordinator(appState: AppState.shared)
        self.dictation = dictation
        self.textRewrite = textRewrite

        dictation.onStateChange = { [weak self] state in
            self?.menuBarController?.updateDictationState(state)
        }

        // Fn 키 push-to-talk: 누르면 녹음 시작, 떼면 처리.
        self.fnMonitor = FnKeyMonitor { [weak dictation] pressed in
            guard let dictation else { return }
            if pressed {
                if dictation.state == .idle {
                    dictation.startRecording()
                }
            } else {
                if dictation.state == .recording {
                    dictation.stopRecordingAndProcess()
                }
            }
        }

        // KeyboardShortcuts: 보너스 텍스트 액션만 (디폴트 미할당).
        // 받아쓰기는 Fn 키 모니터로 처리.
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
        fnMonitor?.stop()
        fnMonitor = nil
        hotkeyManager = nil
        dictation = nil
        textRewrite = nil
        menuBarController = nil
    }
}
