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
    private var lastUsedAt: Date?

    public init() {}

    public var isLoaded: Bool { whisper != nil }
    public var currentModelID: String? { loadedModelID }

    /// 현재 진행 중인 transcribe의 진행률 (0.0 ~ 1.0).
    /// 호출자가 폴링해서 UI 갱신에 사용.
    public var currentProgressFraction: Double {
        whisper?.progress.fractionCompleted ?? 0
    }

    /// 마지막 사용 시점으로부터 경과한 초. 사용 기록이 없으면 nil.
    public var secondsSinceLastUse: TimeInterval? {
        guard let lastUsedAt else { return nil }
        return Date().timeIntervalSince(lastUsedAt)
    }

    /// idle 시간이 threshold 이상이면 모델을 메모리에서 해제하고 true 반환.
    public func unloadIfIdle(thresholdSeconds: TimeInterval) -> Bool {
        guard whisper != nil,
              let elapsed = secondsSinceLastUse,
              elapsed >= thresholdSeconds else {
            return false
        }
        whisper = nil
        loadedModelID = nil
        lastUsedAt = nil
        return true
    }

    public func load(model: WhisperModelInfo) async throws {
        if loadedModelID == model.id, whisper != nil { return }

        // v0.1.0 사용자의 기존 ~/Documents 캐시를 새 Application Support 위치로 silent 이동.
        VibeTypeWhisperRegistry.migrateCacheIfNeeded(for: model)

        do {
            let config = WhisperKitConfig(
                model: model.whisperKitName,
                modelFolder: VibeTypeWhisperRegistry.cacheDirectory(for: model).path,
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
        lastUsedAt = nil
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
            lastUsedAt = Date()
            return results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            lastUsedAt = Date()
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
            lastUsedAt = Date()
            return results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            lastUsedAt = Date()
            throw WhisperEngineError.transcriptionFailed(String(describing: error))
        }
    }
}
