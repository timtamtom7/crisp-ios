import Foundation

// MARK: - Crisp R13: Team Workspaces, Organization Management, Admin Controls

/// Organization / Team Workspace
struct Organization: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var members: [OrganizationMember]
    var settings: OrgSettings
    var createdAt: Date
    var billingEmail: String
    
    struct OrganizationMember: Identifiable, Codable, Equatable {
        let id: UUID
        var userID: String
        var displayName: String
        var email: String
        var role: Role
        var joinedAt: Date
        var isActive: Bool
        
        enum Role: String, Codable {
            case admin
            case member
            case guest
        }
        
        init(id: UUID = UUID(), userID: String, displayName: String, email: String, role: Role = .member, joinedAt: Date = Date(), isActive: Bool = true) {
            self.id = id
            self.userID = userID
            self.displayName = displayName
            self.email = email
            self.role = role
            self.joinedAt = joinedAt
            self.isActive = isActive
        }
    }
    
    struct OrgSettings: Codable, Equatable {
        var complianceLoggingEnabled: Bool
        var dataRetentionDays: Int
        var ssoEnabled: Bool
        var ssoProvider: String? // "google" or "microsoft"
        var defaultRole: OrganizationMember.Role
        
        init(complianceLoggingEnabled: Bool = false, dataRetentionDays: Int = 730, ssoEnabled: Bool = false, ssoProvider: String? = nil, defaultRole: OrganizationMember.Role = .member) {
            self.complianceLoggingEnabled = complianceLoggingEnabled
            self.dataRetentionDays = dataRetentionDays
            self.ssoEnabled = ssoEnabled
            self.ssoProvider = ssoProvider
            self.defaultRole = defaultRole
        }
    }
    
    init(id: UUID = UUID(), name: String, members: [OrganizationMember] = [], settings: OrgSettings = OrgSettings(), createdAt: Date = Date(), billingEmail: String = "") {
        self.id = id
        self.name = name
        self.members = members
        self.settings = settings
        self.createdAt = createdAt
        self.billingEmail = billingEmail
    }
    
    mutating func addMember(_ member: OrganizationMember) {
        guard !members.contains(where: { $0.userID == member.userID }) else { return }
        members.append(member)
    }
    
    mutating func removeMember(_ userID: String) {
        members.removeAll { $0.userID == userID }
    }
    
    mutating func updateMemberRole(_ userID: String, to role: OrganizationMember.Role) {
        if let index = members.firstIndex(where: { $0.userID == userID }) {
            members[index].role = role
        }
    }
}

/// Invite to organization
struct OrgInvite: Identifiable, Codable, Equatable {
    let id: UUID
    var organizationID: UUID
    var email: String
    var role: Organization.OrganizationMember.Role
    var inviteLink: String
    var expiresAt: Date
    var isUsed: Bool
    
    init(id: UUID = UUID(), organizationID: UUID, email: String, role: Organization.OrganizationMember.Role = .member, inviteLink: String = "", expiresAt: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(), isUsed: Bool = false) {
        self.id = id
        self.organizationID = organizationID
        self.email = email
        self.role = role
        self.inviteLink = inviteLink.isEmpty ? "https://crisp.ai/invite/\(id.uuidString)" : inviteLink
        self.expiresAt = expiresAt
        self.isUsed = isUsed
    }
    
    var isExpired: Bool { Date() > expiresAt }
}

/// Team analytics
struct TeamAnalytics: Codable, Equatable {
    var meetingsPerWeek: Int
    var meetingsPerTeam: [String: Int]
    var meetingsPerPerson: [String: Int]
    var actionItemsCompleted: Int
    var actionItemsOverdue: Int
    var meetingFrequencyByPerson: [String: Double]
    var talkingTimeByPerson: [String: TimeInterval]
    var weeklyLeaderboard: [LeaderboardEntry]
    
    struct LeaderboardEntry: Identifiable, Codable, Equatable {
        let id: UUID
        var personID: String
        var displayName: String
        var actionItemsClosed: Int
        var rank: Int
        
        init(id: UUID = UUID(), personID: String, displayName: String, actionItemsClosed: Int, rank: Int) {
            self.id = id
            self.personID = personID
            self.displayName = displayName
            self.actionItemsClosed = actionItemsClosed
            self.rank = rank
        }
    }
    
    init(meetingsPerWeek: Int = 0, meetingsPerTeam: [String: Int] = [:], meetingsPerPerson: [String: Int] = [:], actionItemsCompleted: Int = 0, actionItemsOverdue: Int = 0, meetingFrequencyByPerson: [String: Double] = [:], talkingTimeByPerson: [String: TimeInterval] = [:], weeklyLeaderboard: [LeaderboardEntry] = []) {
        self.meetingsPerWeek = meetingsPerWeek
        self.meetingsPerTeam = meetingsPerTeam
        self.meetingsPerPerson = meetingsPerPerson
        self.actionItemsCompleted = actionItemsCompleted
        self.actionItemsOverdue = actionItemsOverdue
        self.meetingFrequencyByPerson = meetingFrequencyByPerson
        self.talkingTimeByPerson = talkingTimeByPerson
        self.weeklyLeaderboard = weeklyLeaderboard
    }
}

/// Education-specific: Lecture capture
struct LectureCapture: Identifiable, Codable, Equatable {
    let id: UUID
    var professorID: String
    var title: String
    var courseName: String
    var recordingURL: URL?
    var transcript: String
    var studentAnnotations: [StudentAnnotation]
    var createdAt: Date
    
    struct StudentAnnotation: Identifiable, Codable, Equatable {
        let id: UUID
        var studentID: String
        var timestamp: TimeInterval
        var text: String
        var createdAt: Date
        
        init(id: UUID = UUID(), studentID: String, timestamp: TimeInterval, text: String, createdAt: Date = Date()) {
            self.id = id
            self.studentID = studentID
            self.timestamp = timestamp
            self.text = text
            self.createdAt = createdAt
        }
    }
    
    init(id: UUID = UUID(), professorID: String, title: String, courseName: String, recordingURL: URL? = nil, transcript: String = "", studentAnnotations: [StudentAnnotation] = [], createdAt: Date = Date()) {
        self.id = id
        self.professorID = professorID
        self.title = title
        self.courseName = courseName
        self.recordingURL = recordingURL
        self.transcript = transcript
        self.studentAnnotations = studentAnnotations
        self.createdAt = createdAt
    }
}

/// Study group
struct StudyGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var memberIDs: [String]
    var sharedNoteIDs: [UUID]
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, memberIDs: [String] = [], sharedNoteIDs: [UUID] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.memberIDs = memberIDs
        self.sharedNoteIDs = sharedNoteIDs
        self.createdAt = createdAt
    }
}
