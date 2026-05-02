import AppKit
import KeyboardShortcuts
import VibeTypeCore

extension KeyboardShortcuts.Name {
    static let invokeImprove     = Self("vibetype.improve",     default: .init(.space, modifiers: [.option]))
    static let invokeFixGrammar  = Self("vibetype.fixGrammar")
    static let invokeTranslateKo = Self("vibetype.translateKo")
    static let invokeTranslateEn = Self("vibetype.translateEn")
    static let invokeSummarize   = Self("vibetype.summarize")
}

@MainActor
final class HotkeyManager {
    typealias ActionHandler = @MainActor (TextAction) -> Void

    private let onAction: ActionHandler

    init(onAction: @escaping ActionHandler) {
        self.onAction = onAction
        register()
    }

    private func register() {
        KeyboardShortcuts.onKeyUp(for: .invokeImprove)     { [weak self] in self?.onAction(.improve) }
        KeyboardShortcuts.onKeyUp(for: .invokeFixGrammar)  { [weak self] in self?.onAction(.fixGrammar) }
        KeyboardShortcuts.onKeyUp(for: .invokeTranslateKo) { [weak self] in self?.onAction(.translateKo) }
        KeyboardShortcuts.onKeyUp(for: .invokeTranslateEn) { [weak self] in self?.onAction(.translateEn) }
        KeyboardShortcuts.onKeyUp(for: .invokeSummarize)   { [weak self] in self?.onAction(.summarize) }
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
