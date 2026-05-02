import SwiftUI

struct DictationHUDView: View {
    let state: DictationCoordinator.State
    let recordingStartedAt: Date?
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            leadingIcon
            centerContent
            trailingControl
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(width: 280, height: 56)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 8)
        )
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch state {
        case .recording:
            PulsingDot()
        case .transcribing:
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative)
                .font(.title3)
                .foregroundStyle(.cyan)
        case .postProcessing:
            Image(systemName: "wand.and.stars")
                .symbolEffect(.pulse)
                .font(.title3)
                .foregroundStyle(.purple)
        case .typing:
            Image(systemName: "keyboard")
                .symbolEffect(.pulse)
                .font(.title3)
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
        case .idle:
            Color.clear.frame(width: 14, height: 14)
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        switch state {
        case .recording:
            WaveformBars()
                .frame(maxWidth: .infinity)
        case .transcribing:
            Text("음성 인식 중…")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .postProcessing:
            Text("다듬는 중…")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .typing:
            Text("입력 중…")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let msg):
            Text(msg)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .idle:
            Color.clear.frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch state {
        case .recording:
            HStack(spacing: 8) {
                RecordingTimer(startedAt: recordingStartedAt)
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        case .transcribing, .postProcessing, .typing:
            ProgressView()
                .controlSize(.small)
                .colorScheme(.dark)
        case .failed, .idle:
            Color.clear.frame(width: 18)
        }
    }
}

private struct PulsingDot: View {
    @State private var pulse = false
    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 12, height: 12)
            .scaleEffect(pulse ? 1.25 : 0.85)
            .opacity(pulse ? 1.0 : 0.7)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

private struct WaveformBars: View {
    @State private var heights: [CGFloat] = [0.4, 0.6, 0.8, 0.5, 0.3]
    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<heights.count, id: \.self) { idx in
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: 4, height: 24 * heights[idx])
                    .animation(.easeInOut(duration: 0.18), value: heights[idx])
            }
        }
        .frame(height: 28)
        .onReceive(timer) { _ in
            heights = (0..<heights.count).map { _ in CGFloat.random(in: 0.25...1.0) }
        }
    }
}

private struct RecordingTimer: View {
    let startedAt: Date?
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formatted)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.8))
            .onReceive(timer) { _ in
                guard let startedAt else { elapsed = 0; return }
                elapsed = Date().timeIntervalSince(startedAt)
            }
    }

    private var formatted: String {
        let total = max(0, elapsed)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        let tenths = Int((total - floor(total)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}
