import SwiftUI

/// Sheet for exporting multiple selected notes as a ZIP archive.
struct BulkExportSheet: View {
    let noteIds: [UUID]

    @State private var notes: [VoiceNote] = []
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private let exportService = ExportService()

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignTokens.textSecondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            VStack(spacing: 20) {
                Text("Export \(notes.count) Notes")
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
        .task {
            loadNotes()
        }
    }

    private var totalDuration: String {
        let total = notes.reduce(0) { $0 + $1.duration }
        let minutes = Int(total) / 60
        return "\(minutes)m"
    }

    private func loadNotes() {
        do {
            notes = try DatabaseService.shared.fetchNotes(ids: noteIds)
        } catch {
            self.error = "Failed to load notes"
        }
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
