import Foundation

/// The Journal: categories, tasks, and what each day was planned to hold.
///
/// Everything lives as human-readable JSONL under `<repo>/journal/`, so the repo
/// stays the single memory and Danny can read the files without the app. The
/// repo path is injected, never hardcoded; the calendar is injected too, because
/// "which day is this" is the one question the whole module turns on.
public struct JournalStore: Sendable {
    /// Where the journal lives, relative to the repo root.
    public static let relativeDirectory = "journal"

    public let repoURL: URL
    let calendar: Calendar

    public init(repoURL: URL, calendar: Calendar = .current) {
        self.repoURL = repoURL
        self.calendar = calendar
    }

    public var directoryURL: URL {
        repoURL.appendingPathComponent(Self.relativeDirectory, isDirectory: true)
    }

    public var categoriesFileURL: URL { directoryURL.appendingPathComponent("categories.jsonl") }

    // MARK: - Categories

    /// Creates a category and puts it on disk immediately.
    @discardableResult
    public func addCategory(
        name: String,
        colorKey: String,
        id: UUID = UUID(),
        at date: Date = Date()
    ) throws -> JournalCategory {
        let category = JournalCategory(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            colorKey: colorKey
        )
        try JournalLog.append(
            CategoryRecord(id: category.id, name: category.name, color: category.colorKey, updatedAt: date),
            to: categoriesFileURL
        )
        return category
    }

    /// A rename is one more line, not a rewrite: the file keeps the history of
    /// what this category used to be called.
    public func renameCategory(id: UUID, to name: String, at date: Date = Date()) throws {
        try JournalLog.append(
            CategoryRecord(
                id: id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                color: nil,
                updatedAt: date
            ),
            to: categoriesFileURL
        )
    }

    public func recolorCategory(id: UUID, to colorKey: String, at date: Date = Date()) throws {
        try JournalLog.append(
            CategoryRecord(id: id, name: nil, color: colorKey, updatedAt: date),
            to: categoriesFileURL
        )
    }

    /// Deletes the category itself. Its tasks stay — they simply stop having a
    /// category (see ``tasks()``), which is a re-tagging job, not a data loss.
    public func deleteCategory(id: UUID, at date: Date = Date()) throws {
        try JournalLog.append(
            CategoryRecord(id: id, name: nil, color: nil, updatedAt: date, removed: true),
            to: categoriesFileURL
        )
    }

    /// The live categories, oldest first — the order they were created in,
    /// which is the order the backlog headers read in.
    public func categories() -> [JournalCategory] {
        JournalLog.replay(
            JournalLog.records(CategoryRecord.self, at: categoriesFileURL),
            id: \.id,
            isRemoved: \.removed,
            // A rename or a recolour carries one field: whatever the line leaves
            // out, the category keeps.
            merge: { record, previous in
                JournalCategory(
                    id: record.id,
                    name: record.name ?? previous?.name ?? "",
                    colorKey: record.color ?? previous?.colorKey ?? ""
                )
            }
        )
    }
}
