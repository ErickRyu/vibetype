import Foundation

public struct PromptTemplate: Sendable {
    public let system: String
    public let user: String

    public init(system: String, user: String) {
        self.system = system
        self.user = user
    }
}

public enum PromptBuilder {
    public static func build(action: TextAction, input: String) -> PromptTemplate {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        switch action {
        case .improve:
            return PromptTemplate(
                system: """
                당신은 한국어와 영어를 모두 잘 다루는 글쓰기 코치입니다.
                사용자가 제공한 텍스트를 본래의 의미와 어조를 유지한 채 더 자연스럽고 명확하게 다듬으세요.
                - 의역하지 말고 원문의 의도를 그대로 살리세요.
                - 한국어 입력은 한국어로, 영어 입력은 영어로 응답하세요.
                - 결과만 출력하세요. 설명, 인사말, 따옴표, 마크다운을 절대 추가하지 마세요.
                """,
                user: trimmed
            )

        case .fixGrammar:
            return PromptTemplate(
                system: """
                당신은 정확한 교정 편집자입니다. 사용자가 제공한 텍스트의 맞춤법, 띄어쓰기, 문법 오류만 고치세요.
                - 어조와 표현은 가능한 한 보존하세요.
                - 한국어 입력은 한국어로, 영어 입력은 영어로 응답하세요.
                - 결과만 출력하세요. 설명이나 부연 없이.
                """,
                user: trimmed
            )

        case .translateKo:
            return PromptTemplate(
                system: """
                당신은 능숙한 한국어 번역가입니다.
                사용자가 제공한 텍스트를 자연스러운 한국어로 번역하세요.
                - 이미 한국어인 경우 동일하게 출력하세요.
                - 결과만 출력하세요. 원문 인용이나 설명 없이.
                """,
                user: trimmed
            )

        case .translateEn:
            return PromptTemplate(
                system: """
                You are a skilled English translator.
                Translate the user-provided text into natural, fluent English.
                - If the input is already English, return it unchanged.
                - Output only the translation. No quotes, no explanations.
                """,
                user: trimmed
            )

        case .summarize:
            return PromptTemplate(
                system: """
                당신은 정확한 요약 전문가입니다.
                사용자가 제공한 텍스트의 핵심을 1~3문장으로 압축하세요.
                - 입력 언어 그대로 출력하세요 (한국어→한국어, 영어→영어).
                - 결과만 출력하세요. 설명이나 메타 코멘트 없이.
                """,
                user: trimmed
            )
        }
    }
}
