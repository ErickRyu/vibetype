import Foundation
@preconcurrency import WhisperKit

public enum WhisperEngineError: Error, Sendable {
    case modelNotLoaded
    case loadFailed(String)
    case transcriptionFailed(String)
    case invalidAudio
}

public actor WhisperEngine {
    public static let shared = WhisperEngine()

    private var whisper: WhisperKit?
    private var loadedModelID: String?

    public init() {}

    public var isLoaded: Bool { whisper != nil }
    public var currentModelID: String? { loadedModelID }

    /// 현재 진행 중인 transcribe의 진행률 (0.0 ~ 1.0).
    /// 호출자가 폴링해서 UI 갱신에 사용.
    public var currentProgressFraction: Double {
        whisper?.progress.fractionCompleted ?? 0
    }

    public func load(model: WhisperModelInfo) async throws {
        if loadedModelID == model.id, whisper != nil { return }

        do {
            let config = WhisperKitConfig(
                model: model.whisperKitName,
                verbose: false,
                logLevel: .error,
                prewarm: false,
                load: true,
                download: true
            )
            self.whisper = try await WhisperKit(config)
            self.loadedModelID = model.id
        } catch {
            throw WhisperEngineError.loadFailed(String(describing: error))
        }
    }

    public func unload() {
        whisper = nil
        loadedModelID = nil
    }

    /// 파일 경로 받아쓰기 (CLI 검증용).
    public func transcribe(audioPath: String, language: String? = "ko") async throws -> String {
        guard let whisper else { throw WhisperEngineError.modelNotLoaded }

        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: language,
            temperature: 0.0,
            temperatureIncrementOnFallback: 0.2,
            temperatureFallbackCount: 3,
            sampleLength: 224,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            chunkingStrategy: .vad
        )

        do {
            let results = try await whisper.transcribe(audioPath: audioPath, decodeOptions: options)
            return results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw WhisperEngineError.transcriptionFailed(String(describing: error))
        }
    }

    /// 메모리상의 16kHz mono float 샘플 배열 받아쓰기 (Mac 앱 마이크 입력).
    public func transcribe(audioArray: [Float], language: String? = "ko") async throws -> String {
        guard let whisper else { throw WhisperEngineError.modelNotLoaded }
        guard !audioArray.isEmpty else { throw WhisperEngineError.invalidAudio }

        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: language,
            temperature: 0.0,
            temperatureIncrementOnFallback: 0.2,
            temperatureFallbackCount: 3,
            sampleLength: 224,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            chunkingStrategy: .vad
        )

        do {
            let results = try await whisper.transcribe(audioArray: audioArray, decodeOptions: options)
            return results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw WhisperEngineError.transcriptionFailed(String(describing: error))
        }
    }
}
