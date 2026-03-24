import Foundation
import SQLite

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

            // Create notes table (with folderId and isFavorite)
            try db?.run(notes.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(title)
                t.column(transcription)
                t.column(audioFileName)
                t.column(duration)
                t.column(createdAt)
                t.column(folderId)
                t.column(isFavorite)
            })

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
            isFavorite <- note.isFavorite
        )
        try db.run(insert)
    }

    func fetchAllNotes() throws -> [VoiceNote] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var results: [VoiceNote] = []
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        for row in try db.prepare(notes.order(createdAt.desc)) {
            let audioURL = documentsPath.appendingPathComponent(row[audioFileName])
            let note = VoiceNote(
                id: UUID(uuidString: row[id]) ?? UUID(),
                title: row[title],
                transcription: row[transcription],
                audioFileURL: audioURL,
                duration: row[duration],
                createdAt: Date(timeIntervalSince1970: row[createdAt]),
                folderId: row[folderId].flatMap { UUID(uuidString: $0) },
                isFavorite: row[isFavorite]
            )
            results.append(note)
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
            let audioURL = documentsPath.appendingPathComponent(row[audioFileName])
            let note = VoiceNote(
                id: UUID(uuidString: row[id]) ?? UUID(),
                title: row[title],
                transcription: row[transcription],
                audioFileURL: audioURL,
                duration: row[duration],
                createdAt: Date(timeIntervalSince1970: row[createdAt]),
                folderId: row[self.folderId].flatMap { UUID(uuidString: $0) },
                isFavorite: row[isFavorite]
            )
            results.append(note)
        }
        return results
    }

    func fetchFavoriteNotes() throws -> [VoiceNote] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var results: [VoiceNote] = []
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        for row in try db.prepare(notes.filter(isFavorite == true).order(createdAt.desc)) {
            let audioURL = documentsPath.appendingPathComponent(row[audioFileName])
            let note = VoiceNote(
                id: UUID(uuidString: row[id]) ?? UUID(),
                title: row[title],
                transcription: row[transcription],
                audioFileURL: audioURL,
                duration: row[duration],
                createdAt: Date(timeIntervalSince1970: row[createdAt]),
                folderId: row[folderId].flatMap { UUID(uuidString: $0) },
                isFavorite: row[isFavorite]
            )
            results.append(note)
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
            let audioURL = documentsPath.appendingPathComponent(row[audioFileName])
            let note = VoiceNote(
                id: UUID(uuidString: row[id]) ?? UUID(),
                title: row[title],
                transcription: row[transcription],
                audioFileURL: audioURL,
                duration: row[duration],
                createdAt: Date(timeIntervalSince1970: row[createdAt]),
                folderId: row[folderId].flatMap { UUID(uuidString: $0) },
                isFavorite: row[isFavorite]
            )
            results.append(note)
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
            isFavorite <- note.isFavorite
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
        let audioURL = documentsPath.appendingPathComponent(row[audioFileName])

        return VoiceNote(
            id: UUID(uuidString: row[id]) ?? UUID(),
            title: row[title],
            transcription: row[transcription],
            audioFileURL: audioURL,
            duration: row[duration],
            createdAt: Date(timeIntervalSince1970: row[createdAt]),
            folderId: row[folderId].flatMap { UUID(uuidString: $0) },
            isFavorite: row[isFavorite]
        )
    }
}

enum DatabaseError: Error {
    case connectionFailed
    case saveFailed
}
