import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct CrispWidgetEntry: TimelineEntry {
    let date: Date
    let lastNoteTitle: String?
    let lastNoteDate: String?
    let lastNoteDuration: String?
}

// MARK: - Timeline Provider

struct CrispWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CrispWidgetEntry {
        CrispWidgetEntry(
            date: Date(),
            lastNoteTitle: "Meeting notes",
            lastNoteDate: "Today",
            lastNoteDuration: "2:34"
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
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsPath.appendingPathComponent("crisp.sqlite3")

        guard FileManager.default.fileExists(atPath: dbPath.path) else {
            return CrispWidgetEntry(date: Date(), lastNoteTitle: nil, lastNoteDate: nil, lastNoteDuration: nil)
        }

        // Simple note loading without SQLite (to avoid linking complexity)
        // In production, use App Groups shared container
        return CrispWidgetEntry(date: Date(), lastNoteTitle: nil, lastNoteDate: nil, lastNoteDuration: nil)
    }
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
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: CrispWidgetEntry

    var body: some View {
        ZStack {
            // Background
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

                if let title = entry.lastNoteTitle {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let date = entry.lastNoteDate {
                        Text(date)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8b8b8e"))
                    }
                } else {
                    Text("No recordings yet")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8b8b8e"))

                    Text("Tap to record")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8b8b8e"))
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

            HStack(spacing: 16) {
                // Left: Last recording info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "c8a97e"))

                        Text("Crisp")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    if let title = entry.lastNoteTitle {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            if let date = entry.lastNoteDate {
                                Text(date)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "8b8b8e"))
                            }

                            if let duration = entry.lastNoteDuration {
                                Text("·")
                                    .foregroundColor(Color(hex: "8b8b8e"))
                                Text(duration)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "8b8b8e"))
                            }
                        }
                    } else {
                        Text("No recordings yet")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "8b8b8e"))

                        Text("Tap to capture your first note")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8b8b8e"))
                    }
                }

                Spacer()

                // Right: Quick record button
                VStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "c8a97e"))
                            .frame(width: 52, height: 52)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "0d0d0e"))
                    }
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
        .description("Quick access to your latest recording.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Color Extension for Widget

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
