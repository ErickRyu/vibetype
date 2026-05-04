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

/// AVAudioEngine 콜백은 audio realtime 큐에서 호출되므로 MainActor 격리 클래스로
/// 만들면 Swift 6 runtime assert에 걸린다. 따라서 nonisolated 클래스로 두고
/// 내부 가변 상태는 NSLock + Sendable 버퍼로 보호한다.
final class AudioRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let targetSampleRate: Double = 16_000
    private let buffer = AudioSampleBuffer()
    private let stateLock = NSLock()
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
        stateLock.lock()
        if isRecording { stateLock.unlock(); return }
        stateLock.unlock()

        // .denied/.restricted만 명시 throw. ad-hoc 서명 환경에서 macOS가
        // 권한 grant를 받았어도 .notDetermined를 보고하는 케이스가 있으므로
        // 그 상태도 engine.start()로 위임 — 실패하면 그때 throw.
        let status = Self.permissionStatus
        if status == .denied || status == .restricted {
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

        stateLock.lock()
        self.converter = converter
        stateLock.unlock()

        let bufferRef = self.buffer
        // capture-list: AVAudioConverter는 Sendable이 아니지만 동일 큐(audio realtime)
        // 에서만 사용되므로 안전. @Sendable 명시로 격리 검증 우회.
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            @Sendable [converter, targetFormat, bufferRef] inputBuffer, _ in
            Self.processBuffer(
                inputBuffer,
                converter: converter,
                targetFormat: targetFormat,
                into: bufferRef
            )
        }

        do {
            try engine.start()
            stateLock.lock()
            isRecording = true
            stateLock.unlock()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioRecorderError.engineFailure(String(describing: error))
        }
    }

    func stop() throws -> [Float] {
        stateLock.lock()
        guard isRecording else { stateLock.unlock(); throw AudioRecorderError.noActiveRecording }
        stateLock.unlock()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        stateLock.lock()
        isRecording = false
        converter = nil
        stateLock.unlock()
        return buffer.drain()
    }

    func cancel() {
        stateLock.lock()
        guard isRecording else { stateLock.unlock(); return }
        stateLock.unlock()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        stateLock.lock()
        isRecording = false
        converter = nil
        stateLock.unlock()
        buffer.clear()
    }

    var currentDurationSeconds: Double {
        Double(buffer.count()) / targetSampleRate
    }

    private static func processBuffer(
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
