import SwiftUI

struct LibraryView: View {
    @State private var notes: [VoiceNote] = []
    @State private var selectedNote: VoiceNote?
    @State private var isLoading = true
    @Binding var showPricing: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(DesignTokens.accent)
                } else if notes.isEmpty {
                    EmptyLibraryView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notes) { note in
                                NoteRow(note: note)
                                    .onTapGesture {
                                        selectedNote = note
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $selectedNote) { note in
                NoteDetailView(note: note, onDelete: {
                    loadNotes()
                })
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPricing = true
                    } label: {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 15))
                            .foregroundColor(DesignTokens.accent)
                    }
                }
            }
        }
        .task {
            loadNotes()
        }
        .refreshable {
            loadNotes()
        }
    }

    private func loadNotes() {
        isLoading = true
        Task {
            do {
                notes = try DatabaseService.shared.fetchAllNotes()
            } catch {
                notes = []
            }
            isLoading = false
        }
    }
}

struct NoteRow: View {
    let note: VoiceNote

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                // Waveform icon
                Image(systemName: "waveform")
                    .font(.system(size: 20))
                    .foregroundColor(DesignTokens.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(DesignTokens.accent.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DesignTokens.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(note.formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.textSecondary)

                        Text("·")
                            .foregroundColor(DesignTokens.textSecondary)

                        Text(note.formattedDuration)
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.textSecondary)
            }
            .padding(12)
        }
    }
}

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 24) {
            EmptyLibraryGraphic()

            VStack(spacing: 8) {
                Text("No voice notes yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)

                Text("Your transcribed notes will live here.\nTap the record button to capture your first thought.")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}
