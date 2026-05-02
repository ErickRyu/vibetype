import Foundation

public enum TextAction: String, CaseIterable, Codable, Sendable {
    case improve
    case fixGrammar
    case translateKo
    case translateEn
    case summarize

    public var displayNameKo: String {
        switch self {
        case .improve:      return "다듬기"
        case .fixGrammar:   return "맞춤법 교정"
        case .translateKo:  return "한국어로 번역"
        case .translateEn:  return "영어로 번역"
        case .summarize:    return "요약"
        }
    }

    public var displayNameEn: String {
        switch self {
        case .improve:      return "Improve"
        case .fixGrammar:   return "Fix Grammar"
        case .translateKo:  return "Translate → KO"
        case .translateEn:  return "Translate → EN"
        case .summarize:    return "Summarize"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .improve:      return "wand.and.stars"
        case .fixGrammar:   return "checkmark.circle"
        case .translateKo:  return "globe"
        case .translateEn:  return "globe"
        case .summarize:    return "text.alignleft"
        }
    }
}
