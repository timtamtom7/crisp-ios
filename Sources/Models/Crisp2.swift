import Foundation

// MARK: - Crisp R19: Crisp 2.0 — Meeting Intelligence Platform

/// AI Meeting Intelligence 2.0
struct MeetingIntelligence: Identifiable, Codable, Equatable {
    let id: UUID
    var meetingID: UUID
    var realtimeCoachingTips: [CoachingTip]
    var sentimentScore: Double
    var conflictFlags: [ConflictFlag]
    var predictedAgenda: [String]
    var roiScore: ROIScore
    var createdAt: Date
    
    struct CoachingTip: Identifiable, Codable, Equatable {
        let id: UUID
        var text: String
        var timestamp: TimeInterval
        var type: TipType
        var isRead: Bool
        
        enum TipType: String, Codable {
            case speakingTime = "Speaking Time"
            case actionReminder = "Action Reminder"
            case agendaReminder = "Agenda Reminder"
            case positive = "Positive"
        }
        
        init(id: UUID = UUID(), text: String, timestamp: TimeInterval, type: TipType, isRead: Bool = false) {
            self.id = id
            self.text = text
            self.timestamp = timestamp
            self.type = type
            self.isRead = isRead
        }
    }
    
    struct ConflictFlag: Identifiable, Codable, Equatable {
        let id: UUID
        var text: String
        var timestamp: TimeInterval
        var severity: Severity
        
        enum Severity: String, Codable {
            case low, medium, high
        }
        
        init(id: UUID = UUID(), text: String, timestamp: TimeInterval, severity: Severity) {
            self.id = id
            self.text = text
            self.timestamp = timestamp
            self.severity = severity
        }
    }
    
    struct ROIScore: Codable, Equatable {
        var actionItemsGenerated: Int
        var openQuestionsResolved: Int
        var score: Double
        
        init(actionItemsGenerated: Int = 0, openQuestionsResolved: Int = 0, score: Double = 0) {
            self.actionItemsGenerated = actionItemsGenerated
            self.openQuestionsResolved = openQuestionsResolved
            self.score = score
        }
    }
    
    init(id: UUID = UUID(), meetingID: UUID, realtimeCoachingTips: [CoachingTip] = [], sentimentScore: Double = 0, conflictFlags: [ConflictFlag] = [], predictedAgenda: [String] = [], roiScore: ROIScore = ROIScore(), createdAt: Date = Date()) {
        self.id = id
        self.meetingID = meetingID
        self.realtimeCoachingTips = realtimeCoachingTips
        self.sentimentScore = sentimentScore
        self.conflictFlags = conflictFlags
        self.predictedAgenda = predictedAgenda
        self.roiScore = roiScore
        self.createdAt = createdAt
    }
}

/// Collaborative meeting workspace
struct CollaborativeWorkspace: Identifiable, Codable, Equatable {
    let id: UUID
    var meetingID: UUID
    var participants: [Participant]
    var comments: [WorkspaceComment]
    var sharedActionItems: [SharedActionItem]
    
    struct Participant: Identifiable, Codable, Equatable {
        let id: UUID
        var userID: String
        var displayName: String
        var role: Role
        
        enum Role: String, Codable {
            case editor, viewer, commenter
        }
        
        init(id: UUID = UUID(), userID: String, displayName: String, role: Role = .editor) {
            self.id = id
            self.userID = userID
            self.displayName = displayName
            self.role = role
        }
    }
    
    struct WorkspaceComment: Identifiable, Codable, Equatable {
        let id: UUID
        var userID: String
        var text: String
        var timestamp: TimeInterval
        var createdAt: Date
        
        init(id: UUID = UUID(), userID: String, text: String, timestamp: TimeInterval = 0, createdAt: Date = Date()) {
            self.id = id
            self.userID = userID
            self.text = text
            self.timestamp = timestamp
            self.createdAt = createdAt
        }
    }
    
    struct SharedActionItem: Identifiable, Codable, Equatable {
        let id: UUID
        var text: String
        var assigneeID: String?
        var dueDate: Date?
        var isCompleted: Bool
        var sourceMeetingID: UUID
        
        init(id: UUID = UUID(), text: String, assigneeID: String? = nil, dueDate: Date? = nil, isCompleted: Bool = false, sourceMeetingID: UUID) {
            self.id = id
            self.text = text
            self.assigneeID = assigneeID
            self.dueDate = dueDate
            self.isCompleted = isCompleted
            self.sourceMeetingID = sourceMeetingID
        }
    }
    
    init(id: UUID = UUID(), meetingID: UUID, participants: [Participant] = [], comments: [WorkspaceComment] = [], sharedActionItems: [SharedActionItem] = []) {
        self.id = id
        self.meetingID = meetingID
        self.participants = participants
        self.comments = comments
        self.sharedActionItems = sharedActionItems
    }
}

/// Recurring meeting thread
struct RecurringMeetingThread: Identifiable, Codable, Equatable {
    let id: UUID
    var threadName: String
    var meetingIDs: [UUID]
    var participantIDs: [String]
    var createdAt: Date
    
    init(id: UUID = UUID(), threadName: String, meetingIDs: [UUID] = [], participantIDs: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.threadName = threadName
        self.meetingIDs = meetingIDs
        self.participantIDs = participantIDs
        self.createdAt = createdAt
    }
    
    var meetingCount: Int { meetingIDs.count }
}

/// Enterprise features
struct EnterpriseFeatures: Codable, Equatable {
    var ssoProvider: SSOProvider?
    var scimEnabled: Bool
    var auditLogsEnabled: Bool
    var dataResidency: DataResidency?
    var customBranding: CustomBranding?
    
    enum SSOProvider: String, Codable {
        case googleWorkspace = "Google Workspace"
        case microsoftEntra = "Microsoft Entra ID"
        case okta = "Okta"
        case onelogin = "OneLogin"
    }
    
    enum DataResidency: String, Codable {
        case us = "United States"
        case eu = "European Union"
        case apac = "Asia Pacific"
    }
    
    struct CustomBranding: Codable, Equatable {
        var logoURL: String?
        var primaryColor: String
        var customDomain: String?
    }
    
    init(ssoProvider: SSOProvider? = nil, scimEnabled: Bool = false, auditLogsEnabled: Bool = false, dataResidency: DataResidency? = nil, customBranding: CustomBranding? = nil) {
        self.ssoProvider = ssoProvider
        self.scimEnabled = scimEnabled
        self.auditLogsEnabled = auditLogsEnabled
        self.dataResidency = dataResidency
        self.customBranding = customBranding
    }
}

// MARK: - Crisp R20: Platform Ecosystem, Awards, Long-Term Vision

/// Platform ecosystem integration
struct PlatformIntegration: Identifiable, Codable, Equatable {
    let id: UUID
    var platform: Platform
    var integrationType: IntegrationType
    var isEnabled: Bool
    var config: [String: String]
    
    enum Platform: String, Codable {
        case zoom = "Zoom"
        case microsoftTeams = "Microsoft Teams"
        case googleMeet = "Google Meet"
        case embeddedSDK = "Embedded SDK"
    }
    
    enum IntegrationType: String, Codable {
        case nativeApp = "Native App"
        case sidePanel = "Side Panel"
        case sdk = "SDK"
        case chromeExtension = "Chrome Extension"
    }
    
    init(id: UUID = UUID(), platform: Platform, integrationType: IntegrationType, isEnabled: Bool = false, config: [String: String] = [:]) {
        self.id = id
        self.platform = platform
        self.integrationType = integrationType
        self.isEnabled = isEnabled
        self.config = config
    }
}

/// Embedded SDK configuration
struct EmbeddedSDKConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var hostAppName: String
    var hostBundleID: String
    var licenseKey: String
    var licenseType: LicenseType
    var isActive: Bool
    
    enum LicenseType: String, Codable {
        case startup = "Startup"
        case commercial = "Commercial"
    }
    
    init(id: UUID = UUID(), hostAppName: String, hostBundleID: String, licenseKey: String = UUID().uuidString, licenseType: LicenseType = .startup, isActive: Bool = true) {
        self.id = id
        self.hostAppName = hostAppName
        self.hostBundleID = hostBundleID
        self.licenseKey = licenseKey
        self.licenseType = licenseType
        self.isActive = isActive
    }
}

/// Partner program
struct PartnerProgram: Codable, Equatable {
    var isEnrolled: Bool
    var revenueShare: Double
    var totalReferrals: Int
    var totalEarnings: Decimal
    var payoutHistory: [Payout]
    
    struct Payout: Identifiable, Codable, Equatable {
        let id: UUID
        var amount: Decimal
        var paidAt: Date
        var status: Status
        
        enum Status: String, Codable {
            case pending, paid, failed
        }
        
        init(id: UUID = UUID(), amount: Decimal, paidAt: Date, status: Status) {
            self.id = id
            self.amount = amount
            self.paidAt = paidAt
            self.status = status
        }
    }
    
    init(isEnrolled: Bool = false, revenueShare: Double = 0.30, totalReferrals: Int = 0, totalEarnings: Decimal = 0, payoutHistory: [Payout] = []) {
        self.isEnrolled = isEnrolled
        self.revenueShare = revenueShare
        self.totalReferrals = totalReferrals
        self.totalEarnings = totalEarnings
        self.payoutHistory = payoutHistory
    }
}

/// Award submission
struct AwardSubmission: Identifiable, Codable, Equatable {
    let id: UUID
    var awardName: String
    var category: String
    var submittedAt: Date
    var status: Status
    var applicationURL: String?
    
    enum Status: String, Codable {
        case draft, submitted, inReview, won, rejected
    }
    
    init(id: UUID = UUID(), awardName: String, category: String, submittedAt: Date = Date(), status: Status = .draft, applicationURL: String? = nil) {
        self.id = id
        self.awardName = awardName
        self.category = category
        self.submittedAt = submittedAt
        self.status = status
        self.applicationURL = applicationURL
    }
    
    static let appleDesignAwards = AwardSubmission(id: UUID(), awardName: "Apple Design Awards", category: "Innovation & Tech")
    static let forbesAI50 = AwardSubmission(id: UUID(), awardName: "Forbes AI 50", category: "AI-Powered Productivity")
}
