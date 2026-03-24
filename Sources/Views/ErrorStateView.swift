import SwiftUI

// MARK: - Error State Manager

enum CrispError: Equatable {
    case microphonePermissionDenied
    case transcriptionFailed(String)
    case recordingTooLongForFreeTier
    case storageFull
    case noRecordings
    case folderCreationFailed
    case emptyFolder(String)
    case noSearchResults(String)

    var title: String {
        switch self {
        case .microphonePermissionDenied: return "Microphone access required"
        case .transcriptionFailed: return "Transcription failed"
        case .recordingTooLongForFreeTier: return "Recording too long"
        case .storageFull: return "Storage full"
        case .noRecordings: return "No recordings yet"
        case .folderCreationFailed: return "Could not create folder"
        case .emptyFolder(let name): return "\(name) is empty"
        case .noSearchResults: return "No results found"
        }
    }

    var message: String {
        switch self {
        case .microphonePermissionDenied:
            return "Crisp needs microphone access to record your voice notes. Please enable it in Settings."
        case .transcriptionFailed(let reason):
            return "Something went wrong during transcription: \(reason). Please try again."
        case .recordingTooLongForFreeTier:
            return "Your free plan supports recordings up to 10 minutes. Upgrade to Pro or Unlimited for longer recordings."
        case .storageFull:
            return "Your device is running low on storage. Free up some space to continue recording."
        case .noRecordings:
            return "Your transcribed voice notes will appear here. Tap the record button to capture your first thought."
        case .folderCreationFailed:
            return "Could not create folder. Please try again."
        case .emptyFolder(let name):
            return "'\(name)' is empty. Move recordings into this folder to keep them organized."
        case .noSearchResults(let query):
            return "No recordings found for \"\(query)\". Try different keywords."
        }
    }

    var iconName: String {
        switch self {
        case .microphonePermissionDenied: return "mic.slash.fill"
        case .transcriptionFailed: return "exclamationmark.triangle.fill"
        case .recordingTooLongForFreeTier: return "clock.badge.exclamationmark.fill"
        case .storageFull: return "externaldrive.fill.badge.xmark"
        case .noRecordings: return "waveform.badge.plus"
        case .folderCreationFailed: return "folder.badge.xmark"
        case .emptyFolder: return "folder"
        case .noSearchResults: return "magnifyingglass"
        }
    }

    var actionTitle: String? {
        switch self {
        case .microphonePermissionDenied: return "Open Settings"
        case .recordingTooLongForFreeTier: return "Upgrade plan"
        case .storageFull: return "Manage Storage"
        default: return nil
        }
    }
}

// MARK: - Generic Error State View

struct ErrorStateView: View {
    let error: CrispError
    var onAction: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor.opacity(0.15))
                    .frame(width: 96, height: 96)

                Image(systemName: error.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(iconBackgroundColor)
            }

            VStack(spacing: 10) {
                Text(error.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DesignTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text(error.message)
                    .font(.system(size: 15))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle = error.actionTitle, let onAction = onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignTokens.background)
                        .frame(height: 50)
                        .frame(maxWidth: 220)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 8)
            }

            if onDismiss != nil {
                Button {
                    onDismiss?()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DesignTokens.textSecondary)
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var iconBackgroundColor: Color {
        switch error {
        case .microphonePermissionDenied: return .orange
        case .transcriptionFailed: return .red
        case .recordingTooLongForFreeTier: return .orange
        case .storageFull: return .red
        case .noRecordings: return DesignTokens.accent
        case .folderCreationFailed: return .red
        case .emptyFolder: return DesignTokens.accent
        case .noSearchResults: return DesignTokens.accent
        }
    }
}

// MARK: - Error Alert Modifier

struct CrispErrorAlert: View {
    let error: CrispError
    @Binding var isPresented: Bool
    var onAction: (() -> Void)?

    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }

                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: error.iconName)
                            .font(.system(size: 28))
                            .foregroundColor(DesignTokens.accent)

                        Spacer()

                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignTokens.textSecondary)
                                .padding(8)
                                .background(DesignTokens.surface)
                                .clipShape(Circle())
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DesignTokens.textPrimary)

                        Text(error.message)
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let actionTitle = error.actionTitle, let onAction = onAction {
                        Button(action: {
                            isPresented = false
                            onAction()
                        }) {
                            Text(actionTitle)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(DesignTokens.background)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(DesignTokens.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(DesignTokens.surface)
                        .overlay(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 32)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

// MARK: - Recording Too Long Error Sheet

struct RecordingLimitSheet: View {
    @Binding var isPresented: Bool
    var currentDuration: TimeInterval
    var maxDuration: TimeInterval
    var onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)

                Text("Recording limit reached")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DesignTokens.textPrimary)

                Text("Your free plan supports recordings up to 10 minutes. This recording is \(formattedDuration(currentDuration)).")
                    .font(.system(size: 15))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 12) {
                Button(action: onUpgrade) {
                    Text("Upgrade to Pro")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignTokens.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    isPresented = false
                } label: {
                    Text("Continue without saving")
                        .font(.system(size: 15))
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
        }
        .padding(24)
        .background(DesignTokens.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Empty Library State

struct EmptyLibraryGraphic: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(DesignTokens.surface)
                .frame(width: 160, height: 160)

            // Animated waveform bars
            HStack(spacing: 5) {
                ForEach(0..<6, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.accentGradientStart, DesignTokens.accentGradientEnd],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 7, height: barHeight(for: i))
                        .opacity(0.5)
                }
            }

            // Plus badge
            Circle()
                .fill(DesignTokens.accent)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignTokens.background)
                )
                .offset(x: 60, y: 60)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [24, 40, 56, 40, 24, 36]
        return heights[index]
    }
}
