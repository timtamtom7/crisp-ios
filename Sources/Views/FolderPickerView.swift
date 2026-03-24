import SwiftUI

struct FolderPickerView: View {
    @Binding var selectedFolderId: UUID?
    let onNoteMove: (UUID?) -> Void

    @State private var folders: [Folder] = []
    @State private var showCreateFolder = false
    @State private var showDeleteConfirmation = false
    @State private var folderToDelete: Folder?
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
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            // All Notes option
                            FolderRow(
                                folder: nil,
                                isSelected: selectedFolderId == nil,
                                onTap: {
                                    selectedFolderId = nil
                                    onNoteMove(nil)
                                    dismiss()
                                }
                            )

                            // Favorites
                            FolderRow(
                                folder: Folder(name: "Favorites", colorHex: "FFD700"),
                                isSelected: false,
                                isFavorites: true,
                                onTap: { }
                            )

                            Divider()
                                .background(DesignTokens.textSecondary.opacity(0.3))
                                .padding(.vertical, 4)

                            ForEach(folders) { folder in
                                FolderRow(
                                    folder: folder,
                                    isSelected: selectedFolderId == folder.id,
                                    onTap: {
                                        selectedFolderId = folder.id
                                        onNoteMove(folder.id)
                                        dismiss()
                                    }
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        folderToDelete = folder
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete Folder", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.accent)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .foregroundColor(DesignTokens.accent)
                    }
                }
            }
            .sheet(isPresented: $showCreateFolder) {
                CreateFolderView { newFolder in
                    folders.append(newFolder)
                }
            }
            .confirmationDialog("Delete Folder?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let folder = folderToDelete {
                        deleteFolder(folder)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Notes in this folder will be moved to All Notes.")
            }
        }
        .task {
            loadFolders()
        }
    }

    private func loadFolders() {
        isLoading = true
        Task {
            do {
                folders = try DatabaseService.shared.fetchAllFolders()
            } catch {
                folders = []
            }
            isLoading = false
        }
    }

    private func deleteFolder(_ folder: Folder) {
        do {
            try DatabaseService.shared.deleteFolder(id: folder.id)
            folders.removeAll { $0.id == folder.id }
            if selectedFolderId == folder.id {
                selectedFolderId = nil
            }
        } catch {
            print("Failed to delete folder: \(error)")
        }
    }
}

struct FolderRow: View {
    let folder: Folder?
    let isSelected: Bool
    var isFavorites: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(folderColor)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(folderColor.opacity(0.15))
                    )

                Text(folderName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignTokens.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignTokens.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                    .fill(isSelected ? DesignTokens.accent.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        if isFavorites {
            return "star.fill"
        }
        switch folder?.name.lowercased() {
        case "work": return "briefcase.fill"
        case "personal": return "person.fill"
        case "ideas": return "lightbulb.fill"
        default: return "folder.fill"
        }
    }

    private var folderName: String {
        if isFavorites { return "Favorites" }
        return folder?.name ?? "All Notes"
    }

    private var folderColor: Color {
        if isFavorites { return Color(hex: "FFD700") }
        return Color(hex: folder?.colorHex ?? "c8a97e")
    }
}

struct CreateFolderView: View {
    let onCreated: (Folder) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var folderName = ""
    @State private var selectedColor = "c8a97e"
    @State private var showError = false
    @State private var errorMessage = ""

    private let colorOptions = [
        "c8a97e", "7eb8c8", "b87ec8", "7ec88a", "c87e7e", "7ec8c8"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Folder preview
                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedColor).opacity(0.15))
                                .frame(width: 100, height: 100)

                            Image(systemName: "folder.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color(hex: selectedColor))
                        }
                        .padding(.top, 20)

                        // Name input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Folder Name")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignTokens.textSecondary)

                            TextField("e.g. Work, Personal, Ideas", text: $folderName)
                                .font(.system(size: 16))
                                .foregroundColor(DesignTokens.textPrimary)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                                        .fill(DesignTokens.surface)
                                )
                        }
                        .padding(.horizontal, 20)

                        // Color picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignTokens.textSecondary)
                                .padding(.horizontal, 20)

                            HStack(spacing: 16) {
                                ForEach(colorOptions, id: \.self) { color in
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                                .padding(3)
                                        )
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        createFolder()
                    }
                    .foregroundColor(folderName.trimmingCharacters(in: .whitespaces).isEmpty ? DesignTokens.textSecondary : DesignTokens.accent)
                    .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Folder Creation Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func createFolder() {
        let trimmedName = folderName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let folder = Folder(name: trimmedName, colorHex: selectedColor)
        do {
            try DatabaseService.shared.saveFolder(folder)
            onCreated(folder)
            dismiss()
        } catch {
            errorMessage = "Could not create folder. Please try again."
            showError = true
        }
    }
}
