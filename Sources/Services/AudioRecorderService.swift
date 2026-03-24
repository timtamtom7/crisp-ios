import AVFoundation
import Combine

final class AudioRecorderService: ObservableObject, @unchecked Sendable {
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    @Published private(set) var isRecording = false
    @Published private(set) var audioLevel: Float = 0.0

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try session.setActive(true)

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "crisp_\(UUID().uuidString).m4a"
        recordingURL = documentsPath.appendingPathComponent(fileName)

        guard let url = recordingURL else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        audioFile = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: recordingFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])

        let capturedAudioFile = audioFile

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            do {
                try capturedAudioFile?.write(from: buffer)
            } catch {
                print("Audio write error: \(error)")
            }

            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += abs(channelData?[i] ?? 0)
            }
            let average = sum / Float(frameLength)
            let level = min(average * 10, 1.0)

            Task { @MainActor in
                self.audioLevel = level
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        Task { @MainActor in
            self.isRecording = true
        }
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)

        guard let url = recordingURL, let file = audioFile else { return nil }

        let duration = Double(file.length) / file.fileFormat.sampleRate

        audioFile = nil
        recordingURL = nil

        Task { @MainActor in
            self.isRecording = false
            self.audioLevel = 0.0
        }

        return (url, duration)
    }

    func cancelRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        audioFile = nil
        recordingURL = nil

        Task { @MainActor in
            self.isRecording = false
            self.audioLevel = 0.0
        }
    }
}
