import AppKit
import VibeTypeCore

/// 음성 받아쓰기 파이프라인 오케스트레이션.
/// 1) 마이크 녹음 (push-to-talk: keyDown → start, keyUp → stop)
/// 2) Whisper로 전사
/// 3) Gemma로 구두점/포맷 후처리
/// 4) AX로 포커스된 앱에 삽입 (한글 IME 우회), 실패 시 Pasteboard ⌘V 폴백
@MainActor
final class DictationCoordinator {
    enum State: Sendable, Equatable {
        case idle
        case recording
        case transcribing
        case postProcessing
        case typing
        case failed(String)
    }

    private let appState: AppState
    private let recorder = AudioRecorder()
    private(set) var state: State = .idle
    private var pipelineTask: Task<Void, Never>?

    /// State 변화에 반응할 옵저버 (메뉴바 인디케이터 갱신용).
    var onStateChange: (@MainActor (State) -> Void)?

    init(appState: AppState) {
        self.appState = appState
    }

    func startRecording() {
        guard state == .idle else { return }
        Task { @MainActor in
            // 권한 체크
            let granted = await AudioRecorder.requestPermission()
            guard granted else {
                self.transition(to: .failed("마이크 권한이 없습니다."))
                NotificationPresenter.show(
                    title: "마이크 권한 필요",
                    body: "System Settings → Privacy & Security → Microphone에서 VibeType을 허용해 주세요."
                )
                self.transition(to: .idle)
                return
            }

            do {
                try self.recorder.start()
                self.transition(to: .recording)
            } catch {
                self.transition(to: .failed(String(describing: error)))
                NotificationPresenter.show(title: "녹음 시작 실패", body: String(describing: error))
                self.transition(to: .idle)
            }
        }
    }

    func stopRecordingAndProcess() {
        guard state == .recording else { return }

        let samples: [Float]
        do {
            samples = try recorder.stop()
        } catch {
            transition(to: .failed(String(describing: error)))
            transition(to: .idle)
            return
        }

        // 너무 짧은 발화 무시 (Whisper 환각 방지)
        let durationSeconds = Double(samples.count) / 16_000.0
        guard durationSeconds >= 0.4, !samples.isEmpty else {
            transition(to: .idle)
            return
        }

        pipelineTask = Task { @MainActor [appState] in
            defer {
                self.pipelineTask = nil
                self.transition(to: .idle)
            }

            // 1) Whisper 전사
            self.transition(to: .transcribing)
            let raw: String
            do {
                if appState.whisperState != .ready {
                    await appState.ensureWhisperLoaded()
                    guard appState.whisperState == .ready else {
                        NotificationPresenter.show(
                            title: "Whisper 모델 로드 실패",
                            body: appState.lastError ?? "다시 시도해 주세요."
                        )
                        return
                    }
                }
                raw = try await WhisperEngine.shared.transcribe(audioArray: samples, language: "ko")
            } catch {
                NotificationPresenter.show(title: "음성 인식 실패", body: String(describing: error))
                return
            }

            if DictationPostProcessor.shouldSkip(rawTranscript: raw) {
                return
            }

            // 2) Gemma 후처리
            self.transition(to: .postProcessing)
            let cleaned: String
            do {
                if appState.modelState != .ready {
                    await appState.ensureModelLoaded()
                }
                if appState.modelState == .ready {
                    let prompt = DictationPostProcessor.makePrompt(rawTranscript: raw)
                    var result = ""
                    for try await token in LLMEngine.shared.stream(prompt: prompt, options: .dictationCleanup) {
                        result += token
                    }
                    cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    // Gemma 미준비 시 raw로 fallback
                    cleaned = raw
                }
            } catch {
                // 후처리 실패해도 raw는 입력 (degrade gracefully)
                cleaned = raw
            }

            let finalText = cleaned.isEmpty ? raw : cleaned
            guard !finalText.isEmpty else { return }

            // 3) 포커스된 앱에 삽입 (AX → Pasteboard ⌘V)
            self.transition(to: .typing)
            do {
                try AccessibilityService.insertTextViaAX(finalText)
            } catch {
                let snapshot = ClipboardSnapshot.capture()
                do {
                    try await PasteboardFallback.paste(finalText, restoring: snapshot)
                } catch {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(finalText, forType: .string)
                    NotificationPresenter.show(
                        title: "텍스트 삽입 실패",
                        body: "결과는 클립보드에 복사되었습니다."
                    )
                }
            }
        }
    }

    func cancelRecording() {
        recorder.cancel()
        pipelineTask?.cancel()
        pipelineTask = nil
        transition(to: .idle)
    }

    private func transition(to newState: State) {
        state = newState
        onStateChange?(newState)
    }
}
