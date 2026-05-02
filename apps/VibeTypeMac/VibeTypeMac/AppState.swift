import Foundation
import Observation
import VibeTypeCore

enum ModelLoadState: Equatable, Sendable {
    case notLoaded
    case downloading(Double)
    case loading
    case ready
    case failed(String)
}

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    // Gemma (LLM 후처리용)
    var selectedModelID: String = VibeTypeModelRegistry.default.id {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: Self.modelKey) }
    }
    var modelState: ModelLoadState = .notLoaded

    // Whisper (STT용)
    var selectedWhisperID: String = VibeTypeWhisperRegistry.default.id {
        didSet { UserDefaults.standard.set(selectedWhisperID, forKey: Self.whisperKey) }
    }
    var whisperState: ModelLoadState = .notLoaded

    var lastError: String?

    /// Gemma 후처리(구두점/포맷 보정) 사용 여부.
    /// 디폴트 OFF — Whisper turbo 단독으로도 한국어 구두점/숫자/띄어쓰기가 양호하고,
    /// Gemma는 +1~3초 + ~1.5GB 비용 + 결과를 잘라낼 위험이 있음.
    var useGemmaPostProcessing: Bool = false {
        didSet { UserDefaults.standard.set(useGemmaPostProcessing, forKey: Self.gemmaToggleKey) }
    }

    private static let modelKey = "vibetype.selectedModel"
    private static let whisperKey = "vibetype.selectedWhisper"
    private static let gemmaToggleKey = "vibetype.useGemmaPostProcessing"

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.modelKey),
           VibeTypeModelRegistry.model(byID: saved) != nil {
            self.selectedModelID = saved
        }
        if let saved = UserDefaults.standard.string(forKey: Self.whisperKey),
           VibeTypeWhisperRegistry.model(byID: saved) != nil {
            self.selectedWhisperID = saved
        }
        // 키가 존재하면 그 값을, 없으면 디폴트(false) 유지.
        if UserDefaults.standard.object(forKey: Self.gemmaToggleKey) != nil {
            self.useGemmaPostProcessing = UserDefaults.standard.bool(forKey: Self.gemmaToggleKey)
        }
    }

    var selectedModel: ModelInfo {
        VibeTypeModelRegistry.model(byID: selectedModelID) ?? VibeTypeModelRegistry.default
    }

    var selectedWhisper: WhisperModelInfo {
        VibeTypeWhisperRegistry.model(byID: selectedWhisperID) ?? VibeTypeWhisperRegistry.default
    }

    func ensureModelLoaded() async {
        let model = selectedModel
        modelState = .downloading(0)
        do {
            try await LLMEngine.shared.load(model: model) { [weak self] progress in
                Task { @MainActor in
                    self?.modelState = .downloading(progress.fractionCompleted)
                }
            }
            modelState = .ready
        } catch {
            let message = String(describing: error)
            modelState = .failed(message)
            lastError = message
        }
    }

    func switchModel(to id: String) async {
        guard id != selectedModelID else { return }
        selectedModelID = id
        await LLMEngine.shared.unload()
        modelState = .notLoaded
        await ensureModelLoaded()
    }

    func ensureWhisperLoaded() async {
        let model = selectedWhisper
        whisperState = .loading
        do {
            try await WhisperEngine.shared.load(model: model)
            whisperState = .ready
        } catch {
            let message = String(describing: error)
            whisperState = .failed(message)
            lastError = message
        }
    }

    func switchWhisper(to id: String) async {
        guard id != selectedWhisperID else { return }
        selectedWhisperID = id
        await WhisperEngine.shared.unload()
        whisperState = .notLoaded
        await ensureWhisperLoaded()
    }
}
