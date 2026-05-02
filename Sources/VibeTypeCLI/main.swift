import Foundation
import VibeTypeCore

let args = Array(CommandLine.arguments.dropFirst())

func printUsage() {
    let usage = """
    VibeType CLI v\(VibeType.version)

    사용법:
      vibetype-cli dictate <wav-path>          음성 파일 받아쓰기 (Whisper)
      vibetype-cli <action> <text>             텍스트 다듬기 (보너스, Gemma)
      vibetype-cli models                      Gemma 모델 목록
      vibetype-cli whisper-models              Whisper 모델 목록

    받아쓰기:
      dictate <wav-path>   wav/m4a/mp3 등 → 한국어 전사

    텍스트 다듬기 액션 (보너스):
      improve         자연스럽게 다듬기
      fix             맞춤법/문법 교정
      translate-ko    한국어로 번역
      translate-en    영어로 번역
      summarize       요약

    예시:
      vibetype-cli dictate sample-ko.wav
      vibetype-cli improve "회의 좋았어"

    환경 변수:
      VIBETYPE_MODEL          Gemma 모델 ID (기본: \(VibeTypeModelRegistry.default.id))
      VIBETYPE_WHISPER_MODEL  Whisper 모델 ID (기본: \(VibeTypeWhisperRegistry.default.id))
    """
    print(usage)
}

func parseAction(_ raw: String) -> TextAction? {
    switch raw.lowercased() {
    case "improve":              return .improve
    case "fix", "grammar":       return .fixGrammar
    case "translate-ko", "ko":   return .translateKo
    case "translate-en", "en":   return .translateEn
    case "summarize", "summary": return .summarize
    default: return TextAction(rawValue: raw)
    }
}

func writeStderr(_ s: String) {
    FileHandle.standardError.write(Data(s.utf8))
}

final class ProgressLogger: @unchecked Sendable {
    private var lastPct: Int = -1
    private let lock = NSLock()
    func report(_ fraction: Double) {
        let pct = Int(fraction * 100)
        lock.lock(); defer { lock.unlock() }
        guard pct != lastPct else { return }
        lastPct = pct
        FileHandle.standardError.write(Data("\r  다운로드 \(pct)%   ".utf8))
    }
}

func run(action: TextAction, input: String, model: ModelInfo) async {
    let engine = LLMEngine.shared
    writeStderr("→ 모델 로드: \(model.displayName)\n")

    do {
        let logger = ProgressLogger()
        try await engine.load(model: model) { progress in
            logger.report(progress.fractionCompleted)
        }
        writeStderr("\n→ 추론 시작 (\(action.displayNameKo))\n")

        let prompt = PromptBuilder.build(action: action, input: input)
        let options = GenerationOptions.defaults(for: action)

        let started = Date()
        var firstTokenAt: Date?
        for try await token in engine.stream(prompt: prompt, options: options) {
            if firstTokenAt == nil { firstTokenAt = Date() }
            FileHandle.standardOutput.write(Data(token.utf8))
        }
        print("")
        let elapsed = Date().timeIntervalSince(started)
        let firstLatency = firstTokenAt.map { $0.timeIntervalSince(started) } ?? 0
        writeStderr(String(format: "→ 완료 (총 %.2fs, 첫 토큰 %.2fs)\n", elapsed, firstLatency))
    } catch {
        writeStderr("실패: \(error)\n")
        exit(2)
    }
}

guard !args.isEmpty else {
    printUsage()
    exit(1)
}

if args[0] == "--list-models" || args[0] == "models" {
    for model in VibeTypeModelRegistry.all {
        let sizeGB = String(format: "%.1f", Double(model.approxSizeBytes) / 1_000_000_000)
        let ios = model.supportsIOS ? "iOS-OK" : "Mac-only"
        print("- \(model.id)  \(model.displayName)  ~\(sizeGB)GB  \(ios)")
    }
    exit(0)
}

if args[0] == "whisper-models" {
    for model in VibeTypeWhisperRegistry.all {
        let sizeGB = String(format: "%.1f", Double(model.approxSizeBytes) / 1_000_000_000)
        let ko = model.supportsKorean ? "KO-OK" : "no-KO"
        print("- \(model.id)  \(model.displayName)  ~\(sizeGB)GB  \(ko)")
    }
    exit(0)
}

if args[0] == "dictate" {
    guard args.count >= 2 else {
        writeStderr("사용법: vibetype-cli dictate <wav-path>\n")
        exit(1)
    }
    let path = args[1]
    let modelID = ProcessInfo.processInfo.environment["VIBETYPE_WHISPER_MODEL"]
    let model = (modelID.flatMap { VibeTypeWhisperRegistry.model(byID: $0) }) ?? VibeTypeWhisperRegistry.default

    await runDictate(audioPath: path, model: model)
    fflush(stdout)
    fflush(stderr)
    Darwin._exit(0)
}

func runDictate(audioPath: String, model: WhisperModelInfo) async {
    writeStderr("→ Whisper 모델 로드: \(model.displayName)\n")
    let started = Date()
    do {
        try await WhisperEngine.shared.load(model: model)
        let loadTime = Date().timeIntervalSince(started)
        writeStderr("→ 로드 완료 (\(String(format: "%.2f", loadTime))s), 받아쓰기 시작\n")
        let transcribeStart = Date()
        let text = try await WhisperEngine.shared.transcribe(audioPath: audioPath)
        let transcribeTime = Date().timeIntervalSince(transcribeStart)
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
        writeStderr(String(format: "→ 완료 (전사 %.2fs)\n", transcribeTime))
    } catch {
        writeStderr("실패: \(error)\n")
        Darwin._exit(2)
    }
}

guard args.count >= 2 else {
    printUsage()
    exit(1)
}

guard let action = parseAction(args[0]) else {
    print("알 수 없는 액션: \(args[0])")
    printUsage()
    exit(1)
}

let input = args[1...].joined(separator: " ")
let modelID = ProcessInfo.processInfo.environment["VIBETYPE_MODEL"]
let model = (modelID.flatMap { VibeTypeModelRegistry.model(byID: $0) }) ?? VibeTypeModelRegistry.default

await run(action: action, input: input, model: model)

// MLX는 종료 시 GPU/Metal 리소스 정리 중 SIGSEGV가 발생할 수 있어
// _exit으로 atexit 핸들러를 모두 건너뛴다 (CLI 한정, 라이브러리 코드는 영향 없음).
fflush(stdout)
fflush(stderr)
Darwin._exit(0)
