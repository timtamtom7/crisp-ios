import Foundation

// MARK: - Crisp R15: Internationalization, Accessibility, Localization

/// Supported locale
struct SupportedLocale: Identifiable, Codable, Equatable {
    let id: UUID
    var code: String
    var displayName: String
    var nativeName: String
    var isRTL: Bool
    var isSupported: Bool
    var numberFormatterID: String
    var currencyCode: String
    
    init(id: UUID = UUID(), code: String, displayName: String, nativeName: String, isRTL: Bool = false, isSupported: Bool = true, numberFormatterID: String = "en_US", currencyCode: String = "USD") {
        self.id = id
        self.code = code
        self.displayName = displayName
        self.nativeName = nativeName
        self.isRTL = isRTL
        self.isSupported = isSupported
        self.numberFormatterID = numberFormatterID
        self.currencyCode = currencyCode
    }
    
    static let supported: [SupportedLocale] = [
        SupportedLocale(code: "en", displayName: "English", nativeName: "English", numberFormatterID: "en_US", currencyCode: "USD"),
        SupportedLocale(code: "de", displayName: "German", nativeName: "Deutsch", numberFormatterID: "de_DE", currencyCode: "EUR"),
        SupportedLocale(code: "fr", displayName: "French", nativeName: "Français", numberFormatterID: "fr_FR", currencyCode: "EUR"),
        SupportedLocale(code: "es", displayName: "Spanish", nativeName: "Español", numberFormatterID: "es_ES", currencyCode: "EUR"),
        SupportedLocale(code: "it", displayName: "Italian", nativeName: "Italiano", numberFormatterID: "it_IT", currencyCode: "EUR"),
        SupportedLocale(code: "pt-BR", displayName: "Portuguese (Brazil)", nativeName: "Português (Brasil)", numberFormatterID: "pt_BR", currencyCode: "BRL"),
        SupportedLocale(code: "ja", displayName: "Japanese", nativeName: "日本語", numberFormatterID: "ja_JP", currencyCode: "JPY"),
        SupportedLocale(code: "ko", displayName: "Korean", nativeName: "한국어", numberFormatterID: "ko_KR", currencyCode: "KRW"),
        SupportedLocale(code: "zh-Hans", displayName: "Chinese (Simplified)", nativeName: "简体中文", numberFormatterID: "zh_CN", currencyCode: "CNY"),
        SupportedLocale(code: "ar", displayName: "Arabic", nativeName: "العربية", isRTL: true, numberFormatterID: "ar-SA", currencyCode: "SAR"),
    ]
}

/// Regional pricing
struct RegionalPricing: Identifiable, Codable, Equatable {
    let id: UUID
    var regionCode: String
    var regionName: String
    var currencyCode: String
    var currencySymbol: String
    var pppMultiplier: Double
    var adjustedPrices: [String: Decimal]
    
    static let defaultRegions: [RegionalPricing] = [
        RegionalPricing(id: UUID(), regionCode: "US", regionName: "United States", currencyCode: "USD", currencySymbol: "$", pppMultiplier: 1.0, adjustedPrices: ["pro": 9.99, "team": 14.99]),
        RegionalPricing(id: UUID(), regionCode: "IN", regionName: "India", currencyCode: "INR", currencySymbol: "₹", pppMultiplier: 0.15, adjustedPrices: ["pro": 299, "team": 449]),
        RegionalPricing(id: UUID(), regionCode: "BR", regionName: "Brazil", currencyCode: "BRL", currencySymbol: "R$", pppMultiplier: 0.35, adjustedPrices: ["pro": 29.9, "team": 44.9]),
        RegionalPricing(id: UUID(), regionCode: "DE", regionName: "Germany", currencyCode: "EUR", currencySymbol: "€", pppMultiplier: 0.95, adjustedPrices: ["pro": 8.99, "team": 13.49]),
        RegionalPricing(id: UUID(), regionCode: "JP", regionName: "Japan", currencyCode: "JPY", currencySymbol: "¥", pppMultiplier: 0.8, adjustedPrices: ["pro": 980, "team": 1480]),
    ]
}

/// Accessibility settings
struct AccessibilitySettings: Codable, Equatable {
    var isVoiceOverEnabled: Bool
    var isDynamicTypeEnabled: Bool
    var isReduceMotionEnabled: Bool
    var preferredContentSize: ContentSize
    var colorContrastMode: ColorContrast
    var hapticFeedbackEnabled: Bool
    
    enum ContentSize: String, Codable {
        case extraSmall, small, medium, large, extraLarge, xxxLarge
    }
    
    enum ColorContrast: String, Codable {
        case standard, high
    }
    
    init(isVoiceOverEnabled: Bool = true, isDynamicTypeEnabled: Bool = true, isReduceMotionEnabled: Bool = false, preferredContentSize: ContentSize = .large, colorContrastMode: ColorContrast = .standard, hapticFeedbackEnabled: Bool = true) {
        self.isVoiceOverEnabled = isVoiceOverEnabled
        self.isDynamicTypeEnabled = isDynamicTypeEnabled
        self.isReduceMotionEnabled = isReduceMotionEnabled
        self.preferredContentSize = preferredContentSize
        self.colorContrastMode = colorContrastMode
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
    }
}

// MARK: - Crisp R16: Android, Web, Cross-Platform Sync

/// Cross-platform device
struct CrossPlatformDevice: Identifiable, Codable, Equatable {
    let id: UUID
    var deviceName: String
    var platform: Platform
    var lastSyncAt: Date
    var meetingCount: Int
    var isPrimary: Bool
    
    enum Platform: String, Codable {
        case ios, android, web, watchOS
    }
    
    init(id: UUID = UUID(), deviceName: String, platform: Platform, lastSyncAt: Date = Date(), meetingCount: Int = 0, isPrimary: Bool = false) {
        self.id = id
        self.deviceName = deviceName
        self.platform = platform
        self.lastSyncAt = lastSyncAt
        self.meetingCount = meetingCount
        self.isPrimary = isPrimary
    }
}

/// Web session
struct WebSession: Identifiable, Codable, Equatable {
    let id: UUID
    var userID: String
    var accessToken: String
    var expiresAt: Date
    var isPro: Bool
    
    init(id: UUID = UUID(), userID: String, accessToken: String = UUID().uuidString, expiresAt: Date = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date(), isPro: Bool = false) {
        self.id = id
        self.userID = userID
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.isPro = isPro
    }
}

/// Sync conflict
struct SyncConflict: Identifiable, Codable, Equatable {
    let id: UUID
    var noteID: UUID
    var localVersion: SyncVersion
    var remoteVersion: SyncVersion
    var resolution: Resolution?
    
    struct SyncVersion: Codable, Equatable {
        let deviceID: String
        let modifiedAt: Date
        let checksum: String
    }
    
    enum Resolution: String, Codable {
        case keepLocal, keepRemote, keepBoth
    }
    
    init(id: UUID = UUID(), noteID: UUID, localVersion: SyncVersion, remoteVersion: SyncVersion, resolution: Resolution? = nil) {
        self.id = id
        self.noteID = noteID
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.resolution = resolution
    }
}

// MARK: - Crisp R17: Chrome Extension, Browser Recorder

/// Browser extension configuration
struct BrowserExtensionConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var browser: Browser
    var isEnabled: Bool
    var permissionsGranted: Bool
    var autoRecordEnabled: Bool
    
    enum Browser: String, Codable {
        case chrome = "Chrome"
        case safari = "Safari"
        case firefox = "Firefox"
    }
    
    init(id: UUID = UUID(), browser: Browser, isEnabled: Bool = false, permissionsGranted: Bool = false, autoRecordEnabled: Bool = false) {
        self.id = id
        self.browser = browser
        self.isEnabled = isEnabled
        self.permissionsGranted = permissionsGranted
        self.autoRecordEnabled = autoRecordEnabled
    }
}

/// Browser recording session
struct BrowserRecordingSession: Identifiable, Codable, Equatable {
    let id: UUID
    var platform: String // Google Meet, Zoom Web, etc.
    var recordingURL: URL?
    var startedAt: Date
    var endedAt: Date?
    var transcript: String
    
    init(id: UUID = UUID(), platform: String, recordingURL: URL? = nil, startedAt: Date = Date(), endedAt: Date? = nil, transcript: String = "") {
        self.id = id
        self.platform = platform
        self.recordingURL = recordingURL
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.transcript = transcript
    }
}

// MARK: - Crisp R18: Subscription Business

/// Crisp subscription tier
struct CrispSubscriptionTier: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var displayName: String
    var monthlyPrice: Decimal
    var annualPrice: Decimal
    var lifetimePrice: Decimal
    var features: [String]
    var isMostPopular: Bool
    
    static let free = CrispSubscriptionTier(id: UUID(), name: "free", displayName: "Free", monthlyPrice: 0, annualPrice: 0, lifetimePrice: 0, features: ["3 meetings/month", "30-min recordings", "Basic transcription"], isMostPopular: false)
    static let pro = CrispSubscriptionTier(id: UUID(), name: "pro", displayName: "Pro", monthlyPrice: 9.99, annualPrice: 95.88, lifetimePrice: 199, features: ["Unlimited meetings", "Unlimited recordings", "AI summaries", "Video recording", "Cloud backup", "All integrations"], isMostPopular: true)
    static let team = CrispSubscriptionTier(id: UUID(), name: "team", displayName: "Team", monthlyPrice: 14.99, annualPrice: 143.88, lifetimePrice: 0, features: ["Everything in Pro", "Team workspace", "Admin controls", "SSO", "Compliance logging"], isMostPopular: false)
    static let family = CrispSubscriptionTier(id: UUID(), name: "family", displayName: "Family", monthlyPrice: 19.99, annualPrice: 191.88, lifetimePrice: 0, features: ["Up to 5 members", "Separate vaults", "Shared team workspace", "Family analytics"], isMostPopular: false)
}

/// A/B test variant
struct ABTestVariant: Identifiable, Codable, Equatable {
    let id: UUID
    var testName: String
    var variantName: String
    var payload: [String: String]
    
    init(id: UUID = UUID(), testName: String, variantName: String, payload: [String: String] = [:]) {
        self.id = id
        self.testName = testName
        self.variantName = variantName
        self.payload = payload
    }
}

/// Subscription analytics
struct SubscriptionAnalytics: Codable, Equatable {
    var mrr: Double
    var arr: Double
    var churnRate: Double
    var ltv: Double
    var trialToPaidRate: Double
    var activeSubscriptions: Int
    
    static let empty = SubscriptionAnalytics(mrr: 0, arr: 0, churnRate: 0, ltv: 0, trialToPaidRate: 0, activeSubscriptions: 0)
}
