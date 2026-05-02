import AppKit
import Carbon.HIToolbox

@MainActor
enum PasteboardFallback {

    /// ⌘C로 선택 텍스트를 복사 후 클립보드에서 읽는다.
    /// fixed sleep 대신 NSPasteboard.changeCount 폴링으로 ⌘C가 실제 반영된 시점을 기다린다.
    /// 호출자는 finally에서 snapshot.restore()를 반드시 호출해야 한다.
    static func captureSelection() async throws -> (text: String, savedSnapshot: ClipboardSnapshot) {
        let snapshot = ClipboardSnapshot.capture()
        let pasteboard = NSPasteboard.general
        let beforeCount = pasteboard.changeCount

        try sendKeystroke(keyCode: kVK_ANSI_C, modifiers: [.maskCommand])

        // 최대 600ms까지 changeCount 변화를 폴링 (20ms 간격).
        let deadline = Date().addingTimeInterval(0.6)
        while Date() < deadline {
            if pasteboard.changeCount != beforeCount {
                if let text = pasteboard.string(forType: .string), !text.isEmpty {
                    return (text, snapshot)
                }
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        snapshot.restore()
        throw PasteboardError.nothingCopied
    }

    /// 새 텍스트를 클립보드에 넣고 ⌘V로 붙여넣은 후 원래 클립보드를 복원한다.
    static func paste(_ text: String, restoring snapshot: ClipboardSnapshot) async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let afterWrite = pasteboard.changeCount

        try sendKeystroke(keyCode: kVK_ANSI_V, modifiers: [.maskCommand])

        // ⌘V가 처리될 시간을 changeCount 변화로 감지하거나 최대 400ms 대기.
        let deadline = Date().addingTimeInterval(0.4)
        while Date() < deadline {
            if pasteboard.changeCount != afterWrite { break }
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        // 충분한 처리 시간을 추가로 둔 뒤 원본 복원.
        try await Task.sleep(nanoseconds: 100_000_000)
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
