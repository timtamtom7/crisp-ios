import SwiftUI

enum SortOption: String, CaseIterable {
    case dateNewest = "Newest"
    case dateOldest = "Oldest"
    case durationLongest = "Longest"
    case durationShortest = "Shortest"
    case favoritesFirst = "Favorites First"
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

    // Topic filter (for AI-detected topics)
    @State private var selectedTopic: String?

    // UI state
    @State private var showSortMenu = false
    @State private var showFolderPicker = false

    // Bulk operations
    @State private var isSelectionMode = false
    @State private var selectedNoteIds: Set<UUID> = []
    @State private var showBulkActionSheet = false
    @State private var showBulkDeleteConfirmation = false
    @State private var showBulkMoveSheet = false
    @State private var showBulkExportSheet = false

    @Binding var showPricing: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Selection mode bar
                    if isSelectionMode {
                        selectionModeBar
                    }

                    // Section tabs
                    sectionTabs

                    // Topic filter chips (only on All section, no folder selected)
                    if selectedSection == .all && selectedFolderId == nil {
                        topicFilterChips
                    }

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
                    } else if selectedTopic != nil && sortedNotes.isEmpty {
                        EmptyTopicFilterView(topic: selectedTopic ?? "")
                    } else {
                        notesList
                    }
                }
            }
            .navigationTitle(isSelectionMode ? "\(selectedNoteIds.count) selected" : "Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelectionMode {
                        Button("Cancel") {
                            exitSelectionMode()
                        }
                        .font(.system(size: 15))
                        .foregroundColor(DesignTokens.textSecondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if !isSelectionMode && !notes.isEmpty {
                            Button {
                                enterSelectionMode()
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 15))
                                    .foregroundColor(DesignTokens.textSecondary)
                            }
                        }

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
        .confirmationDialog("Bulk Actions", isPresented: $showBulkActionSheet) {
            Button("Move to Folder") {
                showBulkMoveSheet = true
            }
            Button("Export Selected") {
                showBulkExportSheet = true
            }
            Button("Delete Selected", role: .destructive) {
                showBulkDeleteConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showBulkMoveSheet) {
            FolderPickerView(
                selectedFolderId: .constant(nil),
                onNoteMove: { folderId in
                    bulkMove(to: folderId)
                }
            )
        }
        .sheet(isPresented: $showBulkExportSheet) {
            BulkExportSheet(noteIds: Array(selectedNoteIds))
        }
        .confirmationDialog("Delete \(selectedNoteIds.count) notes?", isPresented: $showBulkDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete \(selectedNoteIds.count) notes", role: .destructive) {
                bulkDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Selection Mode

    private var selectionModeBar: some View {
        HStack(spacing: 16) {
            Button {
                if selectedNoteIds.count == notes.count {
                    selectedNoteIds.removeAll()
                } else {
                    selectedNoteIds = Set(notes.map { $0.id })
                }
            } label: {
                Text(selectedNoteIds.count == notes.count ? "Deselect All" : "Select All")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.accent)
            }

            Spacer()

            Button {
                showBulkActionSheet = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(selectedNoteIds.isEmpty ? DesignTokens.textSecondary : DesignTokens.accent)
            }
            .disabled(selectedNoteIds.isEmpty)

            Button {
                showBulkActionSheet = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 20))
                    .foregroundColor(selectedNoteIds.isEmpty ? DesignTokens.textSecondary : .red)
            }
            .disabled(selectedNoteIds.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DesignTokens.surface)
    }

    private func enterSelectionMode() {
        isSelectionMode = true
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedNoteIds.removeAll()
    }

    private func bulkDelete() {
        Task {
            do {
                try DatabaseService.shared.deleteNotes(ids: Array(selectedNoteIds))
                exitSelectionMode()
                loadNotes()
            } catch {
                print("Bulk delete failed: \(error)")
            }
        }
    }

    private func bulkMove(to folderId: UUID?) {
        Task {
            do {
                try DatabaseService.shared.moveNotesToFolder(noteIds: Array(selectedNoteIds), folderId: folderId)
                exitSelectionMode()
                loadNotes()
            } catch {
                print("Bulk move failed: \(error)")
            }
        }
    }

    // MARK: - Subviews

    private var sectionTabs: some View {
        HStack(spacing: 0) {
            ForEach([LibrarySection.all, .favorites, .folders], id: \.self) { section in
                Button {
                    withAnimation(DesignTokens.easeOut) {
                        selectedSection = section
                        if section != .all {
                            selectedTopic = nil
                        }
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

    /// Horizontal scrolling chip bar for filtering notes by AI-detected topic.
    private var topicFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                TopicChip(
                    label: "All",
                    isSelected: selectedTopic == nil,
                    color: DesignTokens.accent,
                    onTap: {
                        withAnimation(DesignTokens.easeOut) {
                            selectedTopic = nil
                        }
                    }
                )
                .accessibilityLabel("Filter: All topics")

                ForEach(availableTopics, id: \.self) { topic in
                    TopicChip(
                        label: topic,
                        isSelected: selectedTopic == topic,
                        color: topicColor(for: topic),
                        onTap: {
                            withAnimation(DesignTokens.easeOut) {
                                selectedTopic = selectedTopic == topic ? nil : topic
                            }
                        }
                    )
                    .accessibilityLabel("Filter: \(topic)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    /// Returns a color for a given AI-detected topic string.
    private func topicColor(for topic: String) -> Color {
        switch topic {
        case "Meeting": return .blue
        case "Personal": return .pink
        case "Idea": return .yellow
        case "Tutorial": return .green
        case "News": return .orange
        case "Health": return .red
        case "Work": return .purple
        default: return DesignTokens.accent
        }
    }

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sortedNotes) { note in
                    NoteRow(
                        note: note,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedNoteIds.contains(note.id),
                        onFavorite: { toggleFavorite(note) },
                        onMove: {
                            selectedNote = note
                            showFolderPicker = true
                        },
                        onToggleSelect: {
                            toggleSelection(note)
                        }
                    )
                    .onTapGesture {
                        if isSelectionMode {
                            toggleSelection(note)
                        } else {
                            selectedNote = note
                        }
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
                                isSelectionMode: isSelectionMode,
                                isSelected: selectedNoteIds.contains(note.id),
                                onFavorite: { toggleFavorite(note) },
                                onMove: { },
                                onToggleSelect: {
                                    toggleSelection(note)
                                }
                            )
                            .onTapGesture {
                                if isSelectionMode {
                                    toggleSelection(note)
                                } else {
                                    selectedNote = note
                                }
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
        // Apply topic filter first
        let base = topicFilteredNotes

        switch sortOption {
        case .dateNewest:
            return base.sorted { $0.createdAt > $1.createdAt }
        case .dateOldest:
            return base.sorted { $0.createdAt < $1.createdAt }
        case .durationLongest:
            return base.sorted { $0.duration > $1.duration }
        case .durationShortest:
            return base.sorted { $0.duration < $1.duration }
        case .favoritesFirst:
            return base.sorted { note1, note2 in
                if note1.isFavorite != note2.isFavorite {
                    return note1.isFavorite
                }
                return note1.createdAt > note2.createdAt
            }
        }
    }

    /// Notes filtered by the selected AI-detected topic.
    private var topicFilteredNotes: [VoiceNote] {
        guard let topic = selectedTopic else { return notes }
        return notes.filter { $0.topic == topic }
    }

    /// Unique AI-detected topics present in the current notes set.
    private var availableTopics: [String] {
        let topics = notes.compactMap { $0.topic }
        return Array(Set(topics)).sorted()
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

    private func toggleSelection(_ note: VoiceNote) {
        if selectedNoteIds.contains(note.id) {
            selectedNoteIds.remove(note.id)
        } else {
            selectedNoteIds.insert(note.id)
        }
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

// MARK: - NoteRow with Favorite + Move + Selection

struct NoteRow: View {
    let note: VoiceNote
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    let onFavorite: () -> Void
    let onMove: () -> Void
    var onToggleSelect: (() -> Void)? = nil

    @State private var showMoveSheet = false

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                // Selection checkbox or waveform icon
                if isSelectionMode {
                    Button {
                        onToggleSelect?()
                    } label: {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(isSelected ? DesignTokens.accent : DesignTokens.textSecondary)
                    }
                }

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
                    HStack(spacing: 6) {
                        Text(note.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(DesignTokens.textPrimary)
                            .lineLimit(1)

                        // Topic badge
                        if let topic = note.topic {
                            Text(topic)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(topicColor(for: topic))
                                .clipShape(Capsule())
                        }

                        // Sentiment indicator
                        if let sentiment = note.sentiment {
                            Image(systemName: sentimentIcon(for: sentiment))
                                .font(.system(size: 10))
                                .foregroundColor(sentimentColor(for: sentiment))
                        }
                    }

                    HStack(spacing: 8) {
                        Text(note.formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.textSecondary)

                        Text("·")
                            .foregroundColor(DesignTokens.textSecondary)

                        Text(note.formattedDuration)
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.textSecondary)

                        if let wpm = note.speakingPace {
                            Text("·")
                                .foregroundColor(DesignTokens.textSecondary)
                            Text("\(Int(wpm)) wpm")
                                .font(.system(size: 12))
                                .foregroundColor(DesignTokens.textSecondary)
                        }
                    }
                }

                Spacer()

                if !isSelectionMode {
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

    // MARK: - AI Helpers

    private func topicColor(for topic: String) -> Color {
        switch topic {
        case "Meeting": return .blue
        case "Personal": return .pink
        case "Idea": return .yellow
        case "Tutorial": return .green
        case "News": return .orange
        case "Health": return .red
        case "Work": return .purple
        default: return DesignTokens.accent
        }
    }

    private func sentimentIcon(for sentiment: Double) -> String {
        if sentiment > 0.3 { return "face.smiling.fill" }
        if sentiment < -0.3 { return "face.smiling.inverse" }
        return "face.dashed.fill"
    }

    private func sentimentColor(for sentiment: Double) -> Color {
        if sentiment > 0.3 { return .green }
        if sentiment < -0.3 { return .red }
        return DesignTokens.textSecondary
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

/// A pill-shaped chip for filtering notes by AI-detected topic.
struct TopicChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? DesignTokens.background : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.15))
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

/// Empty state shown when a topic filter returns no results.
struct EmptyTopicFilterView: View {
    let topic: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DesignTokens.accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "tag.slash")
                    .font(.system(size: 32))
                    .foregroundColor(DesignTokens.accent)
            }

            VStack(spacing: 6) {
                Text("No \(topic) notes")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignTokens.textPrimary)

                Text("Notes with this topic will appear here once the AI analyzes them.")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
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
