import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPricing = false

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadContentView(showPricing: $showPricing)
            } else {
                iPhoneContentView(showPricing: $showPricing)
            }
        }
        .sheet(isPresented: $showPricing) {
            PricingView()
        }
    }
}

// MARK: - iPhone (TabView)

struct iPhoneContentView: View {
    @Binding var showPricing: Bool

    var body: some View {
        TabView(selection: .constant(0)) {
            CaptureView(showPricing: $showPricing)
                .tabItem {
                    Label("Capture", systemImage: "mic.fill")
                }
                .tag(0)

            LibraryView(showPricing: $showPricing)
                .tabItem {
                    Label("Library", systemImage: "waveform")
                }
                .tag(1)
        }
        .tint(DesignTokens.accent)
    }
}

// MARK: - iPad (NavigationSplitView)

struct iPadContentView: View {
    @Binding var showPricing: Bool
    @State private var selectedNote: VoiceNote?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var notes: [VoiceNote] = []
    @State private var isLoading = true

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            iPadSidebar(showPricing: $showPricing)
        } content: {
            iPadLibraryList(
                selectedNote: $selectedNote,
                showPricing: $showPricing,
                notes: $notes,
                isLoading: $isLoading
            )
        } detail: {
            if let note = selectedNote {
                NoteDetailView(note: note, onDelete: {
                    selectedNote = nil
                    loadNotes()
                })
            } else {
                iPadWelcomeView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            loadNotes()
        }
    }

    private func loadNotes() {
        isLoading = true
        Task {
            do {
                notes = try DatabaseService.shared.fetchAllNotes()
                isLoading = false
            } catch {
                notes = []
                isLoading = false
            }
        }
    }
}

// MARK: - iPad Sidebar

struct iPadSidebar: View {
    @Binding var showPricing: Bool
    @State private var selectedSection: String = "Capture"

    var body: some View {
        List {
            Section {
                SidebarItem(
                    title: "Capture",
                    icon: "mic.fill",
                    isSelected: selectedSection == "Capture",
                    onTap: { selectedSection = "Capture" }
                )
            }

            Section("Library") {
                SidebarItem(
                    title: "Library",
                    icon: "waveform",
                    isSelected: selectedSection == "Library",
                    onTap: { selectedSection = "Library" }
                )
                SidebarItem(
                    title: "Favorites",
                    icon: "star.fill",
                    isSelected: selectedSection == "Favorites",
                    onTap: { selectedSection = "Favorites" }
                )
                SidebarItem(
                    title: "Folders",
                    icon: "folder.fill",
                    isSelected: selectedSection == "Folders",
                    onTap: { selectedSection = "Folders" }
                )
            }

            Section("Tools") {
                SidebarItem(
                    title: "Crisp Links",
                    icon: "link",
                    isSelected: selectedSection == "Crisp Links",
                    onTap: { selectedSection = "Crisp Links" }
                )
            }

            Section {
                SidebarItem(
                    title: "Settings",
                    icon: "gear",
                    isSelected: selectedSection == "Settings",
                    onTap: { selectedSection = "Settings" }
                )
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.background)
        .navigationTitle("Crisp")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPricing = true
                } label: {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.accent)
                }
            }
        }
    }
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? DesignTokens.accent : DesignTokens.textPrimary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? DesignTokens.accent : DesignTokens.textPrimary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? DesignTokens.accent.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - iPad Library List

struct iPadLibraryList: View {
    @Binding var selectedNote: VoiceNote?
    @Binding var showPricing: Bool
    @Binding var notes: [VoiceNote]
    @Binding var isLoading: Bool

    @State private var sortOption: SortOption = .dateNewest

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
                        LazyVStack(spacing: 10) {
                            ForEach(sortedNotes) { note in
                                iPadNoteRow(
                                    note: note,
                                    isSelected: selectedNote?.id == note.id,
                                    onTap: { selectedNote = note }
                                )
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                }
            }
            .refreshable {
                loadNotes()
            }
        }
        .task {
            loadNotes()
        }
    }

    private var sortedNotes: [VoiceNote] {
        switch sortOption {
        case .dateNewest: return notes.sorted { $0.createdAt > $1.createdAt }
        case .dateOldest: return notes.sorted { $0.createdAt < $1.createdAt }
        case .durationLongest: return notes.sorted { $0.duration > $1.duration }
        case .durationShortest: return notes.sorted { $0.duration < $1.duration }
        case .favoritesFirst:
            return notes.sorted { note1, note2 in
                if note1.isFavorite != note2.isFavorite {
                    return note1.isFavorite
                }
                return note1.createdAt > note2.createdAt
            }
        }
    }

    private func loadNotes() {
        isLoading = true
        Task {
            do {
                notes = try DatabaseService.shared.fetchAllNotes()
                isLoading = false
            } catch {
                notes = []
                isLoading = false
            }
        }
    }
}

// MARK: - iPad Note Row

struct iPadNoteRow: View {
    let note: VoiceNote
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 18))
                        .foregroundColor(DesignTokens.accent)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(DesignTokens.accent.opacity(0.15))
                        )

                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: "FFD700"))
                            .offset(x: 12, y: -12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(note.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignTokens.textPrimary)
                        .lineLimit(1)

                    Text("\(note.formattedDate) · \(note.formattedDuration)")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DesignTokens.accent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                    .fill(isSelected ? DesignTokens.accent.opacity(0.12) : DesignTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                            .stroke(isSelected ? DesignTokens.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - iPad Welcome View

struct iPadWelcomeView: View {
    var body: some View {
        ZStack {
            DesignTokens.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(DesignTokens.accent.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundColor(DesignTokens.accent)
                }

                VStack(spacing: 8) {
                    Text("Crisp")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(DesignTokens.textPrimary)

                    Text("Select a note from the library\nto view it here.")
                        .font(.system(size: 15))
                        .foregroundColor(DesignTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}
