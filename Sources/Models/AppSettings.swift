import AVFoundation

/// Recording quality preset.
enum RecordingQuality: String, Codable, CaseIterable {
    /// Smaller file size, good quality for voice notes.
    case standard = "standard"
    /// Highest quality, larger file size.
    case high = "high"

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .high: return "High"
        }
    }

    var description: String {
        switch self {
        case .standard: return "Good quality, smaller files"
        case .high: return "Best quality, larger files"
        }
    }

    /// AVAudioQuality value for recording settings.
    var audioQuality: AVAudioQuality {
        switch self {
        case .standard: return .medium
        case .high: return .high
        }
    }

    /// Estimated bitrate for display purposes.
    var bitrate: String {
        switch self {
        case .standard: return "64 kbps"
        case .high: return "128 kbps"
        }
    }
}

struct AppSettings: Codable {
    var speechLanguage: String
    var autoSaveOnStop: Bool
    var iCloudSyncEnabled: Bool
    var syncAutomatically: Bool
    var recordingQuality: RecordingQuality

    static let defaults = AppSettings(
        speechLanguage: "en-US",
        autoSaveOnStop: true,
        iCloudSyncEnabled: false,
        syncAutomatically: true,
        recordingQuality: .high
    )
}
