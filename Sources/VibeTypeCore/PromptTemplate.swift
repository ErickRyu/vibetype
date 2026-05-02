import Foundation

public struct PromptTemplate: Sendable {
    public let system: String
    public let user: String

    public init(system: String, user: String) {
        self.system = system
        self.user = user
    }
}

// 텍스트 변환은 chat이 아닌 "completion 스타일"로 프롬프팅한다.
// 시스템 프롬프트는 강한 directive, user 메시지는 [입력]/[출력] 마커로
// 명확한 구조를 부여해 모델이 대화체로 빠지지 않도록 anchoring한다.
public enum PromptBuilder {

    private static let strictDirective = """
    너는 텍스트 변환 도구다. 대화 상대가 아니다.
    입력 텍스트에 대한 답변/설명/감상/제안을 절대 작성하지 마라.
    입력 텍스트를 변환한 "결과 텍스트"만 단 한 번 출력하고 즉시 종료한다.
    인사, 이모지, 마크다운, 따옴표, 머리말, 꼬리말, 부연 설명, 대안 제시 모두 금지.
    """

    public static func build(action: TextAction, input: String) -> PromptTemplate {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        switch action {
        case .improve:
            return PromptTemplate(
                system: strictDirective + """


                작업: 입력 텍스트를 본래 의미와 어조를 유지한 채 더 자연스럽고 명확하게 다듬는다.
                의역 금지. 한국어 입력은 한국어로, 영어 입력은 영어로 출력한다.
                """,
                user: """
                [입력]
                \(trimmed)
                [/입력]

                [다듬은 결과]
                """
            )

        case .fixGrammar:
            return PromptTemplate(
                system: strictDirective + """


                작업: 입력 텍스트의 맞춤법, 띄어쓰기, 문법 오류만 교정한다.
                어조와 표현은 그대로 보존한다. 의미가 바뀌는 수정 금지.
                한국어 입력은 한국어로, 영어 입력은 영어로 출력한다.
                """,
                user: """
                [입력]
                \(trimmed)
                [/입력]

                [교정된 결과]
                """
            )

        case .translateKo:
            return PromptTemplate(
                system: strictDirective + """


                작업: 입력 텍스트를 자연스러운 한국어로 번역한다.
                이미 한국어이면 그대로 출력한다. 원문 인용 금지.
                """,
                user: """
                [입력]
                \(trimmed)
                [/입력]

                [한국어 번역]
                """
            )

        case .translateEn:
            return PromptTemplate(
                system: strictDirective + """


                작업: 입력 텍스트를 자연스럽고 매끄러운 영어로 번역한다.
                이미 영어이면 그대로 출력한다. 원문 인용 금지.
                """,
                user: """
                [Input]
                \(trimmed)
                [/Input]

                [English translation]
                """
            )

        case .summarize:
            return PromptTemplate(
                system: strictDirective + """


                작업: 입력 텍스트의 핵심을 1~3문장으로 압축한다.
                입력 언어 그대로 출력한다 (한국어→한국어, 영어→영어).
                불릿/번호 매기기 금지. 평문 한 단락으로 작성한다.
                """,
                user: """
                [입력]
                \(trimmed)
                [/입력]

                [요약]
                """
            )
        }
    }
}
