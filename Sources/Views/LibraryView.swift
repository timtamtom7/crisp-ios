import SwiftUI

enum SortOption: String, CaseIterable {
    case dateNewest = "Newest"
    case dateOldest = "Oldest"
    case durationLongest = "Longest"
    case durationShortest = "Shortest"
}

enum LibrarySection: String, CaseIterable {
    case all = "All Notes"
    case favorites = "Favorites"
    case folders = "Folders"
}

struct LibraryView: View {
    @State private var notes: [VoiceNote] = []
    @State private var folders: [Folder] = []
    @State private var selectedNote: VoiceNote?
    @State private var isLoading = true

    // Search
    @State private var searchText = ""
    @State private var isSearching = false

    // Folder filter
    @State private var selectedFolderId: UUID?
    @State private var selectedSection: LibrarySection = .all

    // Sorting
    @State private var sortOption: SortOption = .dateNewest

    // UI state
    @State private var showSortMenu = false
    @State private var showFolderPicker = false

    @Binding var showPricing: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Section tabs
                    sectionTabs

                    // Folder chips (when on Folders section)
                    if selectedSection == .folders {
                        folderChips
                    }

                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(DesignTokens.accent)
                        Spacer()
                    } else if isSearching {
                        searchResultsView
                    } else if selectedSection == .favorites && notes.isEmpty {
                        EmptyFavoritesView()
                    } else if selectedSection == .folders && selectedFolderId == nil && notes.isEmpty {
                        EmptyFolderSelectView()
                    } else if selectedFolderId != nil && notes.isEmpty {
                        EmptyFolderView(folderName: selectedFolderName)
                    } else if notes.isEmpty {
                        EmptyLibraryView()
                    } else {
                        notesList
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button {
                                    sortOption = option
                                    sortNotes()
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
                                .font(.system(size: 15))
                                .foregroundColor(DesignTokens.textSecondary)
                        }

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
            .searchable(
                text: $searchText,
                isPresented: $isSearching,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search transcriptions…"
            )
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
            .onChange(of: selectedFolderId) { _, _ in
                loadNotes()
            }
            .onChange(of: selectedSection) { _, _ in
                selectedFolderId = nil
                loadNotes()
            }
            .navigationDestination(item: $selectedNote) { note in
                NoteDetailView(note: note, onDelete: {
                    loadNotes()
                })
            }
        }
        .task {
            loadFolders()
            loadNotes()
        }
        .refreshable {
            loadFolders()
            loadNotes()
        }
    }

    // MARK: - Subviews

    private var sectionTabs: some View {
        HStack(spacing: 0) {
            ForEach([LibrarySection.all, .favorites, .folders], id: \.self) { section in
                Button {
                    withAnimation(DesignTokens.easeOut) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: selectedSection == section ? .semibold : .medium))
                        .foregroundColor(selectedSection == section ? DesignTokens.textPrimary : DesignTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var folderChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(folders) { folder in
                    FolderChip(
                        folder: folder,
                        isSelected: selectedFolderId == folder.id,
                        onTap: {
                            withAnimation(DesignTokens.easeOut) {
                                selectedFolderId = selectedFolderId == folder.id ? nil : folder.id
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sortedNotes) { note in
                    NoteRow(
                        note: note,
                        onFavorite: { toggleFavorite(note) },
                        onMove: {
                            selectedNote = note
                            showFolderPicker = true
                        }
                    )
                    .onTapGesture {
                        selectedNote = note
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    private var searchResultsView: some View {
        Group {
            if notes.isEmpty {
                NoSearchResultsView(query: searchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Text("\(notes.count) result\(notes.count == 1 ? "" : "s")")
                            .font(.system(size: 13))
                            .foregroundColor(DesignTokens.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)

                        ForEach(notes) { note in
                            NoteRow(
                                note: note,
                                onFavorite: { toggleFavorite(note) },
                                onMove: { }
                            )
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
    }

    // MARK: - Computed

    private var sortedNotes: [VoiceNote] {
        switch sortOption {
        case .dateNewest: return notes.sorted { $0.createdAt > $1.createdAt }
        case .dateOldest: return notes.sorted { $0.createdAt < $1.createdAt }
        case .durationLongest: return notes.sorted { $0.duration > $1.duration }
        case .durationShortest: return notes.sorted { $0.duration < $1.duration }
        }
    }

    private var selectedFolderName: String {
        folders.first { $0.id == selectedFolderId }?.name ?? "Folder"
    }

    // MARK: - Actions

    private func loadNotes() {
        isLoading = true
        Task {
            do {
                switch selectedSection {
                case .all:
                    notes = try DatabaseService.shared.fetchAllNotes()
                case .favorites:
                    notes = try DatabaseService.shared.fetchFavoriteNotes()
                case .folders:
                    if let fid = selectedFolderId {
                        notes = try DatabaseService.shared.fetchNotes(folderId: fid)
                    } else {
                        notes = try DatabaseService.shared.fetchAllNotes()
                    }
                }
                isLoading = false
            } catch {
                notes = []
                isLoading = false
            }
        }
    }

    private func loadFolders() {
        Task {
            do {
                folders = try DatabaseService.shared.fetchAllFolders()
            } catch {
                folders = []
            }
        }
    }

    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            loadNotes()
            return
        }
        isLoading = true
        Task {
            do {
                notes = try DatabaseService.shared.searchNotes(query: query)
            } catch {
                notes = []
            }
            isLoading = false
        }
    }

    private func sortNotes() {
        // Trigger UI update
    }

    private func toggleFavorite(_ note: VoiceNote) {
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }
        do {
            try DatabaseService.shared.toggleFavorite(noteId: note.id)
            notes[idx].isFavorite.toggle()
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }
}

// MARK: - NoteRow with Favorite + Move

struct NoteRow: View {
    let note: VoiceNote
    let onFavorite: () -> Void
    let onMove: () -> Void

    @State private var showMoveSheet = false

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                // Waveform icon
                ZStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 20))
                        .foregroundColor(DesignTokens.accent)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(DesignTokens.accent.opacity(0.15))
                        )

                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "FFD700"))
                            .offset(x: 14, y: -14)
                    }
                }

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

                Menu {
                    Button {
                        onFavorite()
                    } label: {
                        Label(
                            note.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: note.isFavorite ? "star.slash" : "star"
                        )
                    }

                    Button {
                        showMoveSheet = true
                    } label: {
                        Label("Move to Folder", systemImage: "folder")
                    }

                    Divider()

                    Button(role: .destructive) {
                        // handled by parent
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.textSecondary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(12)
        }
        .sheet(isPresented: $showMoveSheet) {
            FolderPickerView(
                selectedFolderId: .constant(note.folderId),
                onNoteMove: { newFolderId in
                    do {
                        try DatabaseService.shared.moveNoteToFolder(noteId: note.id, folderId: newFolderId)
                        onMove()
                    } catch {
                        print("Failed to move note: \(error)")
                    }
                }
            )
        }
    }
}

// MARK: - Folder Chip

struct FolderChip: View {
    let folder: Folder
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? DesignTokens.background : Color(hex: folder.colorHex))

                Text(folder.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? DesignTokens.background : DesignTokens.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: folder.colorHex) : Color(hex: folder.colorHex).opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty States

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
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
            Spacer()
        }
    }
}

struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: "FFD700").opacity(0.15))
                    .frame(width: 96, height: 96)

                Image(systemName: "star.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "FFD700"))
            }

            VStack(spacing: 8) {
                Text("No favorites yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)

                Text("Star your most important notes to\nfind them here quickly.")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }
}

struct EmptyFolderView: View {
    let folderName: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            EmptyFolderGraphic()

            VStack(spacing: 8) {
                Text("'\(folderName)' is empty")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)

                Text("Move recordings into this folder to\nkeep them organized.")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }
}

struct EmptyFolderSelectView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DesignTokens.surface)
                    .frame(width: 96, height: 96)

                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 36))
                    .foregroundColor(DesignTokens.accent)
            }

            VStack(spacing: 8) {
                Text("Select a folder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)

                Text("Choose a folder above to view\nrecordings inside it.")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }
}

struct NoSearchResultsView: View {
    let query: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DesignTokens.surface)
                    .frame(width: 96, height: 96)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(DesignTokens.textSecondary)
            }

            VStack(spacing: 8) {
                Text("No results for \"\(query)\"")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)

                Text("Try searching with different\nkeywords or check your spelling.")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }
}

// MARK: - Empty Graphics

struct EmptyFolderGraphic: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(DesignTokens.surface)
                .frame(width: 160, height: 160)

            Image(systemName: "folder.fill")
                .font(.system(size: 56))
                .foregroundColor(DesignTokens.accent.opacity(0.6))
                .offset(y: isAnimating ? -4 : 4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
