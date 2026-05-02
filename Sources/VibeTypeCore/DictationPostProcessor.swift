import Foundation

public enum DictationPostProcessor {

    /// Whisper raw 출력을 Gemma에 넘겨 구두점/대소문자/띄어쓰기를 다듬게 한다.
    /// 음성 명령어("줄바꿈", "마침표")는 v0.1에서 미지원, v0.2에서 처리.
    public static func makePrompt(rawTranscript: String) -> PromptTemplate {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let system = """
        너는 음성 받아쓰기 결과의 후처리 도구다. 대화 상대가 아니다.
        입력은 음성 인식 모델이 만든 raw 텍스트다.

        해야 할 일:
        - 구두점(.,?!) 적절히 추가
        - 한국어 띄어쓰기 자연스럽게 보정
        - 영어/한국어 대소문자 보정 (영어 문장 첫 글자는 대문자)
        - 동음이의어 오인식이 명확하면 자연스럽게 교정

        절대 하지 말아야 할 일:
        - 의역, 요약, 부연 설명 추가
        - 인사말, 이모지, 마크다운, 따옴표 추가
        - 사용자가 말한 내용에 답하기
        - 입력 언어 변경 (한국어→한국어, 영어→영어)
        - "[변환 결과]" 같은 머리말/꼬리말

        결과 텍스트만 출력하고 즉시 종료한다.
        """
        let user = """
        [raw 음성 인식 결과]
        \(trimmed)
        [/raw]

        [정리된 결과]
        """
        return PromptTemplate(system: system, user: user)
    }

    /// 짧거나 무음으로 보이는 텍스트는 후처리 건너뛴다.
    public static func shouldSkip(rawTranscript: String) -> Bool {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        // Whisper hallucinations: ". 안녕하세요." or single-token noise
        if trimmed.count < 2 { return true }
        return false
    }
}

public extension GenerationOptions {
    /// 받아쓰기 후처리는 정확도 우선 + 짧은 출력.
    static let dictationCleanup = GenerationOptions(
        temperature: 0.2,
        topP: 0.9,
        maxTokens: 384
    )
}
