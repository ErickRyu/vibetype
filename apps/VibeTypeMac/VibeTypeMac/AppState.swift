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

    private static let modelKey = "vibetype.selectedModel"
    private static let whisperKey = "vibetype.selectedWhisper"

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.modelKey),
           VibeTypeModelRegistry.model(byID: saved) != nil {
            self.selectedModelID = saved
        }
        if let saved = UserDefaults.standard.string(forKey: Self.whisperKey),
           VibeTypeWhisperRegistry.model(byID: saved) != nil {
            self.selectedWhisperID = saved
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
