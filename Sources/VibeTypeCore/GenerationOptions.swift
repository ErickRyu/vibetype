import Foundation

public struct GenerationOptions: Sendable {
    public var temperature: Float
    public var topP: Float
    public var maxTokens: Int
    public var repetitionPenalty: Float?

    public init(
        temperature: Float = 0.5,
        topP: Float = 0.9,
        maxTokens: Int = 512,
        repetitionPenalty: Float? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.repetitionPenalty = repetitionPenalty
    }

    public static let improve = GenerationOptions(temperature: 0.4, maxTokens: 512)
    public static let fixGrammar = GenerationOptions(temperature: 0.1, maxTokens: 512)
    public static let translate = GenerationOptions(temperature: 0.3, maxTokens: 768)
    public static let summarize = GenerationOptions(temperature: 0.3, maxTokens: 256)

    public static func defaults(for action: TextAction) -> GenerationOptions {
        switch action {
        case .improve:                       return .improve
        case .fixGrammar:                    return .fixGrammar
        case .translateKo, .translateEn:     return .translate
        case .summarize:                     return .summarize
        }
    }
}
