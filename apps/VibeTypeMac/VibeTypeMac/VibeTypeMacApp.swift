import SwiftUI
import AppKit
import VibeTypeCore

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
    private var textRewrite: TextRewriteCoordinator?
    private var hud: DictationHUDWindow?
    private var idleMonitor: IdleUnloadMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()

        let dictation = DictationCoordinator(appState: AppState.shared)
        let textRewrite = TextRewriteCoordinator(appState: AppState.shared)
        self.dictation = dictation
        self.textRewrite = textRewrite

        // 첫 Fn 사용 시점에 다이얼로그가 뜨지 않도록 앱 시작 시 권한 요청.
        Task { @MainActor in
            await dictation.prefetchPermission()
        }

        // 캐시에 모델이 있으면 백그라운드에서 자동 로드 (콜드 스타트 단축).
        // 첫 실행(다운로드 미완료)에서는 자동 트리거하지 않음 — 사용자가 Settings에서 명시 시작.
        Task { @MainActor in
            let state = AppState.shared
            // v0.1.0 ~/Documents 캐시를 새 위치로 silent 마이그레이션.
            VibeTypeWhisperRegistry.migrateCacheIfNeeded(for: state.selectedWhisper)
            guard state.whisperState == .notLoaded,
                  VibeTypeWhisperRegistry.isModelCached(state.selectedWhisper) else { return }
            await state.ensureWhisperLoaded()
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

        // idle 시 Whisper 자동 unload (15분 비활성).
        let idleMonitor = IdleUnloadMonitor(appState: AppState.shared)
        idleMonitor.start()
        self.idleMonitor = idleMonitor
    }

    func applicationWillTerminate(_ notification: Notification) {
        idleMonitor?.stop()
        idleMonitor = nil
        fnMonitor?.stop()
        fnMonitor = nil
        hotkeyManager = nil
        dictation = nil
        textRewrite = nil
        hud = nil
        menuBarController = nil
    }
}
