import SwiftUI
import Combine
import WidgetKit

struct CaptureView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CaptureViewModel()
    @State private var showSettings = false
    @State private var showQualityPicker = false
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
                    .accessibilityLabel("Settings")

                    Spacer()

                    // Quality indicator
                    if viewModel.state == .idle {
                        Button {
                            showQualityPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: viewModel.qualityIcon)
                                    .font(.system(size: 12))
                                Text(viewModel.currentQuality.displayName)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(DesignTokens.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(DesignTokens.surface)
                            )
                        }
                        .accessibilityLabel("Recording quality: \(viewModel.currentQuality.displayName). Tap to change.")
                    }

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
        .sheet(isPresented: $showQualityPicker) {
            RecordingQualitySheet(
                currentQuality: viewModel.currentQuality,
                onSelect: { quality in
                    viewModel.setRecordingQuality(quality)
                }
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
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
    @Published var currentQuality: RecordingQuality = .high

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

    /// SF Symbol name for the current recording quality.
    var qualityIcon: String {
        switch currentQuality {
        case .standard: return "waveform"
        case .high: return "waveform"
        }
    }

    init() {
        setupBindings()
        loadQuality()
    }

    private func setupBindings() {
        recorderService.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        transcriptionService.$transcribedText
            .receive(on: DispatchQueue.main)
            .assign(to: &$transcribedText)
    }

    private func loadQuality() {
        let settings = SettingsService().load()
        currentQuality = settings.recordingQuality
        recorderService.recordingQuality = currentQuality
    }

    func setRecordingQuality(_ quality: RecordingQuality) {
        currentQuality = quality
        recorderService.recordingQuality = quality
        var settings = SettingsService().load()
        settings.recordingQuality = quality
        SettingsService().save(settings)
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

// MARK: - Recording Quality Sheet

/// A bottom sheet for selecting the recording quality preset.
struct RecordingQualitySheet: View {
    let currentQuality: RecordingQuality
    let onSelect: (RecordingQuality) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignTokens.textSecondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            VStack(spacing: 20) {
                Text("Recording Quality")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)
                    .padding(.top, 16)

                VStack(spacing: 10) {
                    ForEach(RecordingQuality.allCases, id: \.self) { quality in
                        QualityOptionRow(
                            quality: quality,
                            isSelected: currentQuality == quality,
                            onTap: {
                                onSelect(quality)
                                dismiss()
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)

                Text("Higher quality uses more storage. All recordings use AAC compression.")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(DesignTokens.background)
    }
}

struct QualityOptionRow: View {
    let quality: RecordingQuality
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? DesignTokens.accent : DesignTokens.surface)
                        .frame(width: 44, height: 44)

                    Image(systemName: quality == .high ? "waveform" : "waveform")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? DesignTokens.background : DesignTokens.textSecondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(quality.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DesignTokens.textPrimary)

                    Text("\(quality.description) · \(quality.bitrate)")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignTokens.accent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                    .fill(isSelected ? DesignTokens.accent.opacity(0.08) : DesignTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                            .stroke(
                                isSelected ? DesignTokens.accent.opacity(0.4) : DesignTokens.textSecondary.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(quality.displayName): \(quality.description), \(quality.bitrate)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
