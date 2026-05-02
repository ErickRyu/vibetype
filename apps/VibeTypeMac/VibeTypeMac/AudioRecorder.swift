import AVFoundation
import Foundation

enum AudioRecorderError: Error, LocalizedError {
    case permissionDenied
    case engineFailure(String)
    case noActiveRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:        return "마이크 권한이 없습니다. System Settings → Privacy & Security → Microphone에서 VibeType을 허용해 주세요."
        case .engineFailure(let msg):  return "오디오 엔진 오류: \(msg)"
        case .noActiveRecording:       return "진행 중인 녹음이 없습니다."
        }
    }
}

/// AVAudioEngine 기반 마이크 녹음.
/// 16kHz mono Float32 PCM 버퍼를 누적해 Whisper에 직접 전달 가능한 [Float]로 반환한다.
@MainActor
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private let targetSampleRate: Double = 16_000
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private var isRecording = false

    /// 마이크 권한 상태.
    static var permissionStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    /// 마이크 권한 요청. 처음이면 시스템 다이얼로그 표시.
    static func requestPermission() async -> Bool {
        if permissionStatus == .authorized { return true }
        if permissionStatus == .denied || permissionStatus == .restricted { return false }
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() throws {
        guard !isRecording else { return }
        guard Self.permissionStatus == .authorized else {
            throw AudioRecorderError.permissionDenied
        }

        samples.removeAll(keepingCapacity: true)
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )
        guard let targetFormat else {
            throw AudioRecorderError.engineFailure("16kHz mono Float32 포맷 생성 실패")
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.engineFailure("샘플레이트 컨버터 생성 실패")
        }
        self.converter = converter

        // input → buffer → 16kHz mono 변환 → samples 누적
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.appendBuffer(buffer, with: converter, targetFormat: targetFormat)
        }

        do {
            try engine.start()
            isRecording = true
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioRecorderError.engineFailure(String(describing: error))
        }
    }

    func stop() throws -> [Float] {
        guard isRecording else { throw AudioRecorderError.noActiveRecording }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        converter = nil
        let captured = samples
        samples.removeAll(keepingCapacity: true)
        return captured
    }

    func cancel() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        converter = nil
        samples.removeAll(keepingCapacity: true)
    }

    var currentDurationSeconds: Double {
        Double(samples.count) / targetSampleRate
    }

    private nonisolated func appendBuffer(
        _ inputBuffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio + 16)
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat, frameCapacity: outputCapacity
        ) else { return }

        var error: NSError?
        var fed = false
        let status = converter.convert(to: outputBuffer, error: &error) { _, inputStatus in
            if fed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            fed = true
            inputStatus.pointee = .haveData
            return inputBuffer
        }

        guard status != .error, error == nil,
              let channelData = outputBuffer.floatChannelData?[0] else { return }
        let frames = Int(outputBuffer.frameLength)
        let bufferPtr = UnsafeBufferPointer(start: channelData, count: frames)
        let chunk = Array(bufferPtr)
        Task { @MainActor [weak self] in
            self?.samples.append(contentsOf: chunk)
        }
    }
}
