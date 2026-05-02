import AppKit
import SwiftUI

/// Wispr Flow 스타일 floating HUD: 화면 하단 중앙에 알약 모양 패널.
/// NSPanel + .nonactivatingPanel로 키 윈도우 안 가로채고, level=floating으로 항상 위.
@MainActor
final class DictationHUDWindow {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<DictationHUDView>?
    private var hideTask: Task<Void, Never>?
    private var currentState: DictationCoordinator.State = .idle
    private var recordingStartedAt: Date?

    /// 사용자가 HUD에서 X 클릭 시 호출.
    var onCancel: (@MainActor () -> Void)?

    func update(state: DictationCoordinator.State) {
        let previous = currentState
        currentState = state

        if case .recording = state, !Self.isRecordingState(previous) {
            recordingStartedAt = Date()
        } else if !Self.isRecordingState(state) {
            // 녹음 종료 시 타이머 정지(이후 상태에서는 사용 안 함).
        }

        switch state {
        case .idle:
            scheduleHide(after: 0.2)
        case .failed:
            ensureVisible()
            scheduleHide(after: 1.5)
        case .recording, .transcribing, .postProcessing, .typing:
            cancelScheduledHide()
            ensureVisible()
        @unknown default:
            ensureVisible()
        }
    }

    private static func isRecordingState(_ state: DictationCoordinator.State) -> Bool {
        if case .recording = state { return true }
        return false
    }

    private func ensureVisible() {
        if panel == nil { createPanel() }
        rebuildContent()
        guard let panel else { return }
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = 1
            }
        }
    }

    private func scheduleHide(after seconds: TimeInterval) {
        cancelScheduledHide()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if Task.isCancelled { return }
            self?.hide()
        }
    }

    private func cancelScheduledHide() {
        hideTask?.cancel()
        hideTask = nil
    }

    private func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
        })
    }

    private func createPanel() {
        let view = DictationHUDView(
            state: currentState,
            recordingStartedAt: recordingStartedAt,
            onCancel: { [weak self] in self?.onCancel?() }
        )
        let hosting = NSHostingController(rootView: view)
        hostingController = hosting

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true

        repositionToScreenBottomCenter(panel)
        self.panel = panel
    }

    private func rebuildContent() {
        let view = DictationHUDView(
            state: currentState,
            recordingStartedAt: recordingStartedAt,
            onCancel: { [weak self] in self?.onCancel?() }
        )
        hostingController?.rootView = view
    }

    private func repositionToScreenBottomCenter(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let originX = visible.midX - size.width / 2
        let originY = visible.minY + 80
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}
