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
    private var hud: DictationHUDWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()

        let dictation = DictationCoordinator(appState: AppState.shared)
        let textRewrite = ActionCoordinator(appState: AppState.shared)
        self.dictation = dictation
        self.textRewrite = textRewrite

        // 첫 Fn 사용 시점에 다이얼로그가 뜨지 않도록 앱 시작 시 권한 요청.
        Task { @MainActor in
            await dictation.prefetchPermission()
        }

        let hud = DictationHUDWindow()
        hud.onCancel = { [weak dictation] in dictation?.cancelRecording() }
        self.hud = hud

        // 상태 변화를 메뉴바 + HUD 양쪽에 전달.
        dictation.onStateChange = { [weak self] state in
            self?.menuBarController?.updateDictationState(state)
            self?.hud?.update(state: state)
        }

        // Fn 키 push-to-talk
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

        // KeyboardShortcuts: 보너스 텍스트 액션 (디폴트 미할당) + 옵션 dictation 토글
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
        hud = nil
        menuBarController = nil
    }
}
