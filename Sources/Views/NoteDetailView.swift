import SwiftUI

struct NoteDetailView: View {
    let note: VoiceNote
    let onDelete: () -> Void

    @StateObject private var playerService = AudioPlayerService()
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DesignTokens.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Audio player
                    AudioPlayerCard(
                        note: note,
                        playerService: playerService
                    )

                    // Transcription
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transcription")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignTokens.textSecondary)

                            Text(note.transcription.isEmpty ? "No transcription available" : note.transcription)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(DesignTokens.textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                    }

                    // Actions
                    HStack(spacing: 12) {
                        ActionButton(
                            icon: "doc.on.doc",
                            label: "Copy",
                            action: copyText
                        )

                        ActionButton(
                            icon: "square.and.arrow.up",
                            label: "Share",
                            action: shareText
                        )

                        ActionButton(
                            icon: "trash",
                            label: "Delete",
                            isDestructive: true,
                            action: { showDeleteConfirmation = true }
                        )
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DesignTokens.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("Delete Note", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteNote()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this note? This action cannot be undone.")
        }
    }

    private func copyText() {
        UIPasteboard.general.string = note.transcription
    }

    private func shareText() {
        let activityVC = UIActivityViewController(
            activityItems: [note.transcription],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func deleteNote() {
        do {
            try DatabaseService.shared.deleteNote(id: note.id)
            try? FileManager.default.removeItem(at: note.audioFileURL)
            onDelete()
            dismiss()
        } catch {
            print("Failed to delete note: \(error)")
        }
    }
}

struct AudioPlayerCard: View {
    let note: VoiceNote
    @ObservedObject var playerService: AudioPlayerService

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                // Play/Pause button
                Button {
                    togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(DesignTokens.accent)
                            .frame(width: 56, height: 56)

                        Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(DesignTokens.background)
                    }
                }

                // Progress bar
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DesignTokens.textSecondary.opacity(0.3))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(DesignTokens.accent)
                                .frame(width: progressWidth(for: geometry.size.width), height: 4)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text(formatTime(playerService.currentTime))
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.textSecondary)

                        Spacer()

                        Text(formatTime(note.duration))
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                }

                Text(note.formattedDate)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.textSecondary)
            }
            .padding(20)
        }
    }

    private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
        guard note.duration > 0 else { return 0 }
        return totalWidth * CGFloat(playerService.currentTime / note.duration)
    }

    private func togglePlayback() {
        if playerService.isPlaying {
            playerService.pause()
        } else {
            do {
                try playerService.play(url: note.audioFileURL)
            } catch {
                print("Playback error: \(error)")
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isDestructive ? .red : DesignTokens.accent)

                    Text(label)
                        .font(.system(size: 12))
                        .foregroundColor(isDestructive ? .red : DesignTokens.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .buttonStyle(.plain)
    }
}
