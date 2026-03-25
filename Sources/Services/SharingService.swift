import Foundation

/// R11: Sharing service for Crisp
/// Supports sharing audio (M4A), transcript (text/PDF), and quote cards (image)
final class SharingService: @unchecked Sendable {
    static let shared = SharingService()

    private init() {}

    enum ShareType {
        case audio
        case transcript
        case quoteCard
    }

    /// Share an audio recording as M4A
    func shareAudio(note: VoiceNote) async throws -> URL {
        let sourceURL = note.audioFileURL
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("\(note.title ?? "recording").m4a")

        try? FileManager.default.removeItem(at: outputURL)

        if FileManager.default.fileExists(atPath: sourceURL.path) {
            // Already M4A, copy to temp
            try FileManager.default.copyItem(at: sourceURL, to: outputURL)
        } else {
            // Convert to M4A
            // For now, just return the original URL if it exists
            return sourceURL
        }

        return outputURL
    }

    /// Export transcript as plain text
    func exportTranscriptAsText(note: VoiceNote, transcription: String) -> String {
        var text = ""
        text += "Crisp Recording\n"
        text += "Title: \(note.title ?? "Untitled")\n"
        text += "Date: \(formatDate(note.createdAt))\n"
        text += "Duration: \(formatDuration(note.duration))\n"
        text += "\n---\n\n"
        text += transcription
        text += "\n\n---\nExported from Crisp"
        return text
    }

    /// Generate a quote card image from a transcript segment
    func generateQuoteCard(text: String, sourceTitle: String, accentColor: String = "c8a97e") -> Data? {
        // Create a simple text-based image as placeholder
        // In a real implementation, this would render a beautiful quote card
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1080))
        let image = renderer.image { ctx in
            // Background
            UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1080, height: 1080))

            // Quote text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 12

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .medium),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]

            let textRect = CGRect(x: 80, y: 400, width: 920, height: 400)
            text.draw(in: textRect, withAttributes: attrs)

            // Source
            let sourceAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .regular),
                .foregroundColor: UIColor(red: 0.55, green: 0.55, blue: 0.56, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]
            let sourceRect = CGRect(x: 80, y: 820, width: 920, height: 60)
            "— \(sourceTitle)".draw(in: sourceRect, withAttributes: sourceAttrs)
        }

        return image.pngData()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

import UIKit
