import Foundation
import Combine

/// iCloud sync service using NSUbiquitousKeyValueStore for lightweight key-value sync.
final class iCloudSyncService: ObservableObject, @unchecked Sendable {
    static let shared = iCloudSyncService()

    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var hasConflict: Bool = false

    private let store = NSUbiquitousKeyValueStore.default

    // Keys
    private let kNotesKey = "crisp_notes_v2"
    private let kLastSyncKey = "crisp_last_sync"
    private let kSettingsKey = "crisp_settings_v1"

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced
        case conflict
        case error(String)
    }

    private init() {
        setupNotifications()
        loadLastSyncDate()
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleiCloudChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }

    @objc private func handleiCloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            Task { [weak self] in
                await self?.handleServerChange(changeReason: changeReason)
            }
        }
    }

    private func handleServerChange(changeReason: Int) async {
        switch changeReason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            await handleExternalChange()

        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            await MainActor.run {
                self.syncStatus = .error("iCloud storage quota exceeded")
            }

        case NSUbiquitousKeyValueStoreAccountChange:
            await handleExternalChange()

        default:
            break
        }
    }

    // MARK: - Public API

    /// Triggers a full sync: saves local notes to iCloud.
    @MainActor
    func sync() async {
        syncStatus = .syncing

        do {
            try saveToCloudSync()
            syncStatus = .synced
            lastSyncDate = Date()
            saveLastSyncDate()
        } catch {
            syncStatus = .error("Sync failed: \(error.localizedDescription)")
        }
    }

    /// Loads notes from iCloud (returns nil if no cloud data or conflict).
    @MainActor
    func loadFromCloud() async -> [VoiceNote]? {
        syncStatus = .syncing

        guard let data = store.data(forKey: kNotesKey) else {
            syncStatus = .idle
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let notes = try decoder.decode([VoiceNote].self, from: data)
            syncStatus = .synced
            return notes
        } catch {
            syncStatus = .error("Failed to load from iCloud: \(error.localizedDescription)")
            return nil
        }
    }

    /// Saves settings to iCloud.
    func saveSettingsToCloud(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            store.set(data, forKey: kSettingsKey)
            store.synchronize()
        } catch {
            print("iCloud settings save error: \(error)")
        }
    }

    /// Loads settings from iCloud.
    func loadSettingsFromCloud() -> AppSettings? {
        guard let data = store.data(forKey: kSettingsKey) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    /// Checks whether iCloud account is available.
    var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Resolves a conflict by preferring local data.
    @MainActor
    func resolveConflictPreferLocal() async {
        hasConflict = false
        await sync()
    }

    /// Resolves a conflict by preferring cloud data.
    @MainActor
    func resolveConflictPreferCloud() async -> [VoiceNote]? {
        hasConflict = false
        return await loadFromCloud()
    }

    // MARK: - Private Helpers

    private func saveToCloudSync() throws {
        let notes = try DatabaseService.shared.fetchAllNotes()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(notes)
        store.set(data, forKey: kNotesKey)
        store.set(Date().timeIntervalSince1970, forKey: kLastSyncKey)
        store.synchronize()
    }

    private func handleExternalChange() async {
        await MainActor.run {
            self.syncStatus = .syncing
        }

        let cloudNotes = await loadFromCloud()
        guard let cloudNotes = cloudNotes else {
            await MainActor.run { self.syncStatus = .idle }
            return
        }

        do {
            let localNotes = try DatabaseService.shared.fetchAllNotes()
            if localNotes.count != cloudNotes.count {
                await MainActor.run {
                    self.hasConflict = true
                    self.syncStatus = .conflict
                }
            } else {
                await MainActor.run {
                    self.syncStatus = .synced
                    self.lastSyncDate = Date()
                    self.saveLastSyncDate()
                }
            }
        } catch {
            await MainActor.run {
                self.syncStatus = .error("Failed to check local notes: \(error.localizedDescription)")
            }
        }
    }

    private func loadLastSyncDate() {
        let timestamp = store.double(forKey: kLastSyncKey)
        if timestamp > 0 {
            DispatchQueue.main.async { [weak self] in
                self?.lastSyncDate = Date(timeIntervalSince1970: timestamp)
            }
        }
    }

    private func saveLastSyncDate() {
        if let date = lastSyncDate {
            store.set(date.timeIntervalSince1970, forKey: kLastSyncKey)
            store.synchronize()
        }
    }
}

// MARK: - Sync Status View

import SwiftUI

struct SyncStatusIndicator: View {
    @ObservedObject var syncService: iCloudSyncService

    var body: some View {
        HStack(spacing: 6) {
            statusIcon
            statusText
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(statusColor)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch syncService.syncStatus {
        case .idle:
            Image(systemName: "icloud")
        case .syncing:
            ProgressView()
                .scaleEffect(0.6)
                .tint(statusColor)
        case .synced:
            Image(systemName: "checkmark.icloud")
        case .conflict:
            Image(systemName: "exclamationmark.icloud")
        case .error:
            Image(systemName: "xmark.icloud")
        }
    }

    private var statusText: Text {
        switch syncService.syncStatus {
        case .idle:
            return Text("iCloud")
        case .syncing:
            return Text("Syncing…")
        case .synced:
            if let date = syncService.lastSyncDate {
                return Text("Synced \(date.formatted(.relative(presentation: .named)))")
            }
            return Text("Synced")
        case .conflict:
            return Text("Conflict")
        case .error(let msg):
            return Text(msg)
        }
    }

    private var statusColor: Color {
        switch syncService.syncStatus {
        case .idle, .synced:
            return DesignTokens.accent
        case .syncing:
            return DesignTokens.textSecondary
        case .conflict, .error:
            return .orange
        }
    }
}

// MARK: - Sync Conflict Resolution View

struct SyncConflictView: View {
    let localCount: Int
    let cloudCount: Int
    let onResolve: (Bool) -> Void  // true = keep local, false = use cloud

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Sync Conflict Detected")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DesignTokens.textPrimary)

                Text("Your local notes and iCloud have different data. Choose which version to keep.")
                    .font(.system(size: 15))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Stats
            HStack(spacing: 24) {
                StatBox(label: "Local", value: "\(localCount) notes", icon: "iphone")
                StatBox(label: "iCloud", value: "\(cloudCount) notes", icon: "icloud")
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button {
                    onResolve(true)
                    dismiss()
                } label: {
                    Text("Keep Local")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignTokens.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onResolve(false)
                    dismiss()
                } label: {
                    Text("Use iCloud")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignTokens.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DesignTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Decide Later")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.textSecondary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(DesignTokens.background)
    }
}

struct StatBox: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(DesignTokens.accent)

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.textSecondary)

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(DesignTokens.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(DesignTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
