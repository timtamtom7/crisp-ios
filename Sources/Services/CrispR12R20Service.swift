import Foundation
import Combine

/// Crisp R12-R20 Service — aggregates all new features
final class CrispR12R20Service: ObservableObject, @unchecked Sendable {
    static let shared = CrispR12R20Service()
    
    // R12
    @Published var videoRecordings: [VideoRecording] = []
    @Published var meetingCards: [MeetingCard] = []
    @Published var chapterMarkers: [ChapterMarker] = []
    @Published var clipExtractions: [ClipExtraction] = []
    @Published var clipAnalytics: [ClipAnalytics] = []
    
    // R13
    @Published var organizations: [Organization] = []
    @Published var orgInvites: [OrgInvite] = []
    @Published var teamAnalytics: TeamAnalytics = TeamAnalytics()
    @Published var lectureCaptures: [LectureCapture] = []
    @Published var studyGroups: [StudyGroup] = []
    
    // R14
    @Published var calendarIntegrations: [CalendarIntegration] = []
    @Published var videoConferenceIntegrations: [VideoConferenceIntegration] = []
    @Published var crmIntegrations: [CRMIntegration] = []
    @Published var productivityIntegrations: [ProductivityIntegration] = []
    @Published var apiCredentials: CrispAPI?
    @Published var webhookSubscriptions: [WebhookSubscription] = []
    @Published var automationRules: [AutomationRule] = []
    
    // R15
    @Published var currentLocale: SupportedLocale = SupportedLocale.supported[0]
    @Published var accessibilitySettings: AccessibilitySettings = AccessibilitySettings()
    
    // R16
    @Published var crossPlatformDevices: [CrossPlatformDevice] = []
    @Published var webSessions: [WebSession] = []
    @Published var syncConflicts: [SyncConflict] = []
    
    // R17
    @Published var browserExtensionConfigs: [BrowserExtensionConfig] = []
    @Published var browserRecordingSessions: [BrowserRecordingSession] = []
    
    // R18
    @Published var currentTier: CrispSubscriptionTier = .free
    @Published var abTestVariants: [ABTestVariant] = []
    @Published var subscriptionAnalytics: SubscriptionAnalytics = .empty
    
    // R19
    @Published var meetingIntelligences: [MeetingIntelligence] = []
    @Published var collaborativeWorkspaces: [CollaborativeWorkspace] = []
    @Published var recurringThreads: [RecurringMeetingThread] = []
    @Published var enterpriseFeatures: EnterpriseFeatures = EnterpriseFeatures()
    
    // R20
    @Published var platformIntegrations: [PlatformIntegration] = []
    @Published var embeddedSDKConfigs: [EmbeddedSDKConfig] = []
    @Published var partnerProgram: PartnerProgram = PartnerProgram()
    @Published var awardSubmissions: [AwardSubmission] = []
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    private init() { loadFromDisk() }
    
    // MARK: - R12: Video Recording
    
    func createVideoRecording(meetingID: UUID, videoType: VideoRecording.VideoType) -> VideoRecording {
        let recording = VideoRecording(meetingID: meetingID, videoType: videoType)
        videoRecordings.append(recording)
        saveToDisk()
        return recording
    }
    
    func extractClip(meetingID: UUID, startTime: TimeInterval, endTime: TimeInterval, transcriptSelection: String) -> ClipExtraction {
        var clip = ClipExtraction(meetingID: meetingID, startTime: startTime, endTime: endTime, transcriptSelection: transcriptSelection)
        clip.shareLink = "https://crisp.ai/clip/\(clip.id.uuidString)"
        clipExtractions.append(clip)
        saveToDisk()
        return clip
    }
    
    func addChapterMarker(meetingID: UUID, title: String, startTime: TimeInterval, endTime: TimeInterval, transcriptSegment: String = "") {
        let marker = ChapterMarker(meetingID: meetingID, title: title, startTime: startTime, endTime: endTime, transcriptSegment: transcriptSegment)
        chapterMarkers.append(marker)
        saveToDisk()
    }
    
    // MARK: - R13: Team Workspace
    
    func createOrganization(name: String, adminUserID: String) -> Organization {
        let admin = Organization.OrganizationMember(userID: adminUserID, displayName: "Admin", email: "", role: .admin)
        var org = Organization(name: name, members: [admin])
        organizations.append(org)
        saveToDisk()
        return org
    }
    
    func inviteToOrg(_ orgID: UUID, email: String, role: Organization.OrganizationMember.Role) -> OrgInvite {
        guard let orgIndex = organizations.firstIndex(where: { $0.id == orgID }) else {
            return OrgInvite(organizationID: orgID, email: email, role: role)
        }
        let invite = OrgInvite(organizationID: orgID, email: email, role: role)
        orgInvites.append(invite)
        let member = Organization.OrganizationMember(userID: "", displayName: email, email: email, role: role)
        organizations[orgIndex].addMember(member)
        saveToDisk()
        return invite
    }
    
    // MARK: - R14: Integrations
    
    func registerAPI(tier: CrispAPI.APITier) -> CrispAPI {
        let api = CrispAPI(tier: tier)
        apiCredentials = api
        saveToDisk()
        return api
    }
    
    func createAutomationRule(name: String, trigger: AutomationRule.AutomationTrigger, actions: [AutomationRule.AutomationAction]) -> AutomationRule {
        let rule = AutomationRule(name: name, trigger: trigger, actions: actions)
        automationRules.append(rule)
        saveToDisk()
        return rule
    }
    
    func createWebhook(callbackURL: String, events: [WebhookSubscription.WebhookEvent]) -> WebhookSubscription {
        let webhook = WebhookSubscription(callbackURL: callbackURL, events: events)
        webhookSubscriptions.append(webhook)
        saveToDisk()
        return webhook
    }
    
    // MARK: - R16: Cross-Platform
    
    func registerDevice(name: String, platform: CrossPlatformDevice.Platform) -> CrossPlatformDevice {
        let device = CrossPlatformDevice(deviceName: name, platform: platform)
        crossPlatformDevices.append(device)
        saveToDisk()
        return device
    }
    
    // MARK: - R17: Browser Extension
    
    func startBrowserRecording(platform: String) -> BrowserRecordingSession {
        let session = BrowserRecordingSession(platform: platform)
        browserRecordingSessions.append(session)
        saveToDisk()
        return session
    }
    
    // MARK: - R18: Subscription
    
    func subscribe(to tier: CrispSubscriptionTier) async -> Bool {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await MainActor.run {
            currentTier = tier
            saveToDisk()
        }
        return true
    }
    
    // MARK: - R19: Crisp 2.0
    
    func generateMeetingIntelligence(meetingID: UUID) -> MeetingIntelligence {
        let intelligence = MeetingIntelligence(meetingID: meetingID)
        meetingIntelligences.append(intelligence)
        saveToDisk()
        return intelligence
    }
    
    func createCollaborativeWorkspace(meetingID: UUID, participants: [CollaborativeWorkspace.Participant]) -> CollaborativeWorkspace {
        let workspace = CollaborativeWorkspace(meetingID: meetingID, participants: participants)
        collaborativeWorkspaces.append(workspace)
        saveToDisk()
        return workspace
    }
    
    func linkRecurringMeetings(threadName: String, meetingIDs: [UUID], participantIDs: [String]) -> RecurringMeetingThread {
        let thread = RecurringMeetingThread(threadName: threadName, meetingIDs: meetingIDs, participantIDs: participantIDs)
        recurringThreads.append(thread)
        saveToDisk()
        return thread
    }
    
    // MARK: - R20: Platform Ecosystem
    
    func registerEmbeddedSDK(hostAppName: String, hostBundleID: String, licenseType: EmbeddedSDKConfig.LicenseType) -> EmbeddedSDKConfig {
        let config = EmbeddedSDKConfig(hostAppName: hostAppName, hostBundleID: hostBundleID, licenseType: licenseType)
        embeddedSDKConfigs.append(config)
        saveToDisk()
        return config
    }
    
    func submitAward(_ award: AwardSubmission) {
        awardSubmissions.append(award)
        saveToDisk()
    }
    
    // MARK: - Persistence
    
    private let keys = [
        "crisp_video_recordings", "crisp_meeting_cards", "crisp_chapters",
        "crisp_clips", "crisp_clip_analytics",
        "crisp_orgs", "crisp_org_invites", "crisp_lectures", "crisp_study_groups",
        "crisp_cal_integrations", "crisp_video_integrations", "crisp_crm_integrations",
        "crisp_prod_integrations", "crisp_api", "crisp_webhooks", "crisp_automations",
        "crisp_locale", "crisp_accessibility",
        "crisp_devices", "crisp_web_sessions", "crisp_sync_conflicts",
        "crisp_browser_exts", "crisp_browser_sessions",
        "crisp_ab_variants",
        "crisp_intelligences", "crisp_workspaces", "crisp_threads", "crisp_enterprise",
        "crisp_platform_integrations", "crisp_sdk_configs", "crisp_partner", "crisp_awards"
    ]
    
    private func saveToDisk() {
        let encoder = JSONEncoder()
        // Save various arrays
        if let data = try? encoder.encode(videoRecordings) { userDefaults.set(data, forKey: "crisp_video_recordings") }
        if let data = try? encoder.encode(chapterMarkers) { userDefaults.set(data, forKey: "crisp_chapters") }
        if let data = try? encoder.encode(clipExtractions) { userDefaults.set(data, forKey: "crisp_clips") }
        if let data = try? encoder.encode(organizations) { userDefaults.set(data, forKey: "crisp_orgs") }
        if let data = try? encoder.encode(orgInvites) { userDefaults.set(data, forKey: "crisp_org_invites") }
        if let data = try? encoder.encode(lectureCaptures) { userDefaults.set(data, forKey: "crisp_lectures") }
        if let data = try? encoder.encode(studyGroups) { userDefaults.set(data, forKey: "crisp_study_groups") }
        if let data = try? encoder.encode(calendarIntegrations) { userDefaults.set(data, forKey: "crisp_cal_integrations") }
        if let data = try? encoder.encode(videoConferenceIntegrations) { userDefaults.set(data, forKey: "crisp_video_integrations") }
        if let data = try? encoder.encode(crmIntegrations) { userDefaults.set(data, forKey: "crisp_crm_integrations") }
        if let data = try? encoder.encode(productivityIntegrations) { userDefaults.set(data, forKey: "crisp_prod_integrations") }
        if let data = try? encoder.encode(apiCredentials) { userDefaults.set(data, forKey: "crisp_api") }
        if let data = try? encoder.encode(webhookSubscriptions) { userDefaults.set(data, forKey: "crisp_webhooks") }
        if let data = try? encoder.encode(automationRules) { userDefaults.set(data, forKey: "crisp_automations") }
        if let data = try? encoder.encode(crossPlatformDevices) { userDefaults.set(data, forKey: "crisp_devices") }
        if let data = try? encoder.encode(webSessions) { userDefaults.set(data, forKey: "crisp_web_sessions") }
        if let data = try? encoder.encode(syncConflicts) { userDefaults.set(data, forKey: "crisp_sync_conflicts") }
        if let data = try? encoder.encode(browserExtensionConfigs) { userDefaults.set(data, forKey: "crisp_browser_exts") }
        if let data = try? encoder.encode(browserRecordingSessions) { userDefaults.set(data, forKey: "crisp_browser_sessions") }
        if let data = try? encoder.encode(abTestVariants) { userDefaults.set(data, forKey: "crisp_ab_variants") }
        if let data = try? encoder.encode(meetingIntelligences) { userDefaults.set(data, forKey: "crisp_intelligences") }
        if let data = try? encoder.encode(collaborativeWorkspaces) { userDefaults.set(data, forKey: "crisp_workspaces") }
        if let data = try? encoder.encode(recurringThreads) { userDefaults.set(data, forKey: "crisp_threads") }
        if let data = try? encoder.encode(platformIntegrations) { userDefaults.set(data, forKey: "crisp_platform_integrations") }
        if let data = try? encoder.encode(embeddedSDKConfigs) { userDefaults.set(data, forKey: "crisp_sdk_configs") }
        if let data = try? encoder.encode(awardSubmissions) { userDefaults.set(data, forKey: "crisp_awards") }
    }
    
    private func loadFromDisk() {
        let decoder = JSONDecoder()
        if let data = userDefaults.data(forKey: "crisp_video_recordings"),
           let decoded = try? decoder.decode([VideoRecording].self, from: data) { videoRecordings = decoded }
        if let data = userDefaults.data(forKey: "crisp_chapters"),
           let decoded = try? decoder.decode([ChapterMarker].self, from: data) { chapterMarkers = decoded }
        if let data = userDefaults.data(forKey: "crisp_clips"),
           let decoded = try? decoder.decode([ClipExtraction].self, from: data) { clipExtractions = decoded }
        if let data = userDefaults.data(forKey: "crisp_orgs"),
           let decoded = try? decoder.decode([Organization].self, from: data) { organizations = decoded }
        if let data = userDefaults.data(forKey: "crisp_org_invites"),
           let decoded = try? decoder.decode([OrgInvite].self, from: data) { orgInvites = decoded }
        if let data = userDefaults.data(forKey: "crisp_lectures"),
           let decoded = try? decoder.decode([LectureCapture].self, from: data) { lectureCaptures = decoded }
        if let data = userDefaults.data(forKey: "crisp_study_groups"),
           let decoded = try? decoder.decode([StudyGroup].self, from: data) { studyGroups = decoded }
        if let data = userDefaults.data(forKey: "crisp_cal_integrations"),
           let decoded = try? decoder.decode([CalendarIntegration].self, from: data) { calendarIntegrations = decoded }
        if let data = userDefaults.data(forKey: "crisp_video_integrations"),
           let decoded = try? decoder.decode([VideoConferenceIntegration].self, from: data) { videoConferenceIntegrations = decoded }
        if let data = userDefaults.data(forKey: "crisp_crm_integrations"),
           let decoded = try? decoder.decode([CRMIntegration].self, from: data) { crmIntegrations = decoded }
        if let data = userDefaults.data(forKey: "crisp_prod_integrations"),
           let decoded = try? decoder.decode([ProductivityIntegration].self, from: data) { productivityIntegrations = decoded }
        if let data = userDefaults.data(forKey: "crisp_api"),
           let decoded = try? decoder.decode(CrispAPI.self, from: data) { apiCredentials = decoded }
        if let data = userDefaults.data(forKey: "crisp_webhooks"),
           let decoded = try? decoder.decode([WebhookSubscription].self, from: data) { webhookSubscriptions = decoded }
        if let data = userDefaults.data(forKey: "crisp_automations"),
           let decoded = try? decoder.decode([AutomationRule].self, from: data) { automationRules = decoded }
        if let data = userDefaults.data(forKey: "crisp_devices"),
           let decoded = try? decoder.decode([CrossPlatformDevice].self, from: data) { crossPlatformDevices = decoded }
        if let data = userDefaults.data(forKey: "crisp_web_sessions"),
           let decoded = try? decoder.decode([WebSession].self, from: data) { webSessions = decoded }
        if let data = userDefaults.data(forKey: "crisp_sync_conflicts"),
           let decoded = try? decoder.decode([SyncConflict].self, from: data) { syncConflicts = decoded }
        if let data = userDefaults.data(forKey: "crisp_browser_exts"),
           let decoded = try? decoder.decode([BrowserExtensionConfig].self, from: data) { browserExtensionConfigs = decoded }
        if let data = userDefaults.data(forKey: "crisp_browser_sessions"),
           let decoded = try? decoder.decode([BrowserRecordingSession].self, from: data) { browserRecordingSessions = decoded }
        if let data = userDefaults.data(forKey: "crisp_ab_variants"),
           let decoded = try? decoder.decode([ABTestVariant].self, from: data) { abTestVariants = decoded }
        if let data = userDefaults.data(forKey: "crisp_intelligences"),
           let decoded = try? decoder.decode([MeetingIntelligence].self, from: data) { meetingIntelligences = decoded }
        if let data = userDefaults.data(forKey: "crisp_workspaces"),
           let decoded = try? decoder.decode([CollaborativeWorkspace].self, from: data) { collaborativeWorkspaces = decoded }
        if let data = userDefaults.data(forKey: "crisp_threads"),
           let decoded = try? decoder.decode([RecurringMeetingThread].self, from: data) { recurringThreads = decoded }
        if let data = userDefaults.data(forKey: "crisp_platform_integrations"),
           let decoded = try? decoder.decode([PlatformIntegration].self, from: data) { platformIntegrations = decoded }
        if let data = userDefaults.data(forKey: "crisp_sdk_configs"),
           let decoded = try? decoder.decode([EmbeddedSDKConfig].self, from: data) { embeddedSDKConfigs = decoded }
        if let data = userDefaults.data(forKey: "crisp_awards"),
           let decoded = try? decoder.decode([AwardSubmission].self, from: data) { awardSubmissions = decoded }
    }
}
