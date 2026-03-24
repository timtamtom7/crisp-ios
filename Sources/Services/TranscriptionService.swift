import Speech
import AVFoundation
import Combine

@MainActor
final class TranscriptionService: ObservableObject {
    @Published private(set) var transcribedText = ""
    @Published private(set) var isTranscribing = false
    @Published private(set) var errorMessage: String?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let audioEngine = AVAudioEngine()

    init(locale: Locale = Locale(identifier: "en-US")) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startTranscribing() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer not available"
            return
        }

        transcribedText = ""
        errorMessage = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try session.setActive(true)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let request = recognitionRequest else {
            errorMessage = "Failed to create recognition request"
            return
        }

        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.stopTranscribing()
                }

                if result?.isFinal == true {
                    self.stopTranscribing()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isTranscribing = true
    }

    func stopTranscribing() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        isTranscribing = false
    }

    func transcribeAudioFile(at url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let recognizer = speechRecognizer, recognizer.isAvailable else {
                continuation.resume(throwing: TranscriptionError.recognizerUnavailable)
                return
            }

            let request = SFSpeechURLRecognitionRequest(url: url)
            request.addsPunctuation = true

            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

enum TranscriptionError: Error {
    case recognizerUnavailable
    case notAuthorized
}
