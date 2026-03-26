import SwiftUI
import Combine
import WidgetKit

struct NoteDetailView: View {
    let note: VoiceNote
    let onDelete: () -> Void

    @StateObject private var playerService = AudioPlayerService()
    @StateObject private var aiService = AISummaryService()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showDeleteConfirmation = false
    @State private var showSpeedPicker = false
    @State private var showMoveSheet = false
    @State private var showShareSheet = false
    @State private var editedNote: VoiceNote
    @State private var exportError: String?
    @State private var showEditTranscription = false
    @State private var showMergeSheet = false
    @State private var showSplitSheet = false
    @State private var showProUpgradePrompt = false
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

                    // AI Insights (topic, sentiment, entities, speaking pace)
                    if editedNote.topic != nil || editedNote.sentiment != nil || !editedNote.detectedEntities.isEmpty {
                        let insightsResult = AnalysisResult(
                            summary: editedNote.aiSummary ?? "",
                            keywords: editedNote.aiKeywords,
                            actionItems: editedNote.actionItems,
                            topic: editedNote.topic,
                            sentiment: editedNote.sentiment,
                            entities: editedNote.detectedEntities,
                            speakingPace: editedNote.speakingPace,
                            folderSuggestion: editedNote.folderSuggestion
                        )
                        AIInsightsView(analysis: insightsResult)
                    }

                    // Transcription
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Transcription")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignTokens.textSecondary)

                                Spacer()

                                if subscriptionManager.tier.isPro {
                                    Button {
                                        showEditTranscription = true
                                    } label: {
                                        Text("Edit")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(DesignTokens.accent)
                                    }
                                }

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

                            if !subscriptionManager.tier.isPro {
                                ProFeatureBadge(label: "Edit transcription")
                                    .onTapGesture {
                                        showProUpgradePrompt = true
                                    }
                            }
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

                    // Advanced editing section
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            // Merge
                            AdvancedActionButton(
                                icon: "arrow.triangle.merge",
                                label: "Merge",
                                isPro: true,
                                onTap: {
                                    if subscriptionManager.tier.isPro {
                                        showMergeSheet = true
                                    } else {
                                        showProUpgradePrompt = true
                                    }
                                }
                            )

                            // Split
                            AdvancedActionButton(
                                icon: "scissors",
                                label: "Split",
                                isPro: true,
                                onTap: {
                                    if subscriptionManager.tier.isPro {
                                        showSplitSheet = true
                                    } else {
                                        showProUpgradePrompt = true
                                    }
                                }
                            )
                        }

                        if !subscriptionManager.tier.isPro {
                            TrialBanner(
                                daysRemaining: subscriptionManager.trialDaysRemaining,
                                onStartTrial: {
                                    subscriptionManager.startTrial(days: 3)
                                }
                            )
                        }
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

                    // Crisp Links — Pro feature for sharing as ephemeral links
                    VStack(spacing: 10) {
                        Text("Share")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignTokens.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        CrispLinkCard(note: editedNote)
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
        .sheet(isPresented: $showEditTranscription) {
            EditTranscriptionSheet(
                note: editedNote,
                onSave: { newText in
                    saveTranscription(newText)
                }
            )
        }
        .sheet(isPresented: $showMergeSheet) {
            MergeNotesSheet(
                currentNote: editedNote,
                onMergeComplete: { mergedNote in
                    onDelete()
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showSplitSheet) {
            SplitRecordingSheet(
                note: editedNote,
                onSplitComplete: {
                    onDelete()
                }
            )
        }
        .sheet(isPresented: $showProUpgradePrompt) {
            ProUpgradeSheet(
                feature: "advanced editing",
                onUpgrade: {
                    // handled by sheet
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
                    Text(editedNote.nonEmptySummary)
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
            let result = await aiService.analyze(
                transcription: editedNote.transcription,
                audioDuration: editedNote.duration
            )
            var updated = editedNote
            updated.aiSummary = result.summary
            updated.aiKeywords = result.keywords
            updated.actionItems = result.actionItems
            updated.topic = result.topic
            updated.sentiment = result.sentiment
            updated.detectedEntities = result.entities
            updated.speakingPace = result.speakingPace
            updated.folderSuggestion = result.folderSuggestion

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

    private func saveTranscription(_ newText: String) {
        editedNote.transcription = newText
        do {
            try DatabaseService.shared.updateNote(editedNote)
        } catch {
            print("Failed to save transcription: \(error)")
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

// MARK: - Pro Feature Badge

struct ProFeatureBadge: View {
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.accent)

            Text("Pro: \(label)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignTokens.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignTokens.accent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DesignTokens.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.top, 8)
    }
}

// MARK: - Trial Banner

struct TrialBanner: View {
    var daysRemaining: Int?
    let onStartTrial: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "FFD700"))

            VStack(alignment: .leading, spacing: 2) {
                Text("Try Pro free")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)

                if let days = daysRemaining, days > 0 {
                    Text("\(days) day\(days == 1 ? "" : "s") left in trial")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.textSecondary)
                } else {
                    Text("Unlock merge, split & edit for 3 days")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }

            Spacer()

            Button {
                onStartTrial()
            } label: {
                Text("Start Trial")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DesignTokens.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                .fill(DesignTokens.accent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                        .stroke(DesignTokens.accent.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Advanced Action Button

struct AdvancedActionButton: View {
    let icon: String
    let label: String
    var isPro: Bool = true
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard {
                VStack(spacing: 6) {
                    ZStack {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(DesignTokens.accent)

                        if isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .foregroundColor(DesignTokens.textSecondary)
                                .offset(x: 12, y: -10)
                        }
                    }

                    Text(label)
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Transcription Sheet

struct EditTranscriptionSheet: View {
    let note: VoiceNote
    let onSave: (String) -> Void

    @State private var editedText: String = ""
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Edit the transcription text below. Changes are saved directly to this note.")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.textSecondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    TextEditor(text: $editedText)
                        .scrollContentBackground(.hidden)
                        .background(DesignTokens.surface)
                        .foregroundColor(DesignTokens.textPrimary)
                        .font(.system(size: 16))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                                .stroke(DesignTokens.textSecondary.opacity(0.2), lineWidth: 1)
                        )
                        .frame(minHeight: 300)

                    if isSaving {
                        ProgressView()
                            .tint(DesignTokens.accent)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Edit Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 15))
                    .foregroundColor(DesignTokens.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignTokens.accent)
                    .disabled(editedText == note.transcription || isSaving)
                }
            }
        }
        .onAppear {
            editedText = note.transcription
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            do {
                try DatabaseService.shared.updateTranscription(noteId: note.id, newTranscription: editedText)
                await MainActor.run {
                    onSave(editedText)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Merge Notes Sheet

struct MergeNotesSheet: View {
    let currentNote: VoiceNote
    let onMergeComplete: (VoiceNote) -> Void

    @State private var allNotes: [VoiceNote] = []
    @State private var selectedNoteIds: Set<UUID> = [UUID()]
    @State private var isMerging = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Select one or more notes to merge with this one. All transcriptions will be combined in chronological order.")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.textSecondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    if let error = error {
                        InlineErrorBanner(
                            title: "Merge Failed",
                            message: error,
                            icon: "exclamationmark.triangle",
                            onDismiss: { self.error = nil }
                        )
                    }

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            // Current note (always included)
                            MergeNoteRow(
                                note: currentNote,
                                isSelected: true,
                                isCurrentNote: true,
                                onToggle: { }
                            )

                            ForEach(allNotes.filter { $0.id != currentNote.id }) { note in
                                MergeNoteRow(
                                    note: note,
                                    isSelected: selectedNoteIds.contains(note.id),
                                    isCurrentNote: false,
                                    onToggle: {
                                        if selectedNoteIds.contains(note.id) {
                                            selectedNoteIds.remove(note.id)
                                        } else {
                                            selectedNoteIds.insert(note.id)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.top, 4)
                    }

                    Button {
                        performMerge()
                    } label: {
                        HStack(spacing: 6) {
                            if isMerging {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(DesignTokens.background)
                            } else {
                                Image(systemName: "arrow.triangle.merge")
                                    .font(.system(size: 14))
                            }
                            Text("Merge \(selectedNoteIds.count) Notes")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(DesignTokens.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(selectedNoteIds.count >= 1 ? DesignTokens.accent : DesignTokens.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(selectedNoteIds.count < 1 || isMerging)
                }
                .padding(20)
            }
            .navigationTitle("Merge Recordings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 15))
                    .foregroundColor(DesignTokens.textSecondary)
                }
            }
        }
        .task {
            loadNotes()
            selectedNoteIds = [currentNote.id]
        }
    }

    private func loadNotes() {
        do {
            allNotes = try DatabaseService.shared.fetchAllNotes()
        } catch {
            allNotes = []
        }
    }

    private func performMerge() {
        isMerging = true
        error = nil

        Task {
            do {
                let notesToMerge = allNotes.filter { selectedNoteIds.contains($0.id) }
                let merged = try DatabaseService.shared.mergeNotes(notesToMerge)
                await MainActor.run {
                    onMergeComplete(merged)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isMerging = false
                }
            }
        }
    }
}

struct MergeNoteRow: View {
    let note: VoiceNote
    let isSelected: Bool
    var isCurrentNote: Bool = false
    let onToggle: () -> Void

    var body: some View {
        Button(action: isCurrentNote ? {} : onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? DesignTokens.accent : DesignTokens.textSecondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isCurrentNote ? "\(note.title) (this note)" : note.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignTokens.textPrimary)
                        .lineLimit(1)

                    Text("\(note.formattedDate) · \(note.formattedDuration)")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.textSecondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                    .fill(isSelected ? DesignTokens.accent.opacity(0.08) : DesignTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                            .stroke(isSelected ? DesignTokens.accent.opacity(0.3) : DesignTokens.textSecondary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isCurrentNote)
    }
}

// MARK: - Split Recording Sheet

struct SplitRecordingSheet: View {
    let note: VoiceNote
    let onSplitComplete: () -> Void

    @State private var splitProgress: Double = 0.5
    @State private var isSplitting = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var splitTimeText: String {
        let time = note.duration * splitProgress
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var remainingTimeText: String {
        let time = note.duration * (1 - splitProgress)
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Drag the divider to choose where to split the recording. Part 1 keeps the original, Part 2 becomes a new note.")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.textSecondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Waveform preview with split marker
                    GeometryReader { geo in
                        ZStack {
                            // Waveform bars (simplified)
                            HStack(spacing: 3) {
                                ForEach(0..<30, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(
                                            Double(i) / 30.0 < splitProgress
                                                ? DesignTokens.accent
                                                : DesignTokens.textSecondary.opacity(0.4)
                                        )
                                        .frame(width: 6, height: CGFloat.random(in: 20...60))
                                }
                            }
                            .padding(.horizontal, 16)

                            // Split divider
                            Rectangle()
                                .fill(DesignTokens.accent)
                                .frame(width: 2)
                                .offset(x: CGFloat(splitProgress - 0.5) * (geo.size.width - 64))
                        }
                        .frame(height: 80)
                    }
                    .background(DesignTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))

                    // Split position slider
                    VStack(spacing: 8) {
                        HStack {
                            Text(splitTimeText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignTokens.accent)

                            Spacer()

                            Text(remainingTimeText)
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.textSecondary)
                        }

                        Slider(value: $splitProgress, in: 0.1...0.9)
                            .tint(DesignTokens.accent)
                    }

                    // Preview labels
                    HStack {
                        VStack(spacing: 4) {
                            Text("Part 1")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DesignTokens.textPrimary)
                            Text(splitTimeText)
                                .font(.system(size: 11))
                                .foregroundColor(DesignTokens.textSecondary)
                        }
                        .frame(maxWidth: .infinity)

                        Image(systemName: "scissors")
                            .font(.system(size: 16))
                            .foregroundColor(DesignTokens.accent)

                        VStack(spacing: 4) {
                            Text("Part 2")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DesignTokens.textPrimary)
                            Text(remainingTimeText)
                                .font(.system(size: 11))
                                .foregroundColor(DesignTokens.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)

                    if let error = error {
                        InlineErrorBanner(
                            title: "Split Failed",
                            message: error,
                            icon: "exclamationmark.triangle",
                            onDismiss: { self.error = nil }
                        )
                    }

                    Button {
                        performSplit()
                    } label: {
                        HStack(spacing: 6) {
                            if isSplitting {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(DesignTokens.background)
                            } else {
                                Image(systemName: "scissors")
                                    .font(.system(size: 14))
                            }
                            Text("Split Recording")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(DesignTokens.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isSplitting)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Split Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 15))
                    .foregroundColor(DesignTokens.textSecondary)
                }
            }
        }
    }

    private func performSplit() {
        isSplitting = true
        error = nil

        Task {
            do {
                let splitAt = note.duration * splitProgress
                _ = try DatabaseService.shared.splitNote(id: note.id, splitAtTime: splitAt)
                await MainActor.run {
                    onSplitComplete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isSplitting = false
                }
            }
        }
    }
}

// MARK: - Pro Upgrade Sheet

struct ProUpgradeSheet: View {
    let feature: String
    let onUpgrade: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignTokens.textSecondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            VStack(spacing: 20) {
                // Crown icon
                ZStack {
                    Circle()
                        .fill(DesignTokens.accent.opacity(0.15))
                        .frame(width: 72, height: 72)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 28))
                        .foregroundColor(DesignTokens.accent)
                }
                .padding(.top, 8)

                VStack(spacing: 6) {
                    Text("Unlock \(feature)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignTokens.textPrimary)

                    Text("Upgrade to Pro to access merge, split, edit and all advanced features.")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                // Features list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(SubscriptionTier.proOnlyFeatures.prefix(5), id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(DesignTokens.accent)
                            Text(feature)
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.textPrimary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

                Button {
                    // Upgrade flow
                    dismiss()
                } label: {
                    Text("Upgrade to Pro")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignTokens.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Maybe Later")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(DesignTokens.background)
    }
}
