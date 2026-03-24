import SwiftUI
import Combine
import WidgetKit

struct NoteDetailView: View {
    let note: VoiceNote
    let onDelete: () -> Void

    @StateObject private var playerService = AudioPlayerService()
    @StateObject private var aiService = AISummaryService()
    @State private var showDeleteConfirmation = false
    @State private var showSpeedPicker = false
    @State private var showMoveSheet = false
    @State private var showShareSheet = false
    @State private var editedNote: VoiceNote
    @State private var exportError: String?
    @Environment(\.dismiss) private var dismiss

    private let exportService = ExportService()

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

                    // AI Summary card
                    aiSummaryCard

                    // Transcription
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Transcription")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignTokens.textSecondary)

                                Spacer()

                                Button {
                                    UIPasteboard.general.string = editedNote.transcription
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 13))
                                        .foregroundColor(DesignTokens.textSecondary)
                                }
                            }

                            Text(editedNote.transcription.isEmpty ? "No transcription available" : editedNote.transcription)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(DesignTokens.textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                    }

                    // Export error banner
                    if let error = exportError {
                        InlineErrorBanner(
                            title: "Export Failed",
                            message: error,
                            icon: "exclamationmark.triangle",
                            onDismiss: { exportError = nil }
                        )
                    }

                    // Actions
                    HStack(spacing: 12) {
                        ActionButton(
                            icon: "square.and.arrow.up",
                            label: "Share",
                            action: { showShareSheet = true }
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
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(
                note: editedNote,
                exportService: exportService,
                onError: { error in
                    exportError = error
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        exportError = nil
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onDisappear {
            playerService.stop()
        }
    }

    // MARK: - AI Summary Card

    @ViewBuilder
    private var aiSummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignTokens.accent)

                    Text("AI Summary")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignTokens.textSecondary)

                    Spacer()

                    if editedNote.hasAISummary {
                        Text("Generated")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(DesignTokens.accent.opacity(0.15))
                            )
                    } else if aiService.isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(DesignTokens.accent)
                    }
                }

                if editedNote.hasAISummary {
                    // Summary text
                    Text(editedNote.aiSummary!)
                        .font(.system(size: 15))
                        .foregroundColor(DesignTokens.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)

                    // Keywords
                    if !editedNote.aiKeywords.isEmpty {
                        Divider()
                            .background(DesignTokens.textSecondary.opacity(0.2))

                        HStack(spacing: 6) {
                            Text("Keywords")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DesignTokens.textSecondary)

                            FlowLayout(spacing: 6) {
                                ForEach(editedNote.aiKeywords, id: \.self) { keyword in
                                    Text(keyword)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(DesignTokens.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(DesignTokens.accent.opacity(0.12))
                                        )
                                }
                            }
                        }
                    }

                    // Action items
                    if !editedNote.actionItems.isEmpty {
                        Divider()
                            .background(DesignTokens.textSecondary.opacity(0.2))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Action Items")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DesignTokens.textSecondary)

                            ForEach(Array(editedNote.actionItems.enumerated()), id: \.offset) { index, item in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 6))
                                        .foregroundColor(DesignTokens.accent)
                                        .padding(.top, 5)

                                    Text("\(index + 1). \(item)")
                                        .font(.system(size: 13))
                                        .foregroundColor(DesignTokens.textPrimary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                    }

                    Button {
                        generateAISummary()
                    } label: {
                        Text("Regenerate")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                    .padding(.top, 4)

                } else {
                    // Empty state
                    Text("Generate an AI summary to get a quick overview of this transcription.")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.textSecondary)
                        .multilineTextAlignment(.leading)

                    Button {
                        generateAISummary()
                    } label: {
                        HStack(spacing: 6) {
                            if aiService.isAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(DesignTokens.background)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13))
                            }
                            Text("Generate Summary")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(DesignTokens.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(aiService.isAnalyzing || editedNote.transcription.isEmpty)
                    .opacity(editedNote.transcription.isEmpty ? 0.5 : 1)
                }

                if aiService.errorMessage != nil {
                    InlineErrorBanner(
                        title: "AI Unavailable",
                        message: aiService.errorMessage ?? "Could not generate summary",
                        icon: "exclamationmark.triangle",
                        onDismiss: { aiService.errorMessage = nil }
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: - Actions

    private func generateAISummary() {
        guard !editedNote.transcription.isEmpty else { return }

        Task {
            let result = await aiService.analyze(transcription: editedNote.transcription)
            var updated = editedNote
            updated.aiSummary = result.summary
            updated.aiKeywords = result.keywords
            updated.actionItems = result.actionItems

            do {
                try DatabaseService.shared.updateNote(updated)
                editedNote = updated
            } catch {
                print("Failed to save AI summary: \(error)")
            }
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

// MARK: - Share Sheet

struct ShareSheetView: View {
    let note: VoiceNote
    let exportService: ExportService
    let onError: (String) -> Void

    @State private var showExportAllSheet = false
    @State private var allNotes: [VoiceNote] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignTokens.textSecondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            VStack(spacing: 20) {
                Text("Share")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)
                    .padding(.top, 16)

                HStack(spacing: 16) {
                    ShareOptionButton(
                        icon: "doc.richtext",
                        label: "PDF",
                        sublabel: "Formatted export",
                        color: .red
                    ) {
                        sharePDF()
                    }

                    ShareOptionButton(
                        icon: "doc.plaintext",
                        label: "Text",
                        sublabel: "Plain text",
                        color: DesignTokens.accent
                    ) {
                        shareText()
                    }

                    ShareOptionButton(
                        icon: "square.and.arrow.up.on.square",
                        label: "Export All",
                        sublabel: "ZIP + JSON",
                        color: .blue
                    ) {
                        exportAllNotes()
                    }
                }

                Text("All exports are generated locally. No data leaves your device.")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DesignTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(DesignTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(DesignTokens.background)
        .sheet(isPresented: $showExportAllSheet) {
            ExportAllNotesSheet(notes: allNotes, exportService: exportService)
        }
    }

    private func sharePDF() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            onError("Share sheet unavailable")
            return
        }
        exportService.sharePDF(for: note, from: rootVC)
        dismiss()
    }

    private func shareText() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            onError("Share sheet unavailable")
            return
        }
        exportService.sharePlainText(for: note, from: rootVC)
        dismiss()
    }

    private func exportAllNotes() {
        Task {
            do {
                allNotes = try DatabaseService.shared.fetchAllNotes()
                if allNotes.isEmpty {
                    onError("No notes to export")
                    return
                }
                showExportAllSheet = true
            } catch {
                onError("Failed to load notes")
            }
        }
    }
}

// MARK: - Export All Notes Sheet

struct ExportAllNotesSheet: View {
    let notes: [VoiceNote]
    let exportService: ExportService

    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignTokens.textSecondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            VStack(spacing: 20) {
                Text("Export All Notes")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)
                    .padding(.top, 16)

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("\(notes.count)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(DesignTokens.accent)
                        Text("Notes")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.textSecondary)
                    }

                    VStack(spacing: 4) {
                        Text(totalDuration)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(DesignTokens.textPrimary)
                        Text("Total")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                }

                if let error = error {
                    InlineErrorBanner(
                        title: "Export Failed",
                        message: error,
                        icon: "exclamationmark.triangle",
                        onDismiss: { self.error = nil }
                    )
                }

                if isExporting {
                    ProgressView()
                        .tint(DesignTokens.accent)
                        .padding(.vertical, 12)
                    Text("Creating ZIP archive…")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.textSecondary)
                } else if showShare, let url = exportURL {
                    Text("Export ready!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignTokens.accent)
                        .padding(.vertical, 8)

                    ShareLink(item: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share ZIP")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignTokens.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                } else {
                    Button {
                        createExport()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up.on.square")
                            Text("Create ZIP Export")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignTokens.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(DesignTokens.background)
    }

    private var totalDuration: String {
        let total = notes.reduce(0) { $0 + $1.duration }
        let minutes = Int(total) / 60
        return "\(minutes)m"
    }

    private func createExport() {
        isExporting = true
        error = nil

        Task {
            do {
                let url = try exportService.createZIPExport(for: notes)
                await MainActor.run {
                    exportURL = url
                    showShare = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}

// MARK: - Share Option Button

struct ShareOptionButton: View {
    let icon: String
    let label: String
    let sublabel: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }

                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignTokens.textPrimary)

                    Text(sublabel)
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline Error Banner

struct InlineErrorBanner: View {
    let title: String
    let message: String
    let icon: String
    let onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.textSecondary)
            }

            Spacer()

            if let onDismiss = onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Flow Layout (for keywords)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = max(totalHeight, currentY + lineHeight)
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
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
                    SkipButton(direction: .backward) {
                        playerService.skipBackward()
                    }

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

                    SkipButton(direction: .forward) {
                        playerService.skipForward()
                    }
                }

                // Progress bar with scrubbing
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignTokens.textSecondary.opacity(0.3))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [DesignTokens.accentGradientStart, DesignTokens.accentGradientMid, DesignTokens.accentGradientEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, progressWidth(for: geometry.size.width)), height: 6)

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
        if speed == 1.0 { return "1×" }
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
                Text(speed == 1.0 ? "1×" : String(format: "%.1f×", speed))
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
}

// MARK: - Action Button

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
