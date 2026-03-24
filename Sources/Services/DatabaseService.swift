import Foundation
import SQLite

final class DatabaseService: @unchecked Sendable {
    static let shared = DatabaseService()

    private var db: Connection?
    private let notes = Table("voice_notes")

    // Columns
    private let id = SQLite.Expression<String>("id")
    private let title = SQLite.Expression<String>("title")
    private let transcription = SQLite.Expression<String>("transcription")
    private let audioFileName = SQLite.Expression<String>("audio_file_name")
    private let duration = SQLite.Expression<Double>("duration")
    private let createdAt = SQLite.Expression<Double>("created_at")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbPath = documentsPath.appendingPathComponent("crisp.sqlite3")
            db = try Connection(dbPath.path)

            try db?.run(notes.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(title)
                t.column(transcription)
                t.column(audioFileName)
                t.column(duration)
                t.column(createdAt)
            })
        } catch {
            print("Database setup error: \(error)")
        }
    }

    func saveNote(_ note: VoiceNote) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let insert = notes.insert(
            id <- note.id.uuidString,
            title <- note.title,
            transcription <- note.transcription,
            audioFileName <- note.audioFileURL.lastPathComponent,
            duration <- note.duration,
            createdAt <- note.createdAt.timeIntervalSince1970
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
                createdAt: Date(timeIntervalSince1970: row[createdAt])
            )
            results.append(note)
        }
        return results
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
            createdAt: Date(timeIntervalSince1970: row[createdAt])
        )
    }
}

enum DatabaseError: Error {
    case connectionFailed
    case saveFailed
}
