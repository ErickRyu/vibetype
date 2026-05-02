import AppKit
import KeyboardShortcuts
import VibeTypeCore

extension KeyboardShortcuts.Name {
    /// 받아쓰기 단축키 (Phase B는 임시 토글: ⌥⇧Space → 시작/정지).
    /// Phase C에서 keyDown=start, keyUp=stop의 push-to-talk으로 전환 예정.
    static let dictate = Self("vibetype.dictate", default: .init(.space, modifiers: [.option, .shift]))

    // 보너스: 텍스트 다듬기 액션 (디폴트 단축키 미할당, 사용자가 설정에서 매핑)
    static let invokeImprove     = Self("vibetype.improve")
    static let invokeFixGrammar  = Self("vibetype.fixGrammar")
    static let invokeTranslateKo = Self("vibetype.translateKo")
    static let invokeTranslateEn = Self("vibetype.translateEn")
    static let invokeSummarize   = Self("vibetype.summarize")
}

@MainActor
final class HotkeyManager {
    typealias DictationToggle = @MainActor () -> Void
    typealias TextActionHandler = @MainActor (TextAction) -> Void

    private let onDictationToggle: DictationToggle
    private let onTextAction: TextActionHandler
    private var isDictating = false

    init(
        onDictationToggle: @escaping DictationToggle,
        onTextAction: @escaping TextActionHandler
    ) {
        self.onDictationToggle = onDictationToggle
        self.onTextAction = onTextAction
        register()
    }

    private func register() {
        // Phase B: 토글 방식. ⌥⇧Space 한 번 누르면 시작/정지 교대.
        KeyboardShortcuts.onKeyUp(for: .dictate) { [weak self] in
            self?.onDictationToggle()
        }

        KeyboardShortcuts.onKeyUp(for: .invokeImprove)     { [weak self] in self?.onTextAction(.improve) }
        KeyboardShortcuts.onKeyUp(for: .invokeFixGrammar)  { [weak self] in self?.onTextAction(.fixGrammar) }
        KeyboardShortcuts.onKeyUp(for: .invokeTranslateKo) { [weak self] in self?.onTextAction(.translateKo) }
        KeyboardShortcuts.onKeyUp(for: .invokeTranslateEn) { [weak self] in self?.onTextAction(.translateEn) }
        KeyboardShortcuts.onKeyUp(for: .invokeSummarize)   { [weak self] in self?.onTextAction(.summarize) }
    }

    static func shortcutName(for action: TextAction) -> KeyboardShortcuts.Name {
        switch action {
        case .improve:      return .invokeImprove
        case .fixGrammar:   return .invokeFixGrammar
        case .translateKo:  return .invokeTranslateKo
        case .translateEn:  return .invokeTranslateEn
        case .summarize:    return .invokeSummarize
        }
    }
}
