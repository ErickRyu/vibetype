import Foundation
import OSLog
import VibeTypeCore

private let log = Logger(subsystem: "com.vibetype.mac", category: "IdleUnload")

/// 일정 시간 동안 받아쓰기가 없으면 Whisper 모델을 메모리에서 자동 해제.
/// 1GB 가까운 CoreML이 무기한 상주하지 않도록.
@MainActor
final class IdleUnloadMonitor {
    private let thresholdSeconds: TimeInterval
    private let checkInterval: TimeInterval
    private weak var appState: AppState?
    private var timer: Timer?

    init(
        appState: AppState,
        thresholdSeconds: TimeInterval = 15 * 60,
        checkInterval: TimeInterval = 60
    ) {
        self.appState = appState
        self.thresholdSeconds = thresholdSeconds
        self.checkInterval = checkInterval
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() async {
        let unloaded = await WhisperEngine.shared.unloadIfIdle(thresholdSeconds: thresholdSeconds)
        guard unloaded else { return }
        log.info("Whisper unloaded after \(self.thresholdSeconds)s idle")
        if appState?.whisperState == .ready {
            appState?.whisperState = .notLoaded
        }
    }
}
