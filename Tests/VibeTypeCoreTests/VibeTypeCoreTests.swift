import Testing
@testable import VibeTypeCore

@Suite("VibeTypeCore basics")
struct VibeTypeCoreTests {
    @Test("Version string is non-empty")
    func versionExists() {
        #expect(!VibeType.version.isEmpty)
    }

    @Test("ModelRegistry has a default model")
    func defaultModelExists() {
        #expect(VibeTypeModelRegistry.default.id == VibeTypeModelRegistry.gemma3n_E4B.id)
        #expect(!VibeTypeModelRegistry.all.isEmpty)
    }

    @Test("ModelRegistry lookup by id", arguments: VibeTypeModelRegistry.all.map(\.id))
    func lookupByID(modelID: String) throws {
        let model = try #require(VibeTypeModelRegistry.model(byID: modelID))
        #expect(model.id == modelID)
        #expect(!model.huggingFaceID.isEmpty)
    }

    @Test("Recommended model on iOS prefers 3n-E2B at 8GB")
    func iosRecommendation() {
        let m = VibeTypeModelRegistry.recommended(forSystemRAMGB: 8, isIOS: true)
        #expect(m.supportsIOS)
        #expect(m.id == VibeTypeModelRegistry.gemma3n_E2B.id)
    }

    @Test("Recommended model on Mac with 16GB picks 3n-E4B")
    func macRecommendation16GB() {
        let m = VibeTypeModelRegistry.recommended(forSystemRAMGB: 16, isIOS: false)
        #expect(m.id == VibeTypeModelRegistry.gemma3n_E4B.id)
    }

    @Test("PromptBuilder trims input and keeps it as user message")
    func promptBuilderTrim() {
        let p = PromptBuilder.build(action: .improve, input: "  hello  ")
        #expect(p.user == "hello")
        #expect(p.system.contains("글쓰기"))
    }

    @Test(
        "PromptBuilder produces non-empty system + user for every action",
        arguments: TextAction.allCases
    )
    func promptBuilderEveryAction(action: TextAction) {
        let p = PromptBuilder.build(action: action, input: "샘플 텍스트")
        #expect(!p.system.isEmpty)
        #expect(!p.user.isEmpty)
    }

    @Test("GenerationOptions defaults differ per action")
    func generationOptionsDefaults() {
        #expect(GenerationOptions.defaults(for: .fixGrammar).temperature < 0.2)
        #expect(GenerationOptions.defaults(for: .improve).temperature >= 0.3)
    }

    @Test("TextAction display names exist in both languages", arguments: TextAction.allCases)
    func textActionDisplayNames(action: TextAction) {
        #expect(!action.displayNameKo.isEmpty)
        #expect(!action.displayNameEn.isEmpty)
        #expect(!action.sfSymbol.isEmpty)
    }
}
