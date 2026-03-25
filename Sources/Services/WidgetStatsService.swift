import Foundation

/// R11: Widget Stats Service — writes widget data to shared app group container
final class WidgetStatsService: @unchecked Sendable {
    static let shared = WidgetStatsService()

    private let containerIdentifier = "group.com.crisp.app"

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: containerIdentifier)
    }

    private init() {}

    /// Update widget notes file (called whenever notes change)
    func updateWidgetNotes(notes: [WidgetNoteEntry]) {
        guard let container = containerURL else { return }

        let notesFile = container.appendingPathComponent("widget_notes.json")
        let data = notes.map { WidgetNoteEntryData(from: $0) }

        do {
            let jsonData = try JSONEncoder().encode(data)
            try jsonData.write(to: notesFile)
        } catch {
            print("Failed to write widget notes: \(error)")
        }
    }

    /// Update widget stats file (called weekly or on significant changes)
    func updateWidgetStats(weekCount: Int, weekDurationSeconds: Double, totalCount: Int) {
        guard let container = containerURL else { return }

        let statsFile = container.appendingPathComponent("widget_stats.json")
        let stats = WidgetStatsLocalData(
            totalRecordingsThisWeek: weekCount,
            totalDurationThisWeekSeconds: weekDurationSeconds,
            totalRecordings: totalCount
        )

        do {
            let jsonData = try JSONEncoder().encode(stats)
            try jsonData.write(to: statsFile)
        } catch {
            print("Failed to write widget stats: \(error)")
        }
    }
}

/// Local copy of WidgetStatsData (widget extension defines its own version)
struct WidgetStatsLocalData: Codable {
    let totalRecordingsThisWeek: Int
    let totalDurationThisWeekSeconds: Double
    let totalRecordings: Int
}

// Lightweight structs for JSON serialization
struct WidgetNoteEntryData: Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let duration: TimeInterval

    init(from entry: WidgetNoteEntry) {
        self.id = entry.id
        self.title = entry.title
        self.createdAt = entry.createdAt
        self.duration = entry.duration
    }
}

struct WidgetNoteEntry {
    let id: UUID
    let title: String
    let createdAt: Date
    let duration: TimeInterval
}
