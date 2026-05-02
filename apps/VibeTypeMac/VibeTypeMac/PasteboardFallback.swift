import AppKit
import Carbon.HIToolbox

@MainActor
enum PasteboardFallback {

    /// ⌘C로 선택 텍스트를 복사 후 클립보드에서 읽는다.
    /// 호출자는 finally 블록에서 `restoreClipboard(_:)` 를 반드시 호출해야 한다.
    static func captureSelection() async throws -> (text: String, savedSnapshot: ClipboardSnapshot) {
        let snapshot = ClipboardSnapshot.capture()
        NSPasteboard.general.clearContents()
        try sendKeystroke(keyCode: kVK_ANSI_C, modifiers: [.maskCommand])
        // ⌘C 처리 시간 확보. 일부 앱은 즉시 반영 안 됨.
        try await Task.sleep(nanoseconds: 80_000_000)
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            snapshot.restore()
            throw PasteboardError.nothingCopied
        }
        return (text, snapshot)
    }

    /// 새 텍스트를 클립보드에 넣고 ⌘V로 붙여넣은 후 원래 클립보드를 복원한다.
    static func paste(_ text: String, restoring snapshot: ClipboardSnapshot) async throws {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        try sendKeystroke(keyCode: kVK_ANSI_V, modifiers: [.maskCommand])
        try await Task.sleep(nanoseconds: 80_000_000)
        snapshot.restore()
    }

    private static func sendKeystroke(keyCode: Int, modifiers: CGEventFlags) throws {
        let source = CGEventSource(stateID: .combinedSessionState)
        let virtualKey = CGKeyCode(keyCode)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        else {
            throw PasteboardError.cgEventCreationFailed
        }
        keyDown.flags = modifiers
        keyUp.flags = modifiers
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

enum PasteboardError: Error, LocalizedError {
    case nothingCopied
    case cgEventCreationFailed

    var errorDescription: String? {
        switch self {
        case .nothingCopied:           return "선택된 텍스트가 없거나 클립보드 캡처에 실패했습니다."
        case .cgEventCreationFailed:   return "키 이벤트 생성에 실패했습니다."
        }
    }
}

/// 사용자가 클립보드에 두었던 내용을 원본 그대로 보존/복원한다.
struct ClipboardSnapshot: @unchecked Sendable {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture() -> ClipboardSnapshot {
        let pasteboard = NSPasteboard.general
        let snapshot = (pasteboard.pasteboardItems ?? []).map { item -> [NSPasteboard.PasteboardType: Data] in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
        return ClipboardSnapshot(items: snapshot)
    }

    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let restoredItems: [NSPasteboardItem] = items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
