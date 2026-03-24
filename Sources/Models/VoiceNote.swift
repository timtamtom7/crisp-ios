import Foundation

struct VoiceNote: Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    var transcription: String
    let audioFileURL: URL
    let duration: TimeInterval
    let createdAt: Date
    var folderId: UUID?
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String,
        transcription: String,
        audioFileURL: URL,
        duration: TimeInterval,
        createdAt: Date = Date(),
        folderId: UUID? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.transcription = transcription
        self.audioFileURL = audioFileURL
        self.duration = duration
        self.createdAt = createdAt
        self.folderId = folderId
        self.isFavorite = isFavorite
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
