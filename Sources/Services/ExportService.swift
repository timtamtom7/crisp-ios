import Foundation
import PDFKit
import UIKit

/// Service for exporting voice notes as PDF, plain text, or bulk ZIP/JSON.
enum ExportError: LocalizedError {
    case pdfGenerationFailed
    case zipCreationFailed
    case noNotesToExport
    case shareSheetUnavailable

    var errorDescription: String? {
        switch self {
        case .pdfGenerationFailed: return "Failed to generate PDF"
        case .zipCreationFailed: return "Failed to create ZIP archive"
        case .noNotesToExport: return "No notes available to export"
        case .shareSheetUnavailable: return "Share sheet unavailable"
        }
    }
}

final class ExportService {
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .short
        return df
    }()

    // MARK: - PDF Export

    /// Generates a formatted PDF for a single voice note.
    func generatePDF(for note: VoiceNote) throws -> Data {
        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 72      // 1 inch margins

        let pdfMetaData = [
            kCGPDFContextCreator: "Crisp",
            kCGPDFContextAuthor: "Crisp Voice Notes",
            kCGPDFContextTitle: note.title
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            let contentWidth = pageWidth - (margin * 2)
            var yPosition: CGFloat = margin

            // ── Header background ──────────────────────────────────────────
            let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 120)
            let headerPath = UIGraphicsGetCurrentContext()! 
            headerPath.setFillColor(UIColor(red: 0.053, green: 0.053, blue: 0.055, alpha: 1.0).cgColor)
            headerPath.fill(headerRect)

            // ── App logo / waveform icon ──────────────────────────────────
            let iconSize: CGFloat = 28
            let iconRect = CGRect(x: margin, y: yPosition + 20, width: iconSize, height: iconSize)
            if let iconImage = UIImage(systemName: "waveform") {
                let tintedIcon = iconImage.withTintColor(UIColor(red: 0.784, green: 0.663, blue: 0.494, alpha: 1.0))
                tintedIcon.draw(in: iconRect)
            }

            // ── "Crisp" app name ──────────────────────────────────────────
            let appNameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor(red: 0.784, green: 0.663, blue: 0.494, alpha: 1.0)
            ]
            let appNameRect = CGRect(x: margin + iconSize + 8, y: yPosition + 22, width: contentWidth, height: 24)
            "Crisp".draw(in: appNameRect, withAttributes: appNameAttrs)

            yPosition += 72

            // ── Note title ────────────────────────────────────────────────
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let titleRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 36)
            note.title.draw(in: titleRect, withAttributes: titleAttrs)
            yPosition += 44

            // ── Date + duration ────────────────────────────────────────────
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor(red: 0.545, green: 0.545, blue: 0.557, alpha: 1.0)
            ]
            let metaText = "\(dateFormatter.string(from: note.createdAt))  ·  \(note.formattedDuration)"
            let metaRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 20)
            metaText.draw(in: metaRect, withAttributes: metaAttrs)
            yPosition += 32

            // ── Divider ───────────────────────────────────────────────────
            let dividerPath = UIGraphicsGetCurrentContext()!
            dividerPath.setStrokeColor(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1.0).cgColor)
            dividerPath.setLineWidth(1)
            dividerPath.move(to: CGPoint(x: margin, y: yPosition))
            dividerPath.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            dividerPath.strokePath()
            yPosition += 24

            // ── "Transcription" section label ─────────────────────────────
            let sectionLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor(red: 0.545, green: 0.545, blue: 0.557, alpha: 1.0)
            ]
            let sectionRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 16)
            "TRANSCRIPTION".draw(in: sectionRect, withAttributes: sectionLabelAttrs)
            yPosition += 24

            // ── Transcription text ────────────────────────────────────────
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1.0)
            ]

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            var bodyAttrsWithParagraph = bodyAttrs
            bodyAttrsWithParagraph[.paragraphStyle] = paragraphStyle

            let transcriptionRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: pageHeight - yPosition - margin)
            let transcriptionText = note.transcription.isEmpty ? "No transcription available." : note.transcription

            let attributedTranscription = NSAttributedString(string: transcriptionText, attributes: bodyAttrsWithParagraph)
            let textBounds = attributedTranscription.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)

            if textBounds.height > transcriptionRect.height {
                // Need new page
                context.beginPage()
                yPosition = margin
            }

            attributedTranscription.draw(in: transcriptionRect)

            // ── AI Summary section (if available) ──────────────────────────
            if note.hasAISummary {
                yPosition += textBounds.height + 40

                if yPosition > pageHeight - 200 {
                    context.beginPage()
                    yPosition = margin
                }

                // Summary section divider
                let sumDividerPath = UIGraphicsGetCurrentContext()!
                sumDividerPath.setStrokeColor(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1.0).cgColor)
                sumDividerPath.setLineWidth(1)
                sumDividerPath.move(to: CGPoint(x: margin, y: yPosition))
                sumDividerPath.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
                sumDividerPath.strokePath()
                yPosition += 20

                // "AI Summary" label
                let sumLabelAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: UIColor(red: 0.784, green: 0.663, blue: 0.494, alpha: 1.0)
                ]
                let sumLabelRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 16)
                "AI SUMMARY".draw(in: sumLabelRect, withAttributes: sumLabelAttrs)
                yPosition += 24

                let summaryAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.italicSystemFont(ofSize: 14),
                    .foregroundColor: UIColor(red: 0.8, green: 0.8, blue: 0.82, alpha: 1.0)
                ]
                var summaryAttrsWithParagraph = summaryAttrs
                summaryAttrsWithParagraph[.paragraphStyle] = paragraphStyle

                let summaryAttrString = NSAttributedString(string: note.aiSummary!, attributes: summaryAttrsWithParagraph)
                let summaryBounds = summaryAttrString.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)

                if yPosition + summaryBounds.height > pageHeight - margin {
                    context.beginPage()
                    yPosition = margin
                }

                summaryAttrString.draw(in: CGRect(x: margin, y: yPosition, width: contentWidth, height: summaryBounds.height + 20))
                yPosition += summaryBounds.height + 30

                // Keywords
                if !note.aiKeywords.isEmpty {
                    let kwLabelAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                        .foregroundColor: UIColor(red: 0.545, green: 0.545, blue: 0.557, alpha: 1.0)
                    ]
                    let kwRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 16)
                    "KEYWORDS".draw(in: kwRect, withAttributes: kwLabelAttrs)
                    yPosition += 20

                    let kwAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                        .foregroundColor: UIColor(red: 0.784, green: 0.663, blue: 0.494, alpha: 1.0)
                    ]
                    let kwText = note.aiKeywords.joined(separator: "  ·  ")
                    kwText.draw(in: CGRect(x: margin, y: yPosition, width: contentWidth, height: 20), withAttributes: kwAttrs)
                    yPosition += 24

                    // Action items
                    if !note.actionItems.isEmpty {
                        let aiLabelAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                            .foregroundColor: UIColor(red: 0.545, green: 0.545, blue: 0.557, alpha: 1.0)
                        ]
                        let aiLabelRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 16)
                        "ACTION ITEMS".draw(in: aiLabelRect, withAttributes: aiLabelAttrs)
                        yPosition += 20

                        let aiItemAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                            .foregroundColor: UIColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1.0)
                        ]
                        for (index, item) in note.actionItems.enumerated() {
                            let bullet = "  \(index + 1).  \(item)"
                            bullet.draw(in: CGRect(x: margin, y: yPosition, width: contentWidth, height: 20), withAttributes: aiItemAttrs)
                            yPosition += 20
                        }
                    }
                }
            }

            // ── Footer ─────────────────────────────────────────────────────
            let footerY = pageHeight - margin + 12
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor(red: 0.3, green: 0.3, blue: 0.33, alpha: 1.0)
            ]
            let footerText = "Exported from Crisp · \(dateFormatter.string(from: Date()))"
            let footerRect = CGRect(x: margin, y: footerY, width: contentWidth, height: 16)
            footerText.draw(in: footerRect, withAttributes: footerAttrs)
        }

        return data
    }

    // MARK: - Plain Text Export

    func generatePlainText(for note: VoiceNote) -> String {
        var text = """
        ═══════════════════════════════════════
                       CRISP
        ═══════════════════════════════════════

        \(note.title)
        \(dateFormatter.string(from: note.createdAt))  ·  \(note.formattedDuration)

        ─────────── TRANSCRIPTION ───────────

        \(note.transcription.isEmpty ? "No transcription available." : note.transcription)

        """

        if note.hasAISummary {
            text += """

            ──────────── AI SUMMARY ────────────

            \(note.aiSummary!)

            """

            if !note.aiKeywords.isEmpty {
                text += "Keywords: \(note.aiKeywords.joined(separator: ", "))\n"
            }

            if !note.actionItems.isEmpty {
                text += "\nAction Items:\n"
                for (index, item) in note.actionItems.enumerated() {
                    text += "  \(index + 1). \(item)\n"
                }
            }
        }

        text += """

        ───────────────────────────────────────
        Exported from Crisp · \(dateFormatter.string(from: Date()))
        """
        return text
    }

    // MARK: - Bulk JSON Export

    func generateJSON(for notes: [VoiceNote]) throws -> Data {
        guard !notes.isEmpty else { throw ExportError.noNotesToExport }

        struct ExportPayload: Codable {
            let exportedAt: Date
            let version: String
            let notes: [VoiceNote]
        }

        let payload = ExportPayload(
            exportedAt: Date(),
            version: "1.0",
            notes: notes
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    // MARK: - ZIP Export

    func createZIPExport(for notes: [VoiceNote]) throws -> URL {
        guard !notes.isEmpty else { throw ExportError.noNotesToExport }

        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent("CrispExport_\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        // Write JSON file
        let jsonData = try generateJSON(for: notes)
        try jsonData.write(to: exportDir.appendingPathComponent("crisp_notes.json"))

        // Write individual text files
        for note in notes {
            let safeTitle = note.title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .prefix(50)
            let fileName = "\(safeTitle)_\(note.id.uuidString.prefix(8)).txt"
            let textContent = generatePlainText(for: note)
            try textContent.write(to: exportDir.appendingPathComponent(String(fileName)), atomically: true, encoding: .utf8)
        }

        // Create ZIP using coordinator
        let zipURL = tempDir.appendingPathComponent("CrispExport.zip")
        try? FileManager.default.removeItem(at: zipURL)

        let coordinator = NSFileCoordinator()
        var error: NSError?

        coordinator.coordinate(readingItemAt: exportDir, options: [.forUploading], error: &error) { url in
            do {
                try FileManager.default.copyItem(at: url, to: zipURL)
            } catch {
                print("ZIP creation error: \(error)")
            }
        }

        if let error = error {
            throw ExportError.zipCreationFailed
        }

        // Cleanup export dir
        try? FileManager.default.removeItem(at: exportDir)

        return zipURL
    }

    // MARK: - Share

    func sharePDF(for note: VoiceNote, from viewController: UIViewController) {
        do {
            let pdfData = try generatePDF(for: note)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(note.title).pdf")
            try pdfData.write(to: tempURL)

            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )
            viewController.present(activityVC, animated: true)
        } catch {
            print("PDF share error: \(error)")
        }
    }

    func sharePlainText(for note: VoiceNote, from viewController: UIViewController) {
        let text = generatePlainText(for: note)
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        viewController.present(activityVC, animated: true)
    }
}
