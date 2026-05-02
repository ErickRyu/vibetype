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
    private var isFnDown = false

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
        Task { @MainActor [weak self] in
            guard let self else { return }
            if pressed != self.isFnDown {
                self.isFnDown = pressed
                self.onChange(pressed)
            }
        }
    }
}
