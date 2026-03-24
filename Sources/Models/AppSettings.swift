import Foundation

struct AppSettings: Codable {
    var speechLanguage: String
    var autoSaveOnStop: Bool

    static let defaults = AppSettings(
        speechLanguage: "en-US",
        autoSaveOnStop: true
    )
}
