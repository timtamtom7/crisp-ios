import Foundation
import SQLite
import AVFoundation

final class DatabaseService: @unchecked Sendable {
    static let shared = DatabaseService()

    private var db: Connection?
    private let notes = Table("voice_notes")
    private let folders = Table("folders")

    // Notes columns
    private let id = SQLite.Expression<String>("id")
    private let title = SQLite.Expression<String>("title")
    private let transcription = SQLite.Expression<String>("transcription")
    private let audioFileName = SQLite.Expression<String>("audio_file_name")
    private let duration = SQLite.Expression<Double>("duration")
    private let createdAt = SQLite.Expression<Double>("created_at")
    private let folderId = SQLite.Expression<String?>("folder_id")
    private let isFavorite = SQLite.Expression<Bool>("is_favorite")
    private let aiSummary = SQLite.Expression<String?>("ai_summary")
    private let aiKeywords = SQLite.Expression<String>("ai_keywords")
    private let actionItems = SQLite.Expression<String>("action_items")

    // Folders columns
    private let folderName = SQLite.Expression<String>("name")
    private let folderColor = SQLite.Expression<String>("color_hex")
    private let folderCreatedAt = SQLite.Expression<Double>("created_at")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbPath = documentsPath.appendingPathComponent("crisp.sqlite3")
            db = try Connection(dbPath.path)

            // Create folders table
            try db?.run(folders.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(folderName)
                t.column(folderColor)
                t.column(folderCreatedAt)
            })

            // Create notes table (with AI features)
            try db?.run(notes.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(title)
                t.column(transcription)
                t.column(audioFileName)
                t.column(duration)
                t.column(createdAt)
                t.column(folderId)
                t.column(isFavorite)
                t.column(aiSummary)
                t.column(aiKeywords)
                t.column(actionItems)
            })

            // Migrate existing columns if needed (add AI columns if missing)
            do {
                try db?.run(notes.addColumn(aiSummary, defaultValue: nil as String?))
            } catch { /* column may already exist */ }
            do {
                try db?.run(notes.addColumn(aiKeywords, defaultValue: ""))
            } catch { /* column may already exist */ }
            do {
                try db?.run(notes.addColumn(actionItems, defaultValue: ""))
            } catch { /* column may already exist */ }

            // Insert default folders if none exist
            let count = try db?.scalar(folders.count) ?? 0
            if count == 0 {
                for folder in Folder.defaultFolders {
                    try saveFolder(folder)
                }
            }
        } catch {
            print("Database setup error: \(error)")
        }
    }

    // MARK: - Folders

    func saveFolder(_ folder: Folder) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let insert = folders.insert(
            id <- folder.id.uuidString,
            folderName <- folder.name,
            folderColor <- folder.colorHex,
            folderCreatedAt <- folder.createdAt.timeIntervalSince1970
        )
        try db.run(insert)
    }

    func fetchAllFolders() throws -> [Folder] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var results: [Folder] = []
        for row in try db.prepare(folders.order(folderCreatedAt.asc)) {
            let folder = Folder(
                id: UUID(uuidString: row[id]) ?? UUID(),
                name: row[folderName],
                colorHex: row[folderColor],
                createdAt: Date(timeIntervalSince1970: row[folderCreatedAt])
            )
            results.append(folder)
        }
        return results
    }

    func updateFolder(_ folder: Folder) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let target = folders.filter(id == folder.id.uuidString)
        try db.run(target.update(
            folderName <- folder.name,
            folderColor <- folder.colorHex
        ))
    }

    func deleteFolder(id folderId: UUID) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        // Move notes in this folder to no folder
        let notesInFolder = notes.filter(self.folderId == folderId.uuidString)
        try db.run(notesInFolder.update(self.folderId <- nil))

        let target = folders.filter(id == folderId.uuidString)
        try db.run(target.delete())
    }

    // MARK: - Notes

    private func parseVoiceNote(row: Row, documentsPath: URL) -> VoiceNote {
        let keywordsStr = row[aiKeywords]
        let actionItemsStr = row[actionItems]
        let keywords = keywordsStr.isEmpty ? [] : keywordsStr.components(separatedBy: "|||")
        let actions = actionItemsStr.isEmpty ? [] : actionItemsStr.components(separatedBy: "|||")

        return VoiceNote(
            id: UUID(uuidString: row[id]) ?? UUID(),
            title: row[title],
            transcription: row[transcription],
            audioFileURL: documentsPath.appendingPathComponent(row[audioFileName]),
            duration: row[duration],
            createdAt: Date(timeIntervalSince1970: row[createdAt]),
            folderId: row[folderId].flatMap { UUID(uuidString: $0) },
            isFavorite: row[isFavorite],
            aiSummary: row[aiSummary],
            aiKeywords: keywords,
            actionItems: actions
        )
    }

    func saveNote(_ note: VoiceNote) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let insert = notes.insert(
            id <- note.id.uuidString,
            title <- note.title,
            transcription <- note.transcription,
            audioFileName <- note.audioFileURL.lastPathComponent,
            duration <- note.duration,
            createdAt <- note.createdAt.timeIntervalSince1970,
            folderId <- note.folderId?.uuidString,
            isFavorite <- note.isFavorite,
            aiSummary <- note.aiSummary,
            aiKeywords <- note.aiKeywords.joined(separator: "|||"),
            actionItems <- note.actionItems.joined(separator: "|||")
        )
        try db.run(insert)
    }

    func fetchAllNotes() throws -> [VoiceNote] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var results: [VoiceNote] = []
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        for row in try db.prepare(notes.order(createdAt.desc)) {
            results.append(parseVoiceNote(row: row, documentsPath: documentsPath))
        }
        return results
    }

    func fetchNotes(folderId: UUID?) throws -> [VoiceNote] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var results: [VoiceNote] = []
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        let query: Table
        if let fid = folderId {
            query = notes.filter(self.folderId == fid.uuidString).order(createdAt.desc)
        } else {
            query = notes.order(createdAt.desc)
        }

        for row in try db.prepare(query) {
            results.append(parseVoiceNote(row: row, documentsPath: documentsPath))
        }
        return results
    }

    func fetchFavoriteNotes() throws -> [VoiceNote] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var results: [VoiceNote] = []
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        for row in try db.prepare(notes.filter(isFavorite == true).order(createdAt.desc)) {
            results.append(parseVoiceNote(row: row, documentsPath: documentsPath))
        }
        return results
    }

    func searchNotes(query: String) throws -> [VoiceNote] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return try fetchAllNotes()
        }

        var results: [VoiceNote] = []
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        let searchPattern = "%\(query)%"
        let searchQuery = notes.filter(
            title.like(searchPattern) || transcription.like(searchPattern)
        ).order(createdAt.desc)

        for row in try db.prepare(searchQuery) {
            results.append(parseVoiceNote(row: row, documentsPath: documentsPath))
        }
        return results
    }

    func updateNote(_ note: VoiceNote) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let target = notes.filter(id == note.id.uuidString)
        try db.run(target.update(
            title <- note.title,
            transcription <- note.transcription,
            folderId <- note.folderId?.uuidString,
            isFavorite <- note.isFavorite,
            aiSummary <- note.aiSummary,
            aiKeywords <- note.aiKeywords.joined(separator: "|||"),
            actionItems <- note.actionItems.joined(separator: "|||")
        ))
    }

    func toggleFavorite(noteId: UUID) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        if let note = try fetchNote(id: noteId) {
            let target = notes.filter(id == noteId.uuidString)
            try db.run(target.update(isFavorite <- !note.isFavorite))
        }
    }

    func moveNoteToFolder(noteId: UUID, folderId: UUID?) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let target = notes.filter(id == noteId.uuidString)
        try db.run(target.update(self.folderId <- folderId?.uuidString))
    }

    func deleteNote(id noteId: UUID) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let note = notes.filter(id == noteId.uuidString)
        try db.run(note.delete())
    }

    func fetchNote(id noteId: UUID) throws -> VoiceNote? {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = notes.filter(id == noteId.uuidString)
        guard let row = try db.pluck(query) else { return nil }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return parseVoiceNote(row: row, documentsPath: documentsPath)
    }

    // MARK: - Bulk Operations

    /// Delete multiple notes at once.
    func deleteNotes(ids: [UUID]) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        for noteId in ids {
            // Delete audio file first
            if let note = try fetchNote(id: noteId) {
                try? FileManager.default.removeItem(at: note.audioFileURL)
            }
            let target = notes.filter(id == noteId.uuidString)
            try db.run(target.delete())
        }
    }

    /// Move multiple notes to a folder.
    func moveNotesToFolder(noteIds: [UUID], folderId: UUID?) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        for noteId in noteIds {
            let target = notes.filter(id == noteId.uuidString)
            try db.run(target.update(self.folderId <- folderId?.uuidString))
        }
    }

    /// Fetch notes by their IDs.
    func fetchNotes(ids: [UUID]) throws -> [VoiceNote] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var results: [VoiceNote] = []
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        for noteId in ids {
            let query = notes.filter(id == noteId.uuidString)
            if let row = try db.pluck(query) {
                results.append(parseVoiceNote(row: row, documentsPath: documentsPath))
            }
        }
        return results
    }

    // MARK: - Advanced Editing

    /// Merge multiple notes into a single new note. Returns the merged VoiceNote.
    func mergeNotes(_ notesToMerge: [VoiceNote]) throws -> VoiceNote {
        guard !notesToMerge.isEmpty else { throw DatabaseError.saveFailed }

        let sorted = notesToMerge.sorted { $0.createdAt < $1.createdAt }
        let combinedTranscription = sorted.map { $0.transcription }.joined(separator: "\n\n")
        let totalDuration = sorted.reduce(0) { $0 + $1.duration }
        let earliestDate = sorted.first!.createdAt
        let mergedTitle = sorted.map { $0.title }.joined(separator: " + ")

        // For audio, we keep a reference to the first note's audio
        // (true audio merging would require audio processing — we preserve the files)
        let firstNote = sorted.first!

        let mergedNote = VoiceNote(
            title: String(mergedTitle.prefix(100)),
            transcription: combinedTranscription,
            audioFileURL: firstNote.audioFileURL,
            duration: totalDuration,
            createdAt: earliestDate,
            folderId: firstNote.folderId,
            isFavorite: sorted.contains { $0.isFavorite },
            aiSummary: nil,
            aiKeywords: Array(Set(sorted.flatMap { $0.aiKeywords })).prefix(20).map { $0 },
            actionItems: sorted.flatMap { $0.actionItems }
        )

        try saveNote(mergedNote)
        return mergedNote
    }

    /// Split a note at a given time point. Returns the second half as a new VoiceNote.
    func splitNote(id: UUID, splitAtTime: TimeInterval) throws -> VoiceNote? {
        guard let original = try fetchNote(id: id) else { return nil }
        guard splitAtTime > 0, splitAtTime < original.duration else { return nil }

        // Split transcription at approximately the time point
        let words = original.transcription.split(separator: " ")
        let wordCount = words.count
        let splitIndex = Int(Double(wordCount) * (splitAtTime / original.duration))
        let splitIdx = max(1, min(splitIndex, wordCount - 1))

        let firstPart = words.prefix(splitIdx).joined(separator: " ")
        let secondPart = words.dropFirst(splitIdx).joined(separator: " ")

        // Create the second half as a new note
        let secondNote = VoiceNote(
            title: "\(original.title) (Part 2)",
            transcription: secondPart,
            audioFileURL: original.audioFileURL,
            duration: original.duration - splitAtTime,
            createdAt: original.createdAt.addingTimeInterval(splitAtTime),
            folderId: original.folderId,
            isFavorite: false,
            aiSummary: nil,
            aiKeywords: [],
            actionItems: []
        )

        try saveNote(secondNote)

        // Delete original and create first part as new note
        try deleteNote(id: original.id)

        let firstNote = VoiceNote(
            title: "\(original.title) (Part 1)",
            transcription: firstPart,
            audioFileURL: original.audioFileURL,
            duration: splitAtTime,
            createdAt: original.createdAt,
            folderId: original.folderId,
            isFavorite: original.isFavorite,
            aiSummary: original.aiSummary,
            aiKeywords: original.aiKeywords,
            actionItems: original.actionItems
        )

        try saveNote(firstNote)

        // Actually split the audio file: create a new file for the second part
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let secondPartFileName = "crisp_\(UUID().uuidString).m4a"
        let secondPartURL = documentsPath.appendingPathComponent(secondPartFileName)

        do {
            let sourceFile = try AVAudioFile(forReading: original.audioFileURL)
            let format = sourceFile.processingFormat
            let sampleRate = format.sampleRate
            let splitFrame = AVAudioFramePosition(splitAtTime * sampleRate)
            let totalFrames = sourceFile.length

            guard splitFrame < totalFrames else {
                throw DatabaseError.splitFailed
            }

            let framesToWrite = totalFrames - splitFrame

            // Create the second part audio file
            let secondPartFile = try AVAudioFile(forWriting: secondPartURL, settings: sourceFile.fileFormat.settings)

            // Read and write the second part
            sourceFile.framePosition = splitFrame
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(framesToWrite)) else {
                throw DatabaseError.splitFailed
            }

            try sourceFile.read(into: buffer)
            try secondPartFile.write(from: buffer)

            // Update the second note to point to the new audio file
            try updateNoteAudioURL(noteId: secondNote.id, newAudioURL: secondPartURL)
        } catch {
            // Clean up on failure
            try? FileManager.default.removeItem(at: secondPartURL)
            throw DatabaseError.splitFailed
        }

        return secondNote
    }

    /// Update just the audio file URL for a note.
    private func updateNoteAudioURL(noteId: UUID, newAudioURL: URL) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        let newFileName = newAudioURL.lastPathComponent
        let target = notes.filter(id == noteId.uuidString)
        try db.run(target.update(audioFileName <- newFileName))
    }

    /// Update just the transcription text.
    func updateTranscription(noteId: UUID, newTranscription: String) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let target = notes.filter(id == noteId.uuidString)
        try db.run(target.update(transcription <- newTranscription))
    }
}

enum DatabaseError: Error {
    case connectionFailed
    case saveFailed
    case splitFailed
}
