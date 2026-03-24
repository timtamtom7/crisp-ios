import Foundation

/// Tracks subscription state and usage limits for free tier enforcement.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var tier: SubscriptionTier = .free
    @Published var recordingCount: Int = 0
    @Published var isTrialActive: Bool = false
    @Published var trialEndDate: Date?

    private let tierKey = "crisp_subscription_tier"
    private let trialStartKey = "crisp_trial_start_date"
    private let trialDaysKey = "crisp_trial_days"
    private let freeRecordingLimit = 5

    var isTrialEligible: Bool {
        tier == .free && !isTrialActive
    }

    var trialDaysRemaining: Int? {
        guard isTrialActive, let endDate = trialEndDate else { return nil }
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(0, remaining)
    }

    /// Returns true if user can create a new recording.
    var canRecord: Bool {
        switch tier {
        case .free:
            if isTrialActive { return true }
            return recordingCount < freeRecordingLimit
        case .pro, .unlimited:
            return true
        }
    }

    var remainingRecordings: Int? {
        switch tier {
        case .free:
            if isTrialActive { return nil }
            return max(0, freeRecordingLimit - recordingCount)
        case .pro, .unlimited:
            return nil
        }
    }

    /// Prompt for paywall if user has used 5+ recordings on free tier.
    var shouldShowPaywall: Bool {
        tier == .free && recordingCount >= freeRecordingLimit && !isTrialActive
    }

    init() {
        loadState()
    }

    func loadState() {
        let savedTier = UserDefaults.standard.string(forKey: tierKey) ?? "free"
        tier = SubscriptionTier(rawValue: savedTier) ?? .free

        // Check trial status
        if let trialStart = UserDefaults.standard.object(forKey: trialStartKey) as? Date {
            let trialDays = UserDefaults.standard.integer(forKey: trialDaysKey)
            let endDate = Calendar.current.date(byAdding: .day, value: trialDays, to: trialStart)!
            if Date() < endDate {
                isTrialActive = true
                trialEndDate = endDate
            } else {
                isTrialActive = false
                trialEndDate = nil
            }
        }

        // Load recording count
        Task {
            do {
                let notes = try DatabaseService.shared.fetchAllNotes()
                recordingCount = notes.count
            } catch {
                recordingCount = 0
            }
        }
    }

    func startTrial(days: Int = 3) {
        guard tier == .free else { return }
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: start)!
        UserDefaults.standard.set(start, forKey: trialStartKey)
        UserDefaults.standard.set(days, forKey: trialDaysKey)
        isTrialActive = true
        trialEndDate = end
    }

    func upgrade(to newTier: SubscriptionTier) {
        tier = newTier
        UserDefaults.standard.set(newTier.rawValue, forKey: tierKey)
        // Clear trial if upgrading
        isTrialActive = false
        trialEndDate = nil
    }

    func refreshRecordingCount() {
        Task {
            do {
                recordingCount = try DatabaseService.shared.fetchAllNotes().count
            } catch {
                recordingCount = 0
            }
        }
    }
}

enum SubscriptionTier: String, CaseIterable {
    case free
    case pro
    case unlimited

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .unlimited: return "Unlimited"
        }
    }

    var isPro: Bool {
        self != .free
    }

    /// Features that are Pro/Unlimited only.
    static let proOnlyFeatures: [String] = [
        "Bulk operations",
        "Merge recordings",
        "Split recording",
        "Edit transcription",
        "Unlimited recordings"
    ]

    func hasFeature(_ feature: String) -> Bool {
        switch self {
        case .free: return false
        case .pro, .unlimited: return true
        }
    }
}
