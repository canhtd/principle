import Foundation
import os

/// One line of `memory/favorites.jsonl` (KTD6).
///
/// A save is `{"id":"life:5.6","saved_at":"…"}`; taking it back off the list is
/// the same line plus `"removed":true`. The key is the corpus `id`, the only
/// unique one (KTD3).
public struct FavoriteEntry: Equatable, Sendable {
    public let id: String
    public let savedAt: Date
    /// True for the line that removes a principle from the list.
    public let removed: Bool

    public init(id: String, savedAt: Date = Date(), removed: Bool = false) {
        self.id = id
        self.savedAt = savedAt
        self.removed = removed
    }
}

extension FavoriteEntry: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, removed
        case savedAt = "saved_at"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Only `id` makes the line meaningful. A hand-written line from a
        // terminal session may well be missing the rest; file order, not
        // `saved_at`, is what replay depends on.
        id = try container.decode(String.self, forKey: .id)
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? .distantPast
        removed = try container.decodeIfPresent(Bool.self, forKey: .removed) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(savedAt, forKey: .savedAt)
        // Written only when true, so a save stays exactly the KTD6 shape.
        if removed { try container.encode(true, forKey: .removed) }
    }
}

/// The favourites list at `<repo>/memory/favorites.jsonl` (KTD6).
///
/// Append-only: every ♥ and every un-♥ is a new line, and the current state is
/// the replay of all of them. Nothing is ever rewritten, so the app and a
/// terminal Claude Code session can both write the file without clobbering each
/// other's edits. The repo path is injected, never hardcoded.
public struct FavoritesStore: Sendable {
    /// Where the list lives, relative to the repo root.
    public static let relativePath = "memory/favorites.jsonl"

    public let repoURL: URL

    private static let logger = Logger(subsystem: PrincipleInfo.bundleIdentifier, category: "FavoritesStore")

    public init(repoURL: URL) {
        self.repoURL = repoURL
    }

    public var fileURL: URL {
        Self.relativePath.split(separator: "/").reduce(repoURL) { $0.appendingPathComponent(String($1)) }
    }

    // MARK: - Write

    @discardableResult
    public func favorite(id: String, at date: Date = Date()) throws -> FavoriteEntry {
        let entry = FavoriteEntry(id: id, savedAt: date)
        try append(entry)
        return entry
    }

    @discardableResult
    public func unfavorite(id: String, at date: Date = Date()) throws -> FavoriteEntry {
        let entry = FavoriteEntry(id: id, savedAt: date, removed: true)
        try append(entry)
        return entry
    }

    public func append(_ entry: FavoriteEntry) throws {
        let line = try Self.encoder.encode(entry) + Data("\n".utf8)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // O_APPEND, not seek-then-write: the app and a terminal session share
        // this file, so two writers must not be able to land on the same offset.
        try AppendOnlyFile.append(line, to: fileURL)
    }

    // MARK: - Read

    /// Every readable line, in file order. An unreadable line is skipped and
    /// logged rather than taking the whole list down with it.
    public func entries() -> [FavoriteEntry] {
        guard let result = JSONLFile.decodeLines(at: fileURL, as: FavoriteEntry.self, decoder: Self.decoder) else {
            return []
        }
        if result.skipped > 0 {
            Self.logger.error("Skipped \(result.skipped, privacy: .public) unreadable favourite line(s)")
        }
        return result.records
    }

    /// The current list: the ids still saved, oldest save first. Replaying in
    /// file order is what makes the last line about an id the one that counts.
    public func favoriteIDs() -> [String] {
        var saved: [String] = []
        var active: Set<String> = []
        for entry in entries() {
            if entry.removed {
                guard active.remove(entry.id) != nil else { continue }
                saved.removeAll { $0 == entry.id }
            } else if active.insert(entry.id).inserted {
                saved.append(entry.id)
            }
        }
        return saved
    }

    // MARK: - Coding

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // One line per entry: no pretty-printing, and no escaped slashes for a
        // file that a terminal session reads by eye.
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
