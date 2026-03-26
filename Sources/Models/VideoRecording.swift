import Foundation

// MARK: - Crisp R12: Video Recording, Gallery, Premium Playback, Clip Sharing

/// Video recording configuration for meetings
struct VideoRecording: Identifiable, Codable, Equatable {
    let id: UUID
    var meetingID: UUID
    var videoFileURL: URL?
    var videoType: VideoType
    var duration: TimeInterval
    var createdAt: Date
    var thumbnailFilename: String?
    var fileSizeBytes: Int64
    
    enum VideoType: String, Codable {
        case frontCamera = "Front Camera"
        case screenRecording = "Screen Recording"
        case pictureInPicture = "PiP"
        case both = "Both"
    }
    
    init(id: UUID = UUID(), meetingID: UUID, videoFileURL: URL? = nil, videoType: VideoType = .frontCamera, duration: TimeInterval = 0, createdAt: Date = Date(), thumbnailFilename: String? = nil, fileSizeBytes: Int64 = 0) {
        self.id = id
        self.meetingID = meetingID
        self.videoFileURL = videoFileURL
        self.videoType = videoType
        self.duration = duration
        self.createdAt = createdAt
        self.thumbnailFilename = thumbnailFilename
        self.fileSizeBytes = fileSizeBytes
    }
}

/// Meeting card for gallery view
struct MeetingCard: Identifiable, Codable, Equatable {
    let id: UUID
    var meetingNoteID: UUID
    var title: String
    var date: Date
    var participantAvatars: [String]
    var duration: TimeInterval
    var hasActionItems: Bool
    var isUnresolved: Bool
    var thumbnailFilename: String?
    var meetingType: String
    
    init(id: UUID = UUID(), meetingNoteID: UUID, title: String, date: Date, participantAvatars: [String] = [], duration: TimeInterval = 0, hasActionItems: Bool = false, isUnresolved: Bool = false, thumbnailFilename: String? = nil, meetingType: String = "General") {
        self.id = id
        self.meetingNoteID = meetingNoteID
        self.title = title
        self.date = date
        self.participantAvatars = participantAvatars
        self.duration = duration
        self.hasActionItems = hasActionItems
        self.isUnresolved = isUnresolved
        self.thumbnailFilename = thumbnailFilename
        self.meetingType = meetingType
    }
}

/// Chapter marker for playback
struct ChapterMarker: Identifiable, Codable, Equatable {
    let id: UUID
    var meetingID: UUID
    var title: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var transcriptSegment: String
    
    init(id: UUID = UUID(), meetingID: UUID, title: String, startTime: TimeInterval, endTime: TimeInterval, transcriptSegment: String = "") {
        self.id = id
        self.meetingID = meetingID
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.transcriptSegment = transcriptSegment
    }
}

/// Clip extraction from meeting
struct ClipExtraction: Identifiable, Codable, Equatable {
    let id: UUID
    var meetingID: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var exportedURL: URL?
    var transcriptSelection: String
    var hasWatermark: Bool
    var createdAt: Date
    var shareLink: String?
    
    init(id: UUID = UUID(), meetingID: UUID, startTime: TimeInterval, endTime: TimeInterval, exportedURL: URL? = nil, transcriptSelection: String = "", hasWatermark: Bool = true, createdAt: Date = Date(), shareLink: String? = nil) {
        self.id = id
        self.meetingID = meetingID
        self.startTime = startTime
        self.endTime = endTime
        self.exportedURL = exportedURL
        self.transcriptSelection = transcriptSelection
        self.hasWatermark = hasWatermark
        self.createdAt = createdAt
        self.shareLink = shareLink
    }
    
    var duration: TimeInterval { endTime - startTime }
}

/// Clip analytics
struct ClipAnalytics: Identifiable, Codable, Equatable {
    let id: UUID
    var clipExtractionID: UUID
    var viewCount: Int
    var uniqueViewers: [String]
    var viewsByDate: [Date: Int]
    var lastViewedAt: Date?
    
    init(id: UUID = UUID(), clipExtractionID: UUID, viewCount: Int = 0, uniqueViewers: [String] = [], viewsByDate: [Date: Int] = [:], lastViewedAt: Date? = nil) {
        self.id = id
        self.clipExtractionID = clipExtractionID
        self.viewCount = viewCount
        self.uniqueViewers = uniqueViewers
        self.viewsByDate = viewsByDate
        self.lastViewedAt = lastViewedAt
    }
    
    mutating func recordView(from viewerID: String) {
        if !uniqueViewers.contains(viewerID) {
            uniqueViewers.append(viewerID)
        }
        viewCount += 1
        lastViewedAt = Date()
        let today = Calendar.current.startOfDay(for: Date())
        viewsByDate[today, default: 0] += 1
    }
}
