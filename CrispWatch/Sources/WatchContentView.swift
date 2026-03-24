import SwiftUI
import WatchKit
import AVFoundation

// MARK: - Watch Design Tokens

enum WatchTokens {
    static let background = Color(hex: "0d0d0e")
    static let surface = Color(hex: "141416")
    static let accent = Color(hex: "c8a97e")
    static let accentGlow = Color(hex: "c8a97e").opacity(0.3)
    static let textPrimary = Color(hex: "f5f5f7")
    static let textSecondary = Color(hex: "8b8b8e")
    static let danger = Color.red
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Recording State

enum WatchRecordingState {
    case idle
    case recording
    case paused
}

// MARK: - Main Content View

struct WatchContentView: View {
    @State private var recordingState: WatchRecordingState = .idle
    @State private var recordingDuration: TimeInterval = 0
    @State private var audioRecorder: WatchAudioRecorder?
    @State private var hasRecording = false
    @State private var showSaveDialog = false
    @State private var recordingTitle = ""
    @State private var waveformAmplitude: CGFloat = 0.1

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            WatchTokens.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Status bar
                HStack {
                    if recordingState == .recording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text("REC")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.red)
                        }
                    } else {
                        Text("Crisp")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(WatchTokens.textSecondary)
                    }

                    Spacer()

                    Text(formattedDuration)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(recordingState == .recording ? WatchTokens.accent : WatchTokens.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()

                // Waveform visualization
                WaveformCircle(
                    state: recordingState,
                    amplitude: waveformAmplitude
                )

                Spacer()

                // Controls
                HStack(spacing: 16) {
                    if recordingState == .recording || recordingState == .paused {
                        // Stop & Save button
                        Button {
                            stopAndSave()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(WatchTokens.accent)
                        }
                        .buttonStyle(.plain)

                        // Record/Pause button
                        Button {
                            toggleRecording()
                        } label: {
                            Image(systemName: recordingState == .recording ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(WatchTokens.textPrimary)
                        }
                        .buttonStyle(.plain)

                        // Discard button
                        Button {
                            discardRecording()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(WatchTokens.danger)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Idle — Record button
                        Button {
                            startRecording()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(WatchTokens.accent)
                                    .frame(width: 64, height: 64)
                                    .shadow(color: WatchTokens.accentGlow, radius: hasRecording ? 12 : 0)

                                Image(systemName: "mic.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(WatchTokens.background)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .onReceive(timer) { _ in
            if recordingState == .recording {
                recordingDuration += 0.1
                // Simulate waveform amplitude
                waveformAmplitude = CGFloat.random(in: 0.15...0.85)
            }
        }
        .sheet(isPresented: $showSaveDialog) {
            WatchSaveSheet(
                title: $recordingTitle,
                onSave: {
                    saveRecording()
                },
                onDiscard: {
                    discardRecording()
                }
            )
        }
    }

    private var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startRecording() {
        audioRecorder = WatchAudioRecorder()
        audioRecorder?.startRecording()
        recordingState = .recording
        recordingDuration = 0
        hasRecording = true
        WKInterfaceDevice.current().play(.start)
    }

    private func toggleRecording() {
        if recordingState == .recording {
            audioRecorder?.pauseRecording()
            recordingState = .paused
            WKInterfaceDevice.current().play(.retry)
        } else if recordingState == .paused {
            audioRecorder?.resumeRecording()
            recordingState = .recording
        }
    }

    private func stopAndSave() {
        audioRecorder?.stopRecording()
        recordingState = .idle
        showSaveDialog = true
        WKInterfaceDevice.current().play(.success)
    }

    private func discardRecording() {
        audioRecorder?.discardRecording()
        audioRecorder = nil
        recordingState = .idle
        recordingDuration = 0
        hasRecording = false
        waveformAmplitude = 0.1
    }

    private func saveRecording() {
        guard !recordingTitle.isEmpty else { return }
        audioRecorder?.saveRecording(title: recordingTitle)
        audioRecorder = nil
        recordingState = .idle
        recordingDuration = 0
        hasRecording = false
        waveformAmplitude = 0.1
        showSaveDialog = false
        recordingTitle = ""
    }
}

// MARK: - Waveform Circle

struct WaveformCircle: View {
    let state: WatchRecordingState
    let amplitude: CGFloat

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer glow ring
            if state == .recording {
                Circle()
                    .stroke(WatchTokens.accent.opacity(0.2), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseScale)
                    .opacity(2 - pulseScale)
            }

            // Main circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            WatchTokens.accent.opacity(state == .recording ? 0.3 : 0.15),
                            WatchTokens.surface
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 80, height: 80)

            // Waveform bars
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WatchTokens.accent)
                        .frame(width: 4, height: barHeight(for: i))
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: amplitude)
        .onChange(of: state) { _, newState in
            if newState == .recording {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    pulseScale = 1.5
                }
            } else {
                pulseScale = 1.0
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard state == .recording else { return 8 }
        let heights: [CGFloat] = [0.3, 0.7, 1.0, 0.5, 0.8]
        let base = heights[index % heights.count]
        return 8 + (40 * base * amplitude)
    }
}

// MARK: - Save Sheet

struct WatchSaveSheet: View {
    @Binding var title: String
    let onSave: () -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            WatchTokens.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Save Recording")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(WatchTokens.textPrimary)

                TextField("Title", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 8)

                HStack(spacing: 16) {
                    Button {
                        onDiscard()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                            .background(WatchTokens.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onSave()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14))
                            .foregroundColor(WatchTokens.background)
                            .frame(width: 44, height: 44)
                            .background(title.isEmpty ? WatchTokens.textSecondary : WatchTokens.accent)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(title.isEmpty)
                }
            }
            .padding()
        }
    }
}

// MARK: - Watch Audio Recorder

final class WatchAudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private var isPaused = false

    private let session = AVAudioSession()

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth])
            try session.setActive(true)
        } catch {
            print("WatchAudioRecorder setup error: \(error)")
        }
    }

    func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "watch_recording_\(UUID().uuidString).m4a"
        audioFileURL = documentsPath.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFileURL!, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isPaused = false
        } catch {
            print("Watch recording start error: \(error)")
        }
    }

    func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
    }

    func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
    }

    func stopRecording() {
        audioRecorder?.stop()
        try? session.setActive(false)
    }

    func discardRecording() {
        stopRecording()
        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        audioFileURL = nil
    }

    func saveRecording(title: String) {
        stopRecording()

        guard let url = audioFileURL else { return }

        // Save metadata to shared UserDefaults (App Group)
        let defaults = UserDefaults(suiteName: "group.com.crisp.app")
        var recordings = defaults?.array(forKey: "watch_recordings") as? [[String: Any]] ?? []

        let metadata: [String: Any] = [
            "id": UUID().uuidString,
            "title": title,
            "fileName": url.lastPathComponent,
            "createdAt": Date().timeIntervalSince1970,
            "duration": getAudioDuration()
        ]

        recordings.append(metadata)
        defaults?.set(recordings, forKey: "watch_recordings")
        defaults?.synchronize()

        // Move audio file to shared container
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.crisp.app") {
            let destURL = containerURL.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.moveItem(at: url, to: destURL)
        }
    }

    private func getAudioDuration() -> TimeInterval {
        guard let url = audioFileURL else { return 0 }
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
}
