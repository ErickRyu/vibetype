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

/// AVAudioEngine 실시간 콜백은 audio realtime 큐에서 호출되므로
/// MainActor 격리 클래스에서 직접 mutate하면 strict concurrency assertion에 걸린다.
/// 락으로 보호되는 Sendable 버퍼로 분리.
final class AudioSampleBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Float] = []

    func append(_ chunk: [Float]) {
        lock.lock(); defer { lock.unlock() }
        storage.append(contentsOf: chunk)
    }

    func drain() -> [Float] {
        lock.lock(); defer { lock.unlock() }
        let captured = storage
        storage.removeAll(keepingCapacity: true)
        return captured
    }

    func count() -> Int {
        lock.lock(); defer { lock.unlock() }
        return storage.count
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        storage.removeAll(keepingCapacity: true)
    }
}

@MainActor
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private let targetSampleRate: Double = 16_000
    private let buffer = AudioSampleBuffer()
    private var converter: AVAudioConverter?
    private var isRecording = false

    static var permissionStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

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

        buffer.clear()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.engineFailure("16kHz mono Float32 포맷 생성 실패")
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.engineFailure("샘플레이트 컨버터 생성 실패")
        }
        self.converter = converter

        // Realtime 콜백: capture-list로 Sendable 값들만 받아 actor 격리에서 벗어남.
        let bufferRef = self.buffer
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { inputBuffer, _ in
            Self.processBuffer(inputBuffer, converter: converter, targetFormat: targetFormat, into: bufferRef)
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
        return buffer.drain()
    }

    func cancel() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        converter = nil
        buffer.clear()
    }

    var currentDurationSeconds: Double {
        Double(buffer.count()) / targetSampleRate
    }

    /// nonisolated static — 어떤 실행 컨텍스트에서도 호출 가능.
    /// AVAudioConverter는 Sendable이 아니지만 동일 큐에서만 사용되므로 안전.
    private nonisolated static func processBuffer(
        _ inputBuffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat,
        into output: AudioSampleBuffer
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
        output.append(Array(bufferPtr))
    }
}
