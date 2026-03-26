import Foundation

// MARK: - Crisp R14: Integrations, API, Workflow Automation

/// Calendar integration
struct CalendarIntegration: Identifiable, Codable, Equatable {
    let id: UUID
    var provider: CalendarProvider
    var isEnabled: Bool
    var lastSyncAt: Date?
    var twoWaySyncEnabled: Bool
    
    enum CalendarProvider: String, Codable {
        case googleCalendar = "Google Calendar"
        case microsoftOutlook = "Microsoft Outlook"
        case fantastical = "Fantastical"
    }
    
    init(id: UUID = UUID(), provider: CalendarProvider, isEnabled: Bool = false, lastSyncAt: Date? = nil, twoWaySyncEnabled: Bool = true) {
        self.id = id
        self.provider = provider
        self.isEnabled = isEnabled
        self.lastSyncAt = lastSyncAt
        self.twoWaySyncEnabled = twoWaySyncEnabled
    }
}

/// Video conferencing integration
struct VideoConferenceIntegration: Identifiable, Codable, Equatable {
    let id: UUID
    var platform: VideoPlatform
    var isEnabled: Bool
    var autoRecordEnabled: Bool
    
    enum VideoPlatform: String, Codable {
        case zoom = "Zoom"
        case googleMeet = "Google Meet"
        case microsoftTeams = "Microsoft Teams"
        case ringCentral = "RingCentral"
        case loom = "Loom"
    }
    
    init(id: UUID = UUID(), platform: VideoPlatform, isEnabled: Bool = false, autoRecordEnabled: Bool = false) {
        self.id = id
        self.platform = platform
        self.isEnabled = isEnabled
        self.autoRecordEnabled = autoRecordEnabled
    }
}

/// CRM integration
struct CRMIntegration: Identifiable, Codable, Equatable {
    let id: UUID
    var crmType: CRMType
    var isEnabled: Bool
    var autoCreateNoteEnabled: Bool
    var apiKey: String?
    
    enum CRMType: String, Codable {
        case salesforce = "Salesforce"
        case hubspot = "HubSpot"
        case pipedrive = "Pipedrive"
    }
    
    init(id: UUID = UUID(), crmType: CRMType, isEnabled: Bool = false, autoCreateNoteEnabled: Bool = true, apiKey: String? = nil) {
        self.id = id
        self.crmType = crmType
        self.isEnabled = isEnabled
        self.autoCreateNoteEnabled = autoCreateNoteEnabled
        self.apiKey = apiKey
    }
}

/// Productivity tool integration
struct ProductivityIntegration: Identifiable, Codable, Equatable {
    let id: UUID
    var toolType: ToolType
    var isEnabled: Bool
    var config: [String: String]
    
    enum ToolType: String, Codable {
        case notion = "Notion"
        case obsidian = "Obsidian"
        case linear = "Linear"
        case asana = "Asana"
        case slack = "Slack"
        case appleReminders = "Apple Reminders"
    }
    
    init(id: UUID = UUID(), toolType: ToolType, isEnabled: Bool = false, config: [String: String] = [:]) {
        self.id = id
        self.toolType = toolType
        self.isEnabled = isEnabled
        self.config = config
    }
}

/// Crisp API credentials
struct CrispAPI: Codable, Equatable {
    var clientID: String
    var clientSecret: String
    var accessToken: String?
    var refreshToken: String?
    var expiresAt: Date?
    var tier: APITier
    
    enum APITier: String, Codable {
        case free = "Free"
        case paid = "Paid Partner"
        
        var rateLimitPerMinute: Int {
            switch self {
            case .free: return 100
            case .paid: return Int.max
            }
        }
    }
    
    init(clientID: String = UUID().uuidString, clientSecret: String = UUID().uuidString, accessToken: String? = nil, refreshToken: String? = nil, expiresAt: Date? = nil, tier: APITier = .free) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tier = tier
    }
}

/// Crisp API configuration
struct CrispAPIConfig {
    static let baseURL = "https://api.crisp.ai/v1"
    
    enum Endpoint: String {
        case listMeetings = "/meetings"
        case getMeeting = "/meetings/{id}"
        case createNote = "/meetings/{id}/notes"
        case listActionItems = "/action-items"
        case createActionItem = "/action-items/create"
        case webhookSubscribe = "/webhooks"
    }
}

/// Webhook subscription
struct WebhookSubscription: Identifiable, Codable, Equatable {
    let id: UUID
    var callbackURL: String
    var events: [WebhookEvent]
    var secret: String
    var isActive: Bool
    var createdAt: Date
    
    enum WebhookEvent: String, Codable {
        case meetingStarted = "meeting.started"
        case meetingEnded = "meeting.ended"
        case actionItemCreated = "action_item.created"
        case noteShared = "note.shared"
        case transcriptUpdated = "transcript.updated"
    }
    
    init(id: UUID = UUID(), callbackURL: String, events: [WebhookEvent] = [], secret: String = UUID().uuidString, isActive: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.callbackURL = callbackURL
        self.events = events
        self.secret = secret
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

/// Automation rule
struct AutomationRule: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var trigger: AutomationTrigger
    var actions: [AutomationAction]
    var isEnabled: Bool
    
    enum AutomationTrigger: Codable, Equatable {
        case tagAdded(String)
        case actionItemCreated
        case meetingEnded
        case noteShared
        
        enum CodingKeys: String, CodingKey {
            case type, value
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .tagAdded(let tag):
                try container.encode("tag_added", forKey: .type)
                try container.encode(tag, forKey: .value)
            case .actionItemCreated:
                try container.encode("action_item_created", forKey: .type)
            case .meetingEnded:
                try container.encode("meeting_ended", forKey: .type)
            case .noteShared:
                try container.encode("note_shared", forKey: .type)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "tag_added":
                let value = try container.decode(String.self, forKey: .value)
                self = .tagAdded(value)
            case "action_item_created":
                self = .actionItemCreated
            case "meeting_ended":
                self = .meetingEnded
            case "note_shared":
                self = .noteShared
            default:
                self = .meetingEnded
            }
        }
    }
    
    enum AutomationAction: Codable, Equatable {
        case sendSlackMessage(channel: String, message: String)
        case createLinearTask(title: String, assignee: String?)
        case createAsanaTask(title: String, projectID: String?)
        case addToAppleReminders(title: String)
        case exportToNotion(pageID: String)
        case sendEmail(to: String, subject: String)
        case addTag(String)
        
        enum CodingKeys: String, CodingKey {
            case type, channel, message, title, assignee, projectID, pageID, to, subject, tag
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .sendSlackMessage(let channel, let message):
                try container.encode("send_slack_message", forKey: .type)
                try container.encode(channel, forKey: .channel)
                try container.encode(message, forKey: .message)
            case .createLinearTask(let title, let assignee):
                try container.encode("create_linear_task", forKey: .type)
                try container.encode(title, forKey: .title)
                try container.encodeIfPresent(assignee, forKey: .assignee)
            case .createAsanaTask(let title, let projectID):
                try container.encode("create_asana_task", forKey: .type)
                try container.encode(title, forKey: .title)
                try container.encodeIfPresent(projectID, forKey: .projectID)
            case .addToAppleReminders(let title):
                try container.encode("add_to_apple_reminders", forKey: .type)
                try container.encode(title, forKey: .title)
            case .exportToNotion(let pageID):
                try container.encode("export_to_notion", forKey: .type)
                try container.encode(pageID, forKey: .pageID)
            case .sendEmail(let to, let subject):
                try container.encode("send_email", forKey: .type)
                try container.encode(to, forKey: .to)
                try container.encode(subject, forKey: .subject)
            case .addTag(let tag):
                try container.encode("add_tag", forKey: .type)
                try container.encode(tag, forKey: .tag)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "send_slack_message":
                let channel = try container.decode(String.self, forKey: .channel)
                let message = try container.decode(String.self, forKey: .message)
                self = .sendSlackMessage(channel: channel, message: message)
            case "create_linear_task":
                let title = try container.decode(String.self, forKey: .title)
                let assignee = try container.decodeIfPresent(String.self, forKey: .assignee)
                self = .createLinearTask(title: title, assignee: assignee)
            case "create_asana_task":
                let title = try container.decode(String.self, forKey: .title)
                let projectID = try container.decodeIfPresent(String.self, forKey: .projectID)
                self = .createAsanaTask(title: title, projectID: projectID)
            case "add_to_apple_reminders":
                let title = try container.decode(String.self, forKey: .title)
                self = .addToAppleReminders(title: title)
            case "export_to_notion":
                let pageID = try container.decode(String.self, forKey: .pageID)
                self = .exportToNotion(pageID: pageID)
            case "send_email":
                let to = try container.decode(String.self, forKey: .to)
                let subject = try container.decode(String.self, forKey: .subject)
                self = .sendEmail(to: to, subject: subject)
            case "add_tag":
                let tag = try container.decode(String.self, forKey: .tag)
                self = .addTag(tag)
            default:
                self = .addTag("unknown")
            }
        }
    }
    
    init(id: UUID = UUID(), name: String, trigger: AutomationTrigger, actions: [AutomationAction] = [], isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.actions = actions
        self.isEnabled = isEnabled
    }
}
