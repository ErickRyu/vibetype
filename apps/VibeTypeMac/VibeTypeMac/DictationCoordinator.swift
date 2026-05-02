import AppKit
import OSLog
import VibeTypeCore

private let log = Logger(subsystem: "com.vibetype.mac", category: "Dictation")

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
        log.info("startRecording called, current state: \(String(describing: self.state))")
        guard state == .idle else {
            log.warning("startRecording skipped — state is \(String(describing: self.state))")
            return
        }
        Task { @MainActor in
            let granted = await AudioRecorder.requestPermission()
            guard granted else {
                log.error("microphone permission denied")
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
                log.info("recording started")
                self.transition(to: .recording)
            } catch {
                log.error("recording start failed: \(String(describing: error))")
                self.transition(to: .failed(String(describing: error)))
                NotificationPresenter.show(title: "녹음 시작 실패", body: String(describing: error))
                self.transition(to: .idle)
            }
        }
    }

    func stopRecordingAndProcess() {
        log.info("stopRecordingAndProcess called, current state: \(String(describing: self.state))")
        guard state == .recording else {
            log.warning("stop skipped — state is \(String(describing: self.state))")
            return
        }

        let samples: [Float]
        do {
            samples = try recorder.stop()
            log.info("recording stopped, sample count: \(samples.count)")
        } catch {
            log.error("recording stop failed: \(String(describing: error))")
            transition(to: .failed(String(describing: error)))
            transition(to: .idle)
            return
        }

        let durationSeconds = Double(samples.count) / 16_000.0
        log.info("recorded duration: \(durationSeconds)s")
        guard durationSeconds >= 0.4, !samples.isEmpty else {
            log.warning("recording too short (<400ms) or empty — skipping")
            NotificationPresenter.show(
                title: "녹음이 너무 짧습니다",
                body: "Fn 키를 좀 더 오래 누른 채 말해주세요 (최소 0.4초)."
            )
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
            log.info("whisper state: \(String(describing: appState.whisperState))")
            let raw: String
            do {
                if appState.whisperState != .ready {
                    NotificationPresenter.show(
                        title: "Whisper 모델 로드 중",
                        body: "첫 실행 시 5분 정도 걸립니다. 메뉴바 → 설정 → 받아쓰기 탭에서 진행 상황을 확인하세요. 로드가 끝난 뒤 다시 Fn 키를 누르면 됩니다."
                    )
                    log.info("triggering whisper load")
                    await appState.ensureWhisperLoaded()
                    guard appState.whisperState == .ready else {
                        log.error("whisper load failed: \(appState.lastError ?? "unknown")")
                        NotificationPresenter.show(
                            title: "Whisper 모델 로드 실패",
                            body: appState.lastError ?? "다시 시도해 주세요."
                        )
                        return
                    }
                }
                log.info("whisper transcribing...")
                raw = try await WhisperEngine.shared.transcribe(audioArray: samples, language: "ko")
                log.info("whisper transcribed: \(raw)")
            } catch {
                log.error("whisper failed: \(String(describing: error))")
                NotificationPresenter.show(title: "음성 인식 실패", body: String(describing: error))
                return
            }

            if DictationPostProcessor.shouldSkip(rawTranscript: raw) {
                log.warning("post-processor skipped — empty/short transcript")
                NotificationPresenter.show(
                    title: "인식 결과 없음",
                    body: "음성이 너무 작거나 짧았습니다. 다시 시도해 주세요."
                )
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

            // 3) 포커스된 앱에 삽입.
            // Pasteboard ⌘V를 우선 — Notes/WebView/Electron 등 다양한 앱에서 안정.
            // AX set은 일부 앱에서 silent no-op이라 마지막 폴백.
            self.transition(to: .typing)
            log.info("inserting text: '\(finalText)' (length: \(finalText.count))")
            let snapshot = ClipboardSnapshot.capture()
            do {
                try await PasteboardFallback.paste(finalText, restoring: snapshot)
                log.info("pasteboard paste succeeded")
            } catch {
                log.warning("pasteboard paste failed: \(String(describing: error)) — trying AX fallback")
                do {
                    try AccessibilityService.insertTextViaAX(finalText)
                    log.info("AX fallback succeeded")
                } catch {
                    log.error("both pasteboard and AX failed: \(String(describing: error))")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(finalText, forType: .string)
                    NotificationPresenter.show(
                        title: "텍스트 삽입 실패",
                        body: "결과(\(finalText.prefix(30))…)는 클립보드에 복사되었습니다. ⌘V로 붙여넣어 주세요."
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
