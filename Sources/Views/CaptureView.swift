import SwiftUI
import Combine
import WidgetKit

struct CaptureView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CaptureViewModel()
    @State private var showSettings = false
    @Binding var showPricing: Bool

    var body: some View {
        ZStack {
            DesignTokens.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundColor(DesignTokens.textSecondary)
                    }

                    Spacer()

                    if viewModel.state != .idle {
                        Button("Done") {
                            viewModel.stopRecording()
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DesignTokens.accent)
                    } else {
                        Button {
                            showPricing = true
                        } label: {
                            Text("Crisp")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(DesignTokens.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Waveform
                WaveformView(audioLevel: viewModel.audioLevel, isAnimating: viewModel.state == .listening)
                    .frame(height: 120)
                    .padding(.horizontal, 24)

                // Status text
                Text(viewModel.statusText)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.textSecondary)
                    .padding(.top, 12)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.state)

                // Transcription area
                if !viewModel.transcribedText.isEmpty {
                    GlassCard {
                        Text(viewModel.transcribedText)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(DesignTokens.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Record button
                RecordButton(
                    state: viewModel.state,
                    action: {
                        viewModel.toggleRecording()
                    }
                )
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .alert("Permission Required", isPresented: $viewModel.showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.permissionAlertMessage)
        }
    }
}

@MainActor
final class CaptureViewModel: ObservableObject {
    enum State {
        case idle
        case listening
        case processing
        case saved
    }

    @Published var state: State = .idle
    @Published var transcribedText = ""
    @Published var audioLevel: Float = 0.0
    @Published var showPermissionAlert = false
    @Published var permissionAlertMessage = ""

    private let recorderService = AudioRecorderService()
    private let transcriptionService = TranscriptionService()
    private var cancellables = Set<AnyCancellable>()

    var statusText: String {
        switch state {
        case .idle: return "Tap to record"
        case .listening: return "Listening..."
        case .processing: return "Saving..."
        case .saved: return "Saved!"
        }
    }

    init() {
        setupBindings()
    }

    private func setupBindings() {
        recorderService.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        transcriptionService.$transcribedText
            .receive(on: DispatchQueue.main)
            .assign(to: &$transcribedText)
    }

    func toggleRecording() {
        if state == .idle {
            startRecording()
        } else {
            stopRecording()
        }
    }

    private func startRecording() {
        Task {
            let authorized = await transcriptionService.requestAuthorization()
            guard authorized else {
                permissionAlertMessage = "Microphone and speech recognition access are required to record and transcribe voice memos."
                showPermissionAlert = true
                return
            }

            do {
                try recorderService.startRecording()
                try transcriptionService.startTranscribing()
                state = .listening
            } catch {
                permissionAlertMessage = "Failed to start recording: \(error.localizedDescription)"
                showPermissionAlert = true
            }
        }
    }

    func stopRecording() {
        state = .processing

        transcriptionService.stopTranscribing()
        let result = recorderService.stopRecording()

        guard let (url, duration) = result else {
            state = .idle
            return
        }

        Task {
            let title = String(transcribedText.prefix(50)).isEmpty
                ? "Voice Note"
                : String(transcribedText.prefix(50))

            let note = VoiceNote(
                title: title,
                transcription: transcribedText,
                audioFileURL: url,
                duration: duration
            )

            do {
                try DatabaseService.shared.saveNote(note)

                // Refresh widget notes after saving
                WidgetCenter.shared.reloadTimelines(ofKind: "CrispWidget")

                state = .saved

                try? await Task.sleep(nanoseconds: 1_500_000_000)

                state = .idle
                transcribedText = ""
            } catch {
                state = .idle
            }
        }
    }
}
