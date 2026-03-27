import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var syncService = iCloudSyncService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showConflictSheet = false
    @State private var isSyncing = false

    private let languages = [
        ("English (US)", "en-US"),
        ("English (UK)", "en-GB"),
        ("Spanish", "es-ES"),
        ("French", "fr-FR"),
        ("German", "de-DE"),
        ("Italian", "it-IT"),
        ("Portuguese", "pt-BR"),
        ("Chinese (Simplified)", "zh-CN"),
        ("Japanese", "ja-JP"),
        ("Korean", "ko-KR")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // iCloud Sync section
                        SettingsSection(title: "iCloud Sync") {
                            GlassCard {
                                VStack(spacing: 14) {
                                    HStack {
                                        Image(systemName: "icloud")
                                            .font(.system(size: 20))
                                            .foregroundColor(syncService.isCloudAvailable ? DesignTokens.accent : DesignTokens.textSecondary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Sync with iCloud")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(DesignTokens.textPrimary)

                                            Text(syncService.isCloudAvailable ? "Keep notes in sync across all your devices" : "Sign in to iCloud to enable sync")
                                                .font(.system(size: 12))
                                                .foregroundColor(DesignTokens.textSecondary)
                                        }

                                        Spacer()

                                        if syncService.syncStatus == .conflict {
                                            Image(systemName: "exclamationmark.icloud")
                                                .foregroundColor(.orange)
                                        } else if syncService.syncStatus == .syncing {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .tint(DesignTokens.accent)
                                        } else if syncService.syncStatus == .synced {
                                            Image(systemName: "checkmark.icloud")
                                                .foregroundColor(DesignTokens.accent)
                                        }
                                    }

                                    if syncService.isCloudAvailable {
                                        HStack(spacing: 12) {
                                            Button {
                                                // iOS 26: Medium haptic for sync action
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                Task {
                                                    isSyncing = true
                                                    await syncService.sync()
                                                    isSyncing = false
                                                }
                                            } label: {
                                                HStack(spacing: 6) {
                                                    if isSyncing {
                                                        ProgressView()
                                                            .scaleEffect(0.6)
                                                            .tint(DesignTokens.background)
                                                    } else {
                                                        Image(systemName: "arrow.triangle.2.circlepath")
                                                            .font(.system(size: 13))
                                                    }
                                                    Text("Sync Now")
                                                        .font(.system(size: 13, weight: .semibold))
                                                }
                                                .foregroundColor(DesignTokens.background)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 36)
                                                .background(DesignTokens.accent)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                            .disabled(isSyncing)

                                            if syncService.syncStatus == .conflict {
                                                Button {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    showConflictSheet = true
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "exclamationmark.triangle")
                                                            .font(.system(size: 11))
                                                        Text("Resolve")
                                                            .font(.system(size: 13, weight: .semibold))
                                                    }
                                                    .foregroundColor(.orange)
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 36)
                                                    .background(Color.orange.opacity(0.15))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                }
                                            }
                                        }

                                        SyncStatusIndicator(syncService: syncService)
                                    } else {
                                        Text("Sign in to iCloud in Settings to enable sync")
                                            .font(.system(size: 12))
                                            .foregroundColor(DesignTokens.textSecondary)
                                            .padding(.top, 4)
                                    }
                                }
                                .padding(16)
                            }
                        }

                        // Crisp Links section
                        SettingsSection(title: "Crisp Links") {
                            GlassCard {
                                VStack(spacing: 12) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "link")
                                            .font(.system(size: 20))
                                            .foregroundColor(DesignTokens.accent)
                                            .frame(width: 40, height: 40)
                                            .background(
                                                Circle()
                                                    .fill(DesignTokens.accent.opacity(0.15))
                                            )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Ephemeral Voice Links")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(DesignTokens.textPrimary)

                                            Text("Share recordings as temporary links")
                                                .font(.system(size: 12))
                                                .foregroundColor(DesignTokens.textSecondary)
                                        }

                                        Spacer()
                                    }

                                    Button {
                                        // Opens Crisp Links management
                                    } label: {
                                        Text("Manage Crisp Links")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(DesignTokens.background)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36)
                                            .background(DesignTokens.accent)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                .padding(16)
                            }
                        }

                        // Language setting
                        SettingsSection(title: "Speech Recognition") {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Language")
                                        .font(.system(size: 13))
                                        .foregroundColor(DesignTokens.textSecondary)

                                    Picker("Language", selection: Binding(
                                        get: { appState.settings.speechLanguage },
                                        set: {
                                            appState.settings.speechLanguage = $0
                                            appState.saveSettings()
                                        }
                                    )) {
                                        ForEach(languages, id: \.1) { lang in
                                            Text(lang.0).tag(lang.1)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(DesignTokens.accent)
                                }
                                .padding(16)
                            }
                        }

                        // Recording settings
                        SettingsSection(title: "Recording") {
                            GlassCard {
                                VStack(spacing: 0) {
                                    Toggle(isOn: Binding(
                                        get: { appState.settings.autoSaveOnStop },
                                        set: {
                                            appState.settings.autoSaveOnStop = $0
                                            appState.saveSettings()
                                        }
                                    )) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Auto-save on stop")
                                                .font(.system(size: 15))
                                                .foregroundColor(DesignTokens.textPrimary)

                                            Text("Automatically save when you stop recording")
                                                .font(.system(size: 12))
                                                .foregroundColor(DesignTokens.textSecondary)
                                        }
                                    }
                                    .tint(DesignTokens.accent)

                                    Divider()
                                        .background(DesignTokens.textSecondary.opacity(0.2))

                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Recording quality")
                                                .font(.system(size: 15))
                                                .foregroundColor(DesignTokens.textPrimary)

                                            Text("\(appState.settings.recordingQuality.displayName) · \(appState.settings.recordingQuality.bitrate)")
                                                .font(.system(size: 12))
                                                .foregroundColor(DesignTokens.textSecondary)
                                        }

                                        Spacer()

                                        Picker("Quality", selection: Binding(
                                            get: { appState.settings.recordingQuality },
                                            set: { newQuality in
                                                appState.settings.recordingQuality = newQuality
                                                appState.saveSettings()
                                            }
                                        )) {
                                            ForEach(RecordingQuality.allCases, id: \.self) { quality in
                                                Text(quality.displayName).tag(quality)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(DesignTokens.accent)
                                    }
                                    .padding(16)
                                }
                            }
                        }

                        // About
                        SettingsSection(title: "About") {
                            GlassCard {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Version")
                                            .font(.system(size: 15))
                                            .foregroundColor(DesignTokens.textPrimary)
                                        Spacer()
                                        Text("1.0.0")
                                            .font(.system(size: 15))
                                            .foregroundColor(DesignTokens.textSecondary)
                                    }

                                    Divider()
                                        .background(DesignTokens.textSecondary.opacity(0.3))

                                    HStack {
                                        Text("Crisp")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(DesignTokens.textPrimary)
                                        Spacer()
                                        Text("Just talk.")
                                            .font(.system(size: 13))
                                            .foregroundColor(DesignTokens.textSecondary)
                                    }
                                }
                                .padding(16)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignTokens.accent)
                }
            }
            .sheet(isPresented: $showConflictSheet) {
                ConflictResolutionSheet()
            }
        }
    }
}

// MARK: - Conflict Resolution Sheet

struct ConflictResolutionSheet: View {
    @StateObject private var syncService = iCloudSyncService.shared
    @State private var localNotes: [VoiceNote] = []
    @State private var cloudNotes: [VoiceNote] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(DesignTokens.accent)
                } else {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: "exclamationmark.icloud")
                                .font(.system(size: 32))
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 16)

                        VStack(spacing: 8) {
                            Text("Sync Conflict")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(DesignTokens.textPrimary)

                            Text("Your local notes and iCloud have different data. Choose which version to keep.")
                                .font(.system(size: 14))
                                .foregroundColor(DesignTokens.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        HStack(spacing: 16) {
                            ConflictOption(
                                icon: "iphone",
                                label: "Local",
                                count: localNotes.count,
                                color: DesignTokens.accent
                            )
                            ConflictOption(
                                icon: "icloud",
                                label: "iCloud",
                                count: cloudNotes.count,
                                color: .blue
                            )
                        }
                        .padding(.horizontal, 24)

                        VStack(spacing: 12) {
                            Button {
                                // iOS 26: Warning haptic for conflict resolution
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                Task {
                                    await syncService.resolveConflictPreferLocal()
                                    dismiss()
                                }
                            } label: {
                                Text("Keep Local")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(DesignTokens.background)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .background(DesignTokens.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button {
                                Task {
                                    if let _ = await syncService.resolveConflictPreferCloud() {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Text("Use iCloud")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(DesignTokens.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .background(DesignTokens.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 24)

                        Button {
                            dismiss()
                        } label: {
                            Text("Decide Later")
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.textSecondary)
                        }

                        Spacer()
                    }
                }
            }
            .navigationTitle("Resolve Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 15))
                    .foregroundColor(DesignTokens.textSecondary)
                }
            }
        }
        .task {
            await loadCounts()
        }
    }

    private func loadCounts() async {
        isLoading = true
        do {
            localNotes = try DatabaseService.shared.fetchAllNotes()
            if let cloud = await syncService.loadFromCloud() {
                cloudNotes = cloud
            }
        } catch {
            localNotes = []
            cloudNotes = []
        }
        isLoading = false
    }
}

struct ConflictOption: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.textSecondary)

            Text("\(count) notes")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(DesignTokens.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(DesignTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.textSecondary)
                .padding(.leading, 4)

            content
        }
    }
}
