import AppKit

/// Fn 키(또는 Apple Silicon Magic Keyboard의 🌐 Globe 키)를
/// push-to-talk 트리거로 사용하기 위한 글로벌 모니터.
///
/// KeyboardShortcuts 라이브러리는 modifier-only 단축키를 지원하지 않으므로
/// NSEvent.flagsChanged를 직접 관찰한다.
///
/// keyCode 0x3F (= 63) 이 Fn 키. macOS 14+에서 Magic Keyboard with Touch ID의
/// 🌐 키도 동일 keyCode + .function 플래그를 발생시킨다.
@MainActor
final class FnKeyMonitor {
    typealias Handler = @MainActor (Bool) -> Void

    private let onChange: Handler
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// 콜백이 audio realtime/UI 큐에서 호출될 수 있어 NSLock으로 sync dedup.
    /// global + local 모니터가 같은 이벤트를 둘 다 emit하거나 macOS가 한 번 누름에
    /// multiple flagsChanged를 emit하는 케이스를 sync 단계에서 차단.
    /// MainActor 클래스지만 이 두 변수는 nonisolated 콜백에서 접근하므로 별도 보호.
    nonisolated(unsafe) private var isFnDownNonisolated = false
    nonisolated(unsafe) private let stateLock = NSLock()

    init(onChange: @escaping Handler) {
        self.onChange = onChange
        start()
    }

    func stop() {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func start() {
        // 다른 앱이 활성일 때 동작하는 글로벌 모니터.
        // Accessibility 권한 필요. 글로벌 모니터는 이벤트 변경 불가, 관찰만 가능.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        // 우리 앱이 활성일 때를 위한 로컬 모니터.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    private nonisolated func handleFlagsChanged(_ event: NSEvent) {
        // Fn 키 자체의 keyCode는 0x3F. 다른 모디파이어(Cmd, Shift 등)의 flagsChanged는 무시.
        guard event.keyCode == 0x3F else { return }
        let pressed = event.modifierFlags.contains(.function)

        // 1차 sync dedup: global/local 양쪽 monitor 또는 multiple flagsChanged emit을
        // MainActor Task 도달 전에 차단. NSLock 안에서만 상태 변경.
        stateLock.lock()
        let changed = pressed != isFnDownNonisolated
        if changed { isFnDownNonisolated = pressed }
        stateLock.unlock()
        guard changed else { return }

        Task { @MainActor [weak self] in
            self?.onChange(pressed)
        }
    }
}
