import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct CrispWidgetEntry: TimelineEntry {
    let date: Date
    let notes: [WidgetNote]
    let isEmpty: Bool
    // R11: Stats for large widget
    let totalRecordingsThisWeek: Int
    let totalDurationThisWeek: String
    let totalRecordings: Int
}

struct WidgetNote: Identifiable {
    let id: UUID
    let title: String
    let date: String
    let duration: String
}

// R11: Data structure for widget stats (shared with main app)
struct WidgetStatsData: Codable {
    let totalRecordingsThisWeek: Int
    let totalDurationThisWeekSeconds: Double
    let totalRecordings: Int
}

// MARK: - Timeline Provider

struct CrispWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CrispWidgetEntry {
        CrispWidgetEntry(
            date: Date(),
            notes: [
                WidgetNote(id: UUID(), title: "Meeting notes", date: "Today", duration: "2:34"),
                WidgetNote(id: UUID(), title: "Shopping list", date: "Yesterday", duration: "0:45"),
                WidgetNote(id: UUID(), title: "Ideas", date: "Mon", duration: "1:12")
            ],
            isEmpty: false,
            totalRecordingsThisWeek: 12,
            totalDurationThisWeek: "45:30",
            totalRecordings: 87
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CrispWidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CrispWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> CrispWidgetEntry {
        // Use shared app group container to read notes
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.crisp.app"
        ) else {
            return emptyEntry()
        }

        let dbPath = containerURL.appendingPathComponent("crisp.sqlite3")
        guard FileManager.default.fileExists(atPath: dbPath.path) else {
            return emptyEntry()
        }

        // Read last 3 notes using a lightweight JSON file written by the main app
        let notesFile = containerURL.appendingPathComponent("widget_notes.json")
        guard let data = try? Data(contentsOf: notesFile),
              let widgetNotes = try? JSONDecoder().decode([WidgetNoteData].self, from: data) else {
            return emptyEntry()
        }

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated

        let notes = widgetNotes.prefix(3).map { noteData -> WidgetNote in
            let date = noteData.createdAt
            let relative = relativeFormatter.localizedString(for: date, relativeTo: Date())
            return WidgetNote(
                id: noteData.id,
                title: noteData.title,
                date: relative,
                duration: formatDuration(noteData.duration)
            )
        }

        // R11: Read stats from shared file
        let statsFile = containerURL.appendingPathComponent("widget_stats.json")
        let (weekCount, weekDuration, totalCount) = loadStats(from: statsFile)

        return CrispWidgetEntry(
            date: Date(),
            notes: Array(notes),
            isEmpty: notes.isEmpty,
            totalRecordingsThisWeek: weekCount,
            totalDurationThisWeek: formatDuration(weekDuration),
            totalRecordings: totalCount
        )
    }

    private func emptyEntry() -> CrispWidgetEntry {
        CrispWidgetEntry(
            date: Date(),
            notes: [],
            isEmpty: true,
            totalRecordingsThisWeek: 0,
            totalDurationThisWeek: "0:00",
            totalRecordings: 0
        )
    }

    private func loadStats(from url: URL) -> (weekCount: Int, weekDuration: Double, totalCount: Int) {
        guard let data = try? Data(contentsOf: url),
              let stats = try? JSONDecoder().decode(WidgetStatsData.self, from: data) else {
            return (0, 0, 0)
        }
        return (stats.totalRecordingsThisWeek, stats.totalDurationThisWeekSeconds, stats.totalRecordings)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct WidgetNoteData: Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let duration: TimeInterval
}

// MARK: - Widget View

struct CrispWidgetEntryView: View {
    var entry: CrispWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: CrispWidgetEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "141416"), Color(hex: "0d0d0e")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "c8a97e"))

                    Spacer()

                    Image(systemName: "mic.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "c8a97e"))
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color(hex: "c8a97e").opacity(0.2))
                        )
                }

                Spacer()

                if let firstNote = entry.notes.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(firstNote.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            Text(firstNote.date)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "8b8b8e"))

                            Text("·")
                                .foregroundColor(Color(hex: "8b8b8e"))

                            Text(firstNote.duration)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "8b8b8e"))
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No recordings yet")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8b8b8e"))

                        Text("Tap to record")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8b8b8e"))
                    }
                }
            }
            .padding(14)
        }
        .widgetURL(URL(string: "crisp://record"))
    }
}

struct MediumWidgetView: View {
    let entry: CrispWidgetEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "141416"), Color(hex: "0d0d0e")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 0) {
                // Left column: Last recording info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "c8a97e"))

                        Text("Crisp")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    if let firstNote = entry.notes.first {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(firstNote.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                Text(firstNote.date)
                                Text("·")
                                Text(firstNote.duration)
                            }
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8b8b8e"))
                        }
                    } else {
                        Text("No recordings yet")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8b8b8e"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Right: Recent recordings list + quick record button
                VStack(alignment: .trailing, spacing: 8) {
                    // Recent recordings
                    if entry.notes.count > 1 {
                        VStack(alignment: .trailing, spacing: 4) {
                            ForEach(entry.notes.dropFirst().prefix(2)) { note in
                                HStack(spacing: 4) {
                                    Text(note.title)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "8b8b8e"))
                                        .lineLimit(1)

                                    Text("·")
                                        .foregroundColor(Color(hex: "8b8b8e"))

                                    Text(note.duration)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "8b8b8e"))
                                }
                            }
                        }
                    }

                    Spacer()

                    // Quick record button
                    ZStack {
                        Circle()
                            .fill(Color(hex: "c8a97e"))
                            .frame(width: 44, height: 44)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "0d0d0e"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
        }
        .widgetURL(URL(string: "crisp://record"))
    }
}

// R11: Large widget — shows recording stats
struct LargeWidgetView: View {
    let entry: CrispWidgetEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "141416"), Color(hex: "0d0d0e")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "c8a97e"))

                        Text("Crisp")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Your Week")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8b8b8e"))
                }

                // Stats row
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("\(entry.totalRecordingsThisWeek)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Recordings")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8b8b8e"))
                    }

                    Divider()
                        .frame(height: 40)
                        .background(Color(hex: "333333"))

                    VStack(spacing: 4) {
                        Text(entry.totalDurationThisWeek)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Total Time")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8b8b8e"))
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Text("\(entry.totalRecordings)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "c8a97e"))
                        Text("All Time")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8b8b8e"))
                    }
                }

                Divider()
                    .background(Color(hex: "2a2a2a"))

                // Recent recordings
                if entry.notes.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "333333"))
                            Text("No recordings yet")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "8b8b8e"))
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recent")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "8b8b8e"))

                        ForEach(entry.notes.prefix(3)) { note in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(note.date)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "8b8b8e"))
                                }
                                Spacer()
                                Text(note.duration)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "c8a97e"))
                            }
                        }
                    }

                    Spacer()
                }
            }
            .padding(16)
        }
        .widgetURL(URL(string: "crisp://record"))
    }
}

// MARK: - Widget Configuration

@main
struct CrispWidget: Widget {
    let kind: String = "CrispWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CrispWidgetProvider()) { entry in
            CrispWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Crisp")
        .description("Quick access to your latest recordings.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
