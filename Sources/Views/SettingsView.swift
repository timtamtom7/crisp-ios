import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

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
                                .padding(16)
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
        }
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
