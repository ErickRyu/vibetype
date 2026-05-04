import Foundation

public struct WhisperModelInfo: Sendable, Identifiable, Hashable {
    public let id: String
    public let displayName: String
    /// WhisperKit이 인식하는 모델 이름 (HF repo 또는 변환 ID).
    public let whisperKitName: String
    public let approxSizeBytes: Int64
    public let recommendedRAMGB: Int
    public let supportsKorean: Bool
    public let notes: String

    public init(
        id: String,
        displayName: String,
        whisperKitName: String,
        approxSizeBytes: Int64,
        recommendedRAMGB: Int,
        supportsKorean: Bool,
        notes: String = ""
    ) {
        self.id = id
        self.displayName = displayName
        self.whisperKitName = whisperKitName
        self.approxSizeBytes = approxSizeBytes
        self.recommendedRAMGB = recommendedRAMGB
        self.supportsKorean = supportsKorean
        self.notes = notes
    }
}

public enum VibeTypeWhisperRegistry {
    public static let largeV3Turbo = WhisperModelInfo(
        id: "openai_whisper-large-v3_turbo_954MB",
        displayName: "Whisper large-v3 turbo (954MB)",
        whisperKitName: "openai_whisper-large-v3_turbo_954MB",
        approxSizeBytes: 950_000_000,
        recommendedRAMGB: 8,
        supportsKorean: true,
        notes: "기본 추천. 950MB int8, 한국어 우수, 실시간보다 빠름."
    )

    public static let largeV3 = WhisperModelInfo(
        id: "openai_whisper-large-v3_947MB",
        displayName: "Whisper large-v3 (947MB)",
        whisperKitName: "openai_whisper-large-v3_947MB",
        approxSizeBytes: 950_000_000,
        recommendedRAMGB: 12,
        supportsKorean: true,
        notes: "비-turbo 정확도, turbo와 동일 크기."
    )

    public static let largeV3Full = WhisperModelInfo(
        id: "openai_whisper-large-v3",
        displayName: "Whisper large-v3 (full)",
        whisperKitName: "openai_whisper-large-v3",
        approxSizeBytes: 3_000_000_000,
        recommendedRAMGB: 12,
        supportsKorean: true,
        notes: "양자화 없는 풀 모델. RAM 큼, 정확도 최고."
    )

    public static let small = WhisperModelInfo(
        id: "openai_whisper-small",
        displayName: "Whisper small",
        whisperKitName: "openai_whisper-small",
        approxSizeBytes: 500_000_000,
        recommendedRAMGB: 4,
        supportsKorean: true,
        notes: "8GB Mac / 빠른 응답 필요 시."
    )

    public static let base = WhisperModelInfo(
        id: "openai_whisper-base",
        displayName: "Whisper base",
        whisperKitName: "openai_whisper-base",
        approxSizeBytes: 150_000_000,
        recommendedRAMGB: 4,
        supportsKorean: true,
        notes: "초경량, 한국어 정확도 보통."
    )

    public static let tiny = WhisperModelInfo(
        id: "openai_whisper-tiny",
        displayName: "Whisper tiny",
        whisperKitName: "openai_whisper-tiny",
        approxSizeBytes: 75_000_000,
        recommendedRAMGB: 4,
        supportsKorean: false,
        notes: "최소 모델, 한국어 정확도 떨어짐. 영어/테스트용."
    )

    public static let all: [WhisperModelInfo] = [
        largeV3Turbo,
        largeV3,
        largeV3Full,
        small,
        base,
        tiny,
    ]

    public static let `default` = largeV3Turbo

    public static func model(byID id: String) -> WhisperModelInfo? {
        all.first(where: { $0.id == id })
    }

    public static func recommended(forSystemRAMGB ramGB: Int) -> WhisperModelInfo {
        if ramGB >= 12 { return largeV3Turbo }
        if ramGB >= 8 { return largeV3Turbo }
        return small
    }

    /// WhisperKit이 모델을 다운로드해 두는 캐시 부모 디렉토리.
    /// `~/Library/Application Support/VibeType/whisperkit/`로 두어 macOS Sonoma+의
    /// Documents TCC 다이얼로그를 회피한다. WhisperKitConfig.modelFolder로 전달된다.
    public static func cacheBaseDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        return appSupport
            .appendingPathComponent("VibeType", isDirectory: true)
            .appendingPathComponent("whisperkit", isDirectory: true)
    }

    /// 특정 모델의 캐시 디렉토리.
    public static func cacheDirectory(for model: WhisperModelInfo) -> URL {
        cacheBaseDirectory().appendingPathComponent(model.whisperKitName, isDirectory: true)
    }

    /// v0.1.0까지 사용한 ~/Documents/huggingface/... 경로. 마이그레이션 source로만 사용.
    public static func legacyDocumentsDirectory(for model: WhisperModelInfo) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        return documents
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("argmaxinc", isDirectory: true)
            .appendingPathComponent("whisperkit-coreml", isDirectory: true)
            .appendingPathComponent(model.whisperKitName, isDirectory: true)
    }

    /// 모델이 사용자 기기에 이미 다운로드되어 있는지 검사.
    /// 캐시 디렉토리에 .mlmodelc 번들이 하나라도 존재하면 true.
    public static func isModelCached(_ model: WhisperModelInfo) -> Bool {
        isModelCached(at: cacheDirectory(for: model))
    }

    private static func isModelCached(at dir: URL) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        guard let contents = try? fm.contentsOfDirectory(atPath: dir.path) else {
            return false
        }
        return contents.contains(where: { $0.hasSuffix(".mlmodelc") })
    }

    /// 새 캐시 위치가 비어 있고 v0.1.0 ~/Documents 위치에 모델이 있으면 이동을 시도한다.
    /// Documents TCC가 거부하면 try?로 silent 무시 — 새 위치에서 다시 다운로드된다.
    public static func migrateCacheIfNeeded(for model: WhisperModelInfo) {
        let new = cacheDirectory(for: model)
        if isModelCached(at: new) { return }

        let old = legacyDocumentsDirectory(for: model)
        guard isModelCached(at: old) else { return }

        let fm = FileManager.default
        try? fm.createDirectory(at: cacheBaseDirectory(), withIntermediateDirectories: true)
        try? fm.moveItem(at: old, to: new)
    }
}
