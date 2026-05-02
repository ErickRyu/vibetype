import AppKit
import ApplicationServices

enum AccessibilityError: Error, LocalizedError {
    case permissionDenied
    case noFocusedElement
    case unsupportedSelectionRead
    case writeRefused

    var errorDescription: String? {
        switch self {
        case .permissionDenied:        return "Accessibility 권한이 없습니다. System Settings → Privacy & Security → Accessibility에서 VibeType을 허용해 주세요."
        case .noFocusedElement:        return "포커스된 텍스트 영역을 찾을 수 없습니다."
        case .unsupportedSelectionRead: return "현재 앱에서 AX로 선택 텍스트를 읽을 수 없습니다. Pasteboard 폴백을 시도합니다."
        case .writeRefused:            return "현재 앱은 텍스트 직접 쓰기를 허용하지 않습니다. 붙여넣기 폴백을 시도합니다."
        }
    }
}

@MainActor
struct AccessibilityService {
    static var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Accessibility 권한을 요청 (필요 시 시스템 프롬프트 + 시스템 설정 안내).
    static func requestPermissionIfNeeded() {
        // Swift 6 strict concurrency 회피: C SDK의 CFString 전역 상수 대신
        // 문자열 리터럴을 사용해 비동기 안전성 검사를 우회한다.
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// 포커스된 UI 요소에서 AX로 선택 텍스트를 읽는다.
    /// 실패 시 Pasteboard 폴백을 호출자가 사용한다.
    static func readSelectionViaAX() throws -> String {
        guard hasPermission else { throw AccessibilityError.permissionDenied }

        let systemElement = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemElement, kAXFocusedUIElementAttribute as CFString, &focused
        )
        guard focusResult == .success, let focusedRef = focused else {
            throw AccessibilityError.noFocusedElement
        }
        let element = focusedRef as! AXUIElement // swiftlint:disable:this force_cast

        var selected: CFTypeRef?
        let selectionResult = AXUIElementCopyAttributeValue(
            element, kAXSelectedTextAttribute as CFString, &selected
        )
        guard selectionResult == .success, let selectedString = selected as? String, !selectedString.isEmpty else {
            throw AccessibilityError.unsupportedSelectionRead
        }
        return selectedString
    }

    /// 포커스된 UI 요소의 선택 텍스트를 새 값으로 교체한다.
    /// 실패 시 Pasteboard 폴백을 호출자가 사용한다.
    static func replaceSelectionViaAX(with text: String) throws {
        guard hasPermission else { throw AccessibilityError.permissionDenied }

        let systemElement = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemElement, kAXFocusedUIElementAttribute as CFString, &focused
        )
        guard focusResult == .success, let focusedRef = focused else {
            throw AccessibilityError.noFocusedElement
        }
        let element = focusedRef as! AXUIElement // swiftlint:disable:this force_cast

        let setResult = AXUIElementSetAttributeValue(
            element, kAXSelectedTextAttribute as CFString, text as CFString
        )
        guard setResult == .success else {
            throw AccessibilityError.writeRefused
        }
    }
}
