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
    var selectedModelID: String = VibeTypeModelRegistry.default.id {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: Self.modelKey) }
    }
    var modelState: ModelLoadState = .notLoaded
    var lastError: String?

    private static let modelKey = "vibetype.selectedModel"

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.modelKey),
           VibeTypeModelRegistry.model(byID: saved) != nil {
            self.selectedModelID = saved
        }
    }

    var selectedModel: ModelInfo {
        VibeTypeModelRegistry.model(byID: selectedModelID) ?? VibeTypeModelRegistry.default
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
}
