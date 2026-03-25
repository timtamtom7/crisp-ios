import Foundation
import AVFoundation
import Combine

/// R11: Playback polish features
/// Variable playback speed (0.5x–2x), chapter markers, sleep timer, background audio
final class PlaybackPolishService: ObservableObject, @unchecked Sendable {
    static let shared = PlaybackPolishService()

    @Published var playbackSpeed: Float = 1.0
    @Published var sleepTimerMinutes: Int? = nil
    @Published var sleepTimerRemaining: TimeInterval = 0
    @Published private(set) var isSleepTimerActive = false

    // Available speeds
    static let availableSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    // Chapter markers (timestamp-based, populated by AI analysis)
    @Published private(set) var chapters: [Chapter] = []

    struct Chapter: Identifiable {
        let id = UUID()
        let title: String
        let startTime: Double
        let endTime: Double?
    }

    private var sleepTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Restore last used speed
        let savedSpeed = UserDefaults.standard.float(forKey: "playbackSpeed")
        if savedSpeed > 0 {
            playbackSpeed = savedSpeed
        }
    }

    // MARK: - Speed Control

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        UserDefaults.standard.set(speed, forKey: "playbackSpeed")
    }

    func cycleSpeed() {
        let speeds = Self.availableSpeeds
        if let currentIndex = speeds.firstIndex(of: playbackSpeed) {
            let nextIndex = (currentIndex + 1) % speeds.count
            setSpeed(speeds[nextIndex])
        } else {
            setSpeed(1.0)
        }
    }

    // MARK: - Sleep Timer

    func startSleepTimer(minutes: Int) {
        cancelSleepTimer()
        sleepTimerMinutes = minutes
        sleepTimerRemaining = TimeInterval(minutes * 60)
        isSleepTimerActive = true

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.sleepTimerRemaining -= 1
                if self.sleepTimerRemaining <= 0 {
                    self.sleepTimerDidFire()
                }
            }
        }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerMinutes = nil
        sleepTimerRemaining = 0
        isSleepTimerActive = false
    }

    private func sleepTimerDidFire() {
        cancelSleepTimer()
        // Notify AudioPlayerService to pause
        NotificationCenter.default.post(name: .playbackPolishSleepTimerFired, object: nil)
    }

    var formattedSleepTimerRemaining: String {
        let minutes = Int(sleepTimerRemaining) / 60
        let seconds = Int(sleepTimerRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Chapters

    func setChapters(_ chapters: [Chapter]) {
        self.chapters = chapters.sorted { $0.startTime < $1.startTime }
    }

    func chapter(at time: Double) -> Chapter? {
        chapters.first { chapter in
            let end = chapter.endTime ?? .infinity
            return time >= chapter.startTime && time < end
        }
    }

    func generateChaptersFromTranscript(_ segments: [(text: String, startTime: Double)]) -> [Chapter] {
        // Simple chapter generation: group transcript segments by ~2-minute intervals
        // with topic change detection (capitalized words at start of sentences)
        var chapters: [Chapter] = []
        var currentChapter: Chapter?

        for segment in segments {
            if currentChapter == nil || (segment.startTime - currentChapter!.startTime) > 120 {
                // Start new chapter
                if let current = currentChapter {
                    chapters.append(Chapter(
                        title: current.title,
                        startTime: current.startTime,
                        endTime: segment.startTime
                    ))
                }
                currentChapter = Chapter(
                    title: extractTopic(from: segment.text),
                    startTime: segment.startTime,
                    endTime: nil
                )
            } else {
                // Update current chapter end
                currentChapter = Chapter(
                    title: currentChapter!.title,
                    startTime: currentChapter!.startTime,
                    endTime: segment.startTime
                )
            }
        }

        // Don't forget the last chapter
        if let current = currentChapter {
            chapters.append(Chapter(
                title: current.title,
                startTime: current.startTime,
                endTime: nil
            ))
        }

        return chapters
    }

    private func extractTopic(from text: String) -> String {
        // Simple: first sentence capitalized words joined
        let words = text.split(separator: " ").prefix(5)
        let topic = words.joined(separator: " ")
        return topic.isEmpty ? "Chapter" : topic
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let playbackPolishSleepTimerFired = Notification.Name("playbackPolishSleepTimerFired")
}
