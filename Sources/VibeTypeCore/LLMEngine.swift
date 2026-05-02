import Foundation
import MLX
import MLXLLM
import MLXLMCommon

public enum LLMEngineError: Error, Sendable {
    case modelNotLoaded
    case loadFailed(String)
    case generationCancelled
}

public struct LoadProgress: Sendable {
    public let fractionCompleted: Double
    public let bytesDownloaded: Int64
    public let totalBytes: Int64

    public init(fractionCompleted: Double, bytesDownloaded: Int64, totalBytes: Int64) {
        self.fractionCompleted = fractionCompleted
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
    }
}

public actor LLMEngine {
    public static let shared = LLMEngine()

    private var container: ModelContainer?
    private var loadedModelID: String?
    private var activeTask: Task<Void, Never>?

    public init() {}

    public var isLoaded: Bool { container != nil }
    public var currentModelID: String? { loadedModelID }

    public func load(
        model: ModelInfo,
        progress: (@Sendable (LoadProgress) -> Void)? = nil
    ) async throws {
        if loadedModelID == model.id, container != nil { return }

        // Conservative GPU cache to keep memory in check on smaller machines.
        MLX.GPU.set(cacheLimit: 64 * 1024 * 1024)

        let configuration = ModelConfiguration(id: model.huggingFaceID)
        do {
            let loaded = try await LLMModelFactory.shared.loadContainer(
                configuration: configuration
            ) { p in
                guard let progress else { return }
                progress(
                    LoadProgress(
                        fractionCompleted: p.fractionCompleted,
                        bytesDownloaded: p.completedUnitCount,
                        totalBytes: p.totalUnitCount
                    )
                )
            }
            self.container = loaded
            self.loadedModelID = model.id
        } catch {
            throw LLMEngineError.loadFailed(String(describing: error))
        }
    }

    public func unload() {
        container = nil
        loadedModelID = nil
        MLX.GPU.clearCache()
    }

    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
    }

    public func generate(
        prompt: PromptTemplate,
        options: GenerationOptions = GenerationOptions()
    ) async throws -> String {
        guard let container else { throw LLMEngineError.modelNotLoaded }

        let parameters = GenerateParameters(
            maxTokens: options.maxTokens,
            temperature: options.temperature,
            topP: options.topP,
            repetitionPenalty: options.repetitionPenalty
        )
        let session = ChatSession(
            container,
            instructions: prompt.system,
            generateParameters: parameters
        )
        return try await session.respond(to: prompt.user)
    }

    public nonisolated func stream(
        prompt: PromptTemplate,
        options: GenerationOptions = GenerationOptions()
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let stream = try await self.makeStream(prompt: prompt, options: options)
                    for try await token in stream {
                        if Task.isCancelled {
                            continuation.finish(throwing: LLMEngineError.generationCancelled)
                            return
                        }
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeStream(
        prompt: PromptTemplate,
        options: GenerationOptions
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let container else { throw LLMEngineError.modelNotLoaded }

        let parameters = GenerateParameters(
            maxTokens: options.maxTokens,
            temperature: options.temperature,
            topP: options.topP,
            repetitionPenalty: options.repetitionPenalty
        )
        let session = ChatSession(
            container,
            instructions: prompt.system,
            generateParameters: parameters
        )
        return session.streamResponse(to: prompt.user)
    }
}
