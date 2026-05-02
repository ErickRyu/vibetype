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
    /// 진행률 콜백은 토큰 생성에 따라 0~1 값을 받음. WhisperKit의 chunk 기반
    /// progress는 짧은 오디오에서 무용지물이라 sampleLength 대비 token 수로 계산.
    public func transcribe(
        audioArray: [Float],
        language: String? = "ko",
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> String {
        guard let whisper else { throw WhisperEngineError.modelNotLoaded }
        guard !audioArray.isEmpty else { throw WhisperEngineError.invalidAudio }

        let sampleLength = 224
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: language,
            temperature: 0.0,
            temperatureIncrementOnFallback: 0.2,
            temperatureFallbackCount: 3,
            sampleLength: sampleLength,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            chunkingStrategy: .vad
        )

        do {
            let results = try await whisper.transcribe(audioArray: audioArray, decodeOptions: options) { progress in
                let tokenCount = progress.tokens.count
                let fraction = min(1.0, Double(tokenCount) / Double(sampleLength))
                onProgress?(fraction)
                return nil  // continue generation
            }
            onProgress?(1.0)
            return results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw WhisperEngineError.transcriptionFailed(String(describing: error))
        }
    }
}
