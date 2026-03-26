import Foundation

struct VoiceNote: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var title: String
    var transcription: String
    let audioFileURL: URL
    let duration: TimeInterval
    let createdAt: Date
    var folderId: UUID?
    var isFavorite: Bool

    // AI features
    var aiSummary: String?
    var aiKeywords: [String]
    var actionItems: [String]
    var topic: String?
    var sentiment: Double?
    var detectedEntities: [String]
    var speakingPace: Double?
    var folderSuggestion: String?

    var hasAISummary: Bool { aiSummary != nil && !(aiSummary?.isEmpty ?? true) }

    /// Returns the AI summary if non-nil and non-empty, otherwise an empty string.
    var nonEmptySummary: String {
        guard let summary = aiSummary, !summary.isEmpty else { return "" }
        return summary
    }

    init(
        id: UUID = UUID(),
        title: String,
        transcription: String,
        audioFileURL: URL,
        duration: TimeInterval,
        createdAt: Date = Date(),
        folderId: UUID? = nil,
        isFavorite: Bool = false,
        aiSummary: String? = nil,
        aiKeywords: [String] = [],
        actionItems: [String] = [],
        topic: String? = nil,
        sentiment: Double? = nil,
        detectedEntities: [String] = [],
        speakingPace: Double? = nil,
        folderSuggestion: String? = nil
    ) {
        self.id = id
        self.title = title
        self.transcription = transcription
        self.audioFileURL = audioFileURL
        self.duration = duration
        self.createdAt = createdAt
        self.folderId = folderId
        self.isFavorite = isFavorite
        self.aiSummary = aiSummary
        self.aiKeywords = aiKeywords
        self.actionItems = actionItems
        self.topic = topic
        self.sentiment = sentiment
        self.detectedEntities = detectedEntities
        self.speakingPace = speakingPace
        self.folderSuggestion = folderSuggestion
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

    // Codable conformance for audioFileURL (encode/decode just the filename)
    enum CodingKeys: String, CodingKey {
        case id, title, transcription, audioFileName, duration, createdAt, folderId, isFavorite
        case aiSummary, aiKeywords, actionItems, topic, sentiment, detectedEntities, speakingPace, folderSuggestion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        transcription = try container.decode(String.self, forKey: .transcription)
        let audioFileName = try container.decode(String.self, forKey: .audioFileName)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        audioFileURL = documentsPath.appendingPathComponent(audioFileName)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        folderId = try container.decodeIfPresent(UUID.self, forKey: .folderId)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        aiSummary = try container.decodeIfPresent(String.self, forKey: .aiSummary)
        aiKeywords = try container.decodeIfPresent([String].self, forKey: .aiKeywords) ?? []
        actionItems = try container.decodeIfPresent([String].self, forKey: .actionItems) ?? []
        topic = try container.decodeIfPresent(String.self, forKey: .topic)
        sentiment = try container.decodeIfPresent(Double.self, forKey: .sentiment)
        detectedEntities = try container.decodeIfPresent([String].self, forKey: .detectedEntities) ?? []
        speakingPace = try container.decodeIfPresent(Double.self, forKey: .speakingPace)
        folderSuggestion = try container.decodeIfPresent(String.self, forKey: .folderSuggestion)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(transcription, forKey: .transcription)
        try container.encode(audioFileURL.lastPathComponent, forKey: .audioFileName)
        try container.encode(duration, forKey: .duration)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(folderId, forKey: .folderId)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(aiSummary, forKey: .aiSummary)
        try container.encode(aiKeywords, forKey: .aiKeywords)
        try container.encode(actionItems, forKey: .actionItems)
        try container.encodeIfPresent(topic, forKey: .topic)
        try container.encodeIfPresent(sentiment, forKey: .sentiment)
        try container.encode(detectedEntities, forKey: .detectedEntities)
        try container.encodeIfPresent(speakingPace, forKey: .speakingPace)
        try container.encodeIfPresent(folderSuggestion, forKey: .folderSuggestion)
    }
}
