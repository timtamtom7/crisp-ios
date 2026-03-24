import Foundation

struct AppSettings: Codable {
    var speechLanguage: String
    var autoSaveOnStop: Bool
    var iCloudSyncEnabled: Bool
    var syncAutomatically: Bool

    static let defaults = AppSettings(
        speechLanguage: "en-US",
        autoSaveOnStop: true,
        iCloudSyncEnabled: false,
        syncAutomatically: true
    )
}
