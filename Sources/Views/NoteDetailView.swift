import SwiftUI

struct NoteDetailView: View {
    let note: VoiceNote
    let onDelete: () -> Void

    @StateObject private var playerService = AudioPlayerService()
    @State private var showDeleteConfirmation = false
    @State private var showSpeedPicker = false
    @State private var showMoveSheet = false
    @State private var editedNote: VoiceNote
    @Environment(\.dismiss) private var dismiss

    init(note: VoiceNote, onDelete: @escaping () -> Void) {
        self.note = note
        self.onDelete = onDelete
        self._editedNote = State(initialValue: note)
    }

    var body: some View {
        ZStack {
            DesignTokens.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Audio player with playback controls
                    AudioPlayerCard(
                        note: editedNote,
                        playerService: playerService,
                        onSpeedTap: { showSpeedPicker = true }
                    )

                    // Transcription
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transcription")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignTokens.textSecondary)

                            Text(editedNote.transcription.isEmpty ? "No transcription available" : editedNote.transcription)
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
                            icon: "folder",
                            label: "Move",
                            action: { showMoveSheet = true }
                        )

                        ActionButton(
                            icon: editedNote.isFavorite ? "star.fill" : "star",
                            label: editedNote.isFavorite ? "Unfavorite" : "Favorite",
                            action: toggleFavorite
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
        .navigationTitle(editedNote.title)
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
        .sheet(isPresented: $showSpeedPicker) {
            SpeedPickerSheet(
                currentSpeed: playerService.playbackRate,
                onSelect: { speed in
                    playerService.setSpeed(speed)
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMoveSheet) {
            FolderPickerView(
                selectedFolderId: $editedNote.folderId,
                onNoteMove: { newFolderId in
                    editedNote.folderId = newFolderId
                    do {
                        try DatabaseService.shared.moveNoteToFolder(noteId: note.id, folderId: newFolderId)
                    } catch {
                        print("Failed to move note: \(error)")
                    }
                }
            )
        }
        .onDisappear {
            playerService.stop()
        }
    }

    private func copyText() {
        UIPasteboard.general.string = editedNote.transcription
    }

    private func shareText() {
        let activityVC = UIActivityViewController(
            activityItems: [editedNote.transcription],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func toggleFavorite() {
        do {
            try DatabaseService.shared.toggleFavorite(noteId: editedNote.id)
            editedNote.isFavorite.toggle()
        } catch {
            print("Failed to toggle favorite: \(error)")
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

// MARK: - Enhanced Audio Player Card

struct AudioPlayerCard: View {
    let note: VoiceNote
    @ObservedObject var playerService: AudioPlayerService
    let onSpeedTap: () -> Void

    @State private var isDragging = false
    @State private var dragProgress: CGFloat = 0

    var body: some View {
        GlassCard {
            VStack(spacing: 20) {
                // Playback controls row
                HStack(spacing: 24) {
                    // Skip backward
                    SkipButton(direction: .backward) {
                        playerService.skipBackward()
                    }

                    // Play/Pause
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

                    // Skip forward
                    SkipButton(direction: .forward) {
                        playerService.skipForward()
                    }
                }

                // Progress bar with scrubbing
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Track background
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignTokens.textSecondary.opacity(0.3))
                                .frame(height: 6)

                            // Progress fill
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [DesignTokens.accentGradientStart, DesignTokens.accentGradientMid, DesignTokens.accentGradientEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, progressWidth(for: geometry.size.width)), height: 6)

                            // Thumb
                            Circle()
                                .fill(DesignTokens.accent)
                                .frame(width: 14, height: 14)
                                .offset(x: progressWidth(for: geometry.size.width) - 7)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            isDragging = true
                                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                            dragProgress = progress
                                        }
                                        .onEnded { value in
                                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                            let newTime = note.duration * Double(progress)
                                            playerService.seek(to: newTime)
                                            isDragging = false
                                        }
                                )
                        }
                    }
                    .frame(height: 14)

                    HStack {
                        Text(formatTime(isDragging ? note.duration * Double(dragProgress) : playerService.currentTime))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignTokens.textPrimary)
                            .monospacedDigit()

                        Spacer()

                        Text(formatTime(note.duration))
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.textSecondary)
                            .monospacedDigit()
                    }
                }

                // Speed selector
                HStack {
                    Spacer()

                    Button(action: onSpeedTap) {
                        HStack(spacing: 6) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 13))

                            Text(speedLabel)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(DesignTokens.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(DesignTokens.accent.opacity(0.15))
                        )
                    }

                    Spacer()
                }

                Text(note.formattedDate)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.textSecondary)
            }
            .padding(20)
        }
    }

    private var speedLabel: String {
        let speed = playerService.playbackRate
        if speed == 1.0 {
            return "1×"
        }
        return String(format: "%.1f×", speed)
    }

    private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
        guard note.duration > 0 else { return 0 }
        let progress = isDragging ? dragProgress : CGFloat(playerService.currentTime / note.duration)
        return totalWidth * max(0, min(1, progress))
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

// MARK: - Skip Button

struct SkipButton: View {
    enum Direction {
        case backward, forward
    }

    let direction: Direction
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(DesignTokens.surface)
                    .frame(width: 44, height: 44)

                if direction == .backward {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 18))
                        .foregroundColor(DesignTokens.textPrimary)
                } else {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 18))
                        .foregroundColor(DesignTokens.textPrimary)
                }
            }
        }
    }
}

// MARK: - Speed Picker Sheet

struct SpeedPickerSheet: View {
    let currentSpeed: Float
    let onSelect: (Float) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignTokens.textSecondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            VStack(spacing: 20) {
                Text("Playback Speed")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)
                    .padding(.top, 16)

                HStack(spacing: 12) {
                    ForEach(AudioPlayerService.speedOptions, id: \.self) { speed in
                        SpeedOptionButton(
                            speed: speed,
                            isSelected: currentSpeed == speed,
                            onTap: {
                                onSelect(speed)
                                dismiss()
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(DesignTokens.background)
    }
}

struct SpeedOptionButton: View {
    let speed: Float
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(speedLabel)
                    .font(.system(size: 20, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? DesignTokens.background : DesignTokens.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? DesignTokens.accent : DesignTokens.surface)
            )
        }
        .buttonStyle(.plain)
    }

    private var speedLabel: String {
        if speed == 1.0 {
            return "1×"
        }
        return String(format: "%.1f×", speed)
    }
}

// MARK: - Action Button (already defined above, but keeping for reference)

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
