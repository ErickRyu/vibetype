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
        /// progress: 0.0 ~ 1.0 (Whisper progress KVO에서 폴링)
        case transcribing(progress: Double)
        case postProcessing
        case typing
        case failed(String)
    }

    private let appState: AppState
    private let recorder = AudioRecorder()
    private(set) var state: State = .idle
    private var pipelineTask: Task<Void, Never>?
    /// 같은 세션에서 권한 알림을 반복 표시하지 않도록 캐시.
    private var didWarnPermissionDenied = false
    /// 권한 요청 도중 추가 Fn 입력이 들어와도 무시.
    private var permissionRequestInFlight = false
    /// ad-hoc 서명 환경에서 macOS가 매번 .notDetermined를 보고하더라도
    /// 한 세션에 권한 요청은 최대 1회만 트리거되도록 직접 캐시.
    private var hasRequestedPermissionThisSession = false

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
        // 권한 요청 진행 중이면 중복 호출 무시 (Fn 연타로 인한 다이얼로그 누적 방지).
        if permissionRequestInFlight {
            log.warning("permission request in flight, skipping")
            return
        }

        // 빠른 경로: 이미 권한이 .authorized면 다이얼로그 없이 즉시 시작.
        let status = AudioRecorder.permissionStatus
        if status == .denied || status == .restricted {
            log.error("microphone permission denied")
            if !didWarnPermissionDenied {
                didWarnPermissionDenied = true
                self.transition(to: .failed("마이크 권한 거부됨 — System Settings 확인"))
                openMicSettings()
                self.transition(to: .idle)
            } else {
                self.transition(to: .failed("마이크 권한 거부됨"))
                self.transition(to: .idle)
            }
            return
        }

        Task { @MainActor in
            // ad-hoc 서명 환경에서 macOS가 매번 .notDetermined로 보고할 수 있어
            // 세션당 최대 1회만 requestPermission 호출. 이미 요청한 적 있으면 그냥 시도.
            if status == .notDetermined && !self.hasRequestedPermissionThisSession {
                self.permissionRequestInFlight = true
                self.hasRequestedPermissionThisSession = true
                let granted = await AudioRecorder.requestPermission()
                self.permissionRequestInFlight = false
                guard granted else {
                    log.error("microphone permission not granted")
                    if !self.didWarnPermissionDenied {
                        self.didWarnPermissionDenied = true
                        self.openMicSettings()
                    }
                    self.transition(to: .failed("마이크 권한 거부됨"))
                    self.transition(to: .idle)
                    return
                }
            }

            do {
                try self.recorder.start()
                log.info("recording started")
                self.transition(to: .recording)
            } catch {
                log.error("recording start failed: \(String(describing: error))")
                self.transition(to: .failed("녹음 시작 실패"))
                self.transition(to: .idle)
            }
        }
    }

    private func openMicSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 앱 시작 시 권한을 사전 요청해 첫 Fn 사용 때 다이얼로그가 뜨지 않도록.
    /// 거부되어도 didWarnPermissionDenied만 표시 후 silent.
    func prefetchPermission() async {
        let status = AudioRecorder.permissionStatus
        guard status == .notDetermined else { return }
        permissionRequestInFlight = true
        hasRequestedPermissionThisSession = true
        _ = await AudioRecorder.requestPermission()
        permissionRequestInFlight = false
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
            transition(to: .failed("너무 짧습니다. Fn을 더 오래 눌러 주세요."))
            transition(to: .idle)
            return
        }

        pipelineTask = Task { @MainActor [appState] in
            defer {
                self.pipelineTask = nil
                self.transition(to: .idle)
            }

            // 1) Whisper 전사 + 진행률 폴링
            self.transition(to: .transcribing(progress: 0))
            log.info("whisper state: \(String(describing: appState.whisperState))")
            let raw: String
            do {
                if appState.whisperState != .ready {
                    log.info("triggering whisper load")
                    await appState.ensureWhisperLoaded()
                    guard appState.whisperState == .ready else {
                        log.error("whisper load failed: \(appState.lastError ?? "unknown")")
                        self.transition(to: .failed("Whisper 모델 로드 실패"))
                        return
                    }
                }
                log.info("whisper transcribing...")
                raw = try await WhisperEngine.shared.transcribe(
                    audioArray: samples,
                    language: "ko"
                ) { fraction in
                    Task { @MainActor [weak self] in
                        self?.transition(to: .transcribing(progress: fraction))
                    }
                }
                log.info("whisper transcribed: \(raw)")
            } catch {
                log.error("whisper failed: \(String(describing: error))")
                self.transition(to: .failed("음성 인식 실패"))
                return
            }

            if DictationPostProcessor.shouldSkip(rawTranscript: raw) {
                log.warning("post-processor skipped — empty/short transcript")
                self.transition(to: .failed("인식 결과 없음"))
                return
            }

            // 2) Gemma 후처리 (옵션, 디폴트 OFF)
            let finalText: String
            if appState.useGemmaPostProcessing {
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
                        cleaned = raw
                    }
                } catch {
                    cleaned = raw
                }
                // 안전장치: Gemma가 결과를 너무 짧게 잘라내면 raw 사용.
                if cleaned.count < raw.count / 2 {
                    log.warning("post-processing returned suspiciously short text (\(cleaned.count) vs raw \(raw.count)) — using raw")
                    finalText = raw
                } else {
                    finalText = cleaned.isEmpty ? raw : cleaned
                }
            } else {
                log.info("gemma post-processing disabled — using whisper raw output")
                finalText = raw
            }

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
                    self.transition(to: .failed("결과를 클립보드에 복사했습니다. ⌘V로 붙여넣어 주세요."))
                    return
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
