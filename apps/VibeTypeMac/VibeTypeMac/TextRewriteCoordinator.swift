import AppKit
import VibeTypeCore

/// 사용자가 텍스트 다듬기 단축키를 누르면:
/// 1) AX로 선택 텍스트 읽기 (실패 시 Pasteboard 폴백)
/// 2) 모델이 준비되어 있는지 확인 (필요 시 로드)
/// 3) Gemma 추론으로 결과 텍스트 생성
/// 4) AX로 교체 (실패 시 ⌘V 폴백)
@MainActor
final class TextRewriteCoordinator {
    private let appState: AppState
    private var inFlight: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
    }

    func invoke(_ action: TextAction) {
        // 동시 호출 방지: 이전 작업이 진행 중이면 무시.
        if let task = inFlight, !task.isCancelled, !task.isHandled {
            return
        }

        inFlight = Task { @MainActor [appState] in
            defer { self.inFlight = nil }

            // 1) 권한 게이트
            guard AccessibilityService.hasPermission else {
                AccessibilityService.requestPermissionIfNeeded()
                NotificationPresenter.show(
                    title: "Accessibility 권한 필요",
                    body: "VibeType은 선택 텍스트를 읽고 교체하기 위해 Accessibility 권한이 필요합니다."
                )
                return
            }

            // 2) 선택 텍스트 캡처 (AX 우선 → Pasteboard 폴백)
            let captured: (String, ClipboardSnapshot?)
            do {
                let text = try AccessibilityService.readSelectionViaAX()
                captured = (text, nil)
            } catch {
                do {
                    let result = try await PasteboardFallback.captureSelection()
                    captured = (result.text, result.savedSnapshot)
                } catch {
                    NotificationPresenter.show(
                        title: "선택 텍스트 없음",
                        body: "텍스트를 먼저 선택하고 단축키를 다시 눌러주세요."
                    )
                    return
                }
            }
            let (selection, restoreSnapshot) = captured

            // 3) 모델 준비
            if appState.modelState != .ready {
                await appState.ensureModelLoaded()
                guard appState.modelState == .ready else {
                    if let snapshot = restoreSnapshot { snapshot.restore() }
                    NotificationPresenter.show(
                        title: "모델 로드 실패",
                        body: appState.lastError ?? "모델을 다시 로드해 주세요."
                    )
                    return
                }
            }

            // 4) 추론
            let prompt = PromptBuilder.build(action: action, input: selection)
            let options = GenerationOptions.defaults(for: action)
            var result = ""
            do {
                for try await token in LLMEngine.shared.stream(prompt: prompt, options: options) {
                    result += token
                }
            } catch {
                if let snapshot = restoreSnapshot { snapshot.restore() }
                NotificationPresenter.show(
                    title: "추론 실패",
                    body: String(describing: error)
                )
                return
            }

            let output = result.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !output.isEmpty else {
                if let snapshot = restoreSnapshot { snapshot.restore() }
                return
            }

            // 5) 교체 (AX 우선 → ⌘V 폴백)
            do {
                try AccessibilityService.replaceSelectionViaAX(with: output)
                if let snapshot = restoreSnapshot { snapshot.restore() }
            } catch {
                let snapshot = restoreSnapshot ?? ClipboardSnapshot.capture()
                do {
                    try await PasteboardFallback.paste(output, restoring: snapshot)
                } catch {
                    NotificationPresenter.show(
                        title: "텍스트 교체 실패",
                        body: "결과는 클립보드에 복사되었습니다."
                    )
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                }
            }
        }
    }
}

private extension Task where Success == Void, Failure == Never {
    var isHandled: Bool { isCancelled }
}

@MainActor
enum NotificationPresenter {
    static func show(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .informational
        alert.addButton(withTitle: "확인")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
