import SwiftUI
import Combine

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
    }

    func saveSettings() {
        settingsService.save(settings)
    }

    enum Tab: Int {
        case capture
        case library
    }
}
