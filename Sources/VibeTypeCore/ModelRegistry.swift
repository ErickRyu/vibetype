import Foundation

public struct ModelInfo: Sendable, Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let huggingFaceID: String
    public let approxSizeBytes: Int64
    public let recommendedRAMGB: Int
    public let supportsIOS: Bool
    public let notes: String

    public init(
        id: String,
        displayName: String,
        huggingFaceID: String,
        approxSizeBytes: Int64,
        recommendedRAMGB: Int,
        supportsIOS: Bool,
        notes: String = ""
    ) {
        self.id = id
        self.displayName = displayName
        self.huggingFaceID = huggingFaceID
        self.approxSizeBytes = approxSizeBytes
        self.recommendedRAMGB = recommendedRAMGB
        self.supportsIOS = supportsIOS
        self.notes = notes
    }
}

public enum VibeTypeModelRegistry {
    public static let gemma3n_E4B = ModelInfo(
        id: "gemma-3n-e4b-it-lm-4bit",
        displayName: "Gemma 3n E4B (4-bit)",
        huggingFaceID: "mlx-community/gemma-3n-E4B-it-lm-4bit",
        approxSizeBytes: 2_400_000_000,
        recommendedRAMGB: 12,
        supportsIOS: true,
        notes: "기본 추천. PLE로 4B 효과, 메모리 효율 우수, iOS 호환."
    )

    public static let gemma3n_E2B = ModelInfo(
        id: "gemma-3n-e2b-it-lm-4bit",
        displayName: "Gemma 3n E2B (4-bit)",
        huggingFaceID: "mlx-community/gemma-3n-E2B-it-lm-4bit",
        approxSizeBytes: 1_500_000_000,
        recommendedRAMGB: 8,
        supportsIOS: true,
        notes: "iOS 키보드 / 8GB Mac 폴백."
    )

    public static let gemma2_2B = ModelInfo(
        id: "gemma-2-2b-it-4bit",
        displayName: "Gemma 2 2B (4-bit)",
        huggingFaceID: "mlx-community/gemma-2-2b-it-4bit",
        approxSizeBytes: 1_500_000_000,
        recommendedRAMGB: 8,
        supportsIOS: true,
        notes: "검증된 안정 모델, 최후 폴백."
    )

    public static let gemma2_9B = ModelInfo(
        id: "gemma-2-9b-it-4bit",
        displayName: "Gemma 2 9B (4-bit)",
        huggingFaceID: "mlx-community/gemma-2-9b-it-4bit",
        approxSizeBytes: 5_500_000_000,
        recommendedRAMGB: 24,
        supportsIOS: false,
        notes: "고품질, 24GB+ Mac 권장."
    )

    public static let gemma3_1B = ModelInfo(
        id: "gemma-3-1b-it-qat-4bit",
        displayName: "Gemma 3 1B QAT (4-bit)",
        huggingFaceID: "mlx-community/gemma-3-1b-it-qat-4bit",
        approxSizeBytes: 800_000_000,
        recommendedRAMGB: 6,
        supportsIOS: true,
        notes: "최소형, 빠르나 품질 제한적."
    )

    public static let all: [ModelInfo] = [
        gemma3n_E4B,
        gemma3n_E2B,
        gemma2_2B,
        gemma2_9B,
        gemma3_1B,
    ]

    public static let `default` = gemma3n_E4B

    public static func model(byID id: String) -> ModelInfo? {
        all.first(where: { $0.id == id })
    }

    public static func recommended(forSystemRAMGB ramGB: Int, isIOS: Bool) -> ModelInfo {
        if isIOS {
            return ramGB >= 8 ? gemma3n_E2B : gemma3_1B
        }
        if ramGB >= 24 { return gemma2_9B }
        if ramGB >= 12 { return gemma3n_E4B }
        if ramGB >= 8 { return gemma3n_E2B }
        return gemma3_1B
    }
}
