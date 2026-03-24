import SwiftUI
import Combine
import WidgetKit

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .capture
    @Published var settings: AppSettings

    private let settingsService: SettingsService

    var isOnboardingCompleted: Bool {
        UserDefaults.standard.bool(forKey: "onboarding_completed_v1")
    }

    init() {
        let settingsService = SettingsService()
        self.settingsService = settingsService
        self.settings = settingsService.load()
        setupWidgetNotesSync()
        setupiCloudSync()
    }

    func saveSettings() {
        settingsService.save(settings)
        // Sync settings to iCloud
        if settings.iCloudSyncEnabled {
            iCloudSyncService.shared.saveSettingsToCloud(settings)
        }
    }

    /// Writes last 3 notes to shared widget container for widget access.
    func refreshWidgetNotes() {
        Task {
            do {
                let notes = try DatabaseService.shared.fetchAllNotes()
                let widgetNotes = notes.prefix(3).map { note in
                    WidgetNoteData(
                        id: note.id,
                        title: note.title,
                        createdAt: note.createdAt,
                        duration: note.duration
                    )
                }

                guard let containerURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: "group.com.crisp.app"
                ) else { return }

                let notesFile = containerURL.appendingPathComponent("widget_notes.json")
                let data = try JSONEncoder().encode(Array(widgetNotes))
                try data.write(to: notesFile)

                // Trigger widget reload
                WidgetCenter.shared.reloadTimelines(ofKind: "CrispWidget")
            } catch {
                print("Widget notes sync error: \(error)")
            }
        }
    }

    private func setupWidgetNotesSync() {
        // Initial widget notes write
        refreshWidgetNotes()
    }

    private func setupiCloudSync() {
        guard settings.iCloudSyncEnabled else { return }
        Task {
            await iCloudSyncService.shared.sync()
        }
    }

    enum Tab: Int {
        case capture
        case library
    }
}

struct WidgetNoteData: Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let duration: TimeInterval
}
