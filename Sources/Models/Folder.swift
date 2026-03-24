import Foundation

struct Folder: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    let colorHex: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "c8a97e",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    static let defaultFolders: [Folder] = [
        Folder(name: "Work", colorHex: "c8a97e"),
        Folder(name: "Personal", colorHex: "7eb8c8"),
        Folder(name: "Ideas", colorHex: "b87ec8"),
    ]
}
