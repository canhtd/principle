import Foundation
import os

/// One principle from the local corpus, verbatim.
///
/// Never assembled from model output: the engine cites ids, the app renders
/// what the file says (AE2). Roughly half of the 515 records carry a heading
/// and nothing else — that heading *is* the principle, so `body` stays empty
/// rather than being filled in (AE3).
public struct PrincipleRecord: Codable, Identifiable, Equatable, Sendable {
    /// Unique across the whole corpus, e.g. `life:5.6`. The only safe key: 515
    /// records share just ~414 distinct `num`s (KTD3).
    public let id: String
    /// "Nguyên tắc sống" or "Nguyên tắc làm việc".
    public let part: String
    /// Empty for the handful of records that belong to no chapter.
    public let chapter: String
    public let num: String
    public let title: String
    public let body: String
    public let hasBody: Bool

    public init(
        id: String,
        part: String,
        chapter: String,
        num: String,
        title: String,
        body: String,
        hasBody: Bool
    ) {
        self.id = id
        self.part = part
        self.chapter = chapter
        self.num = num
        self.title = title
        self.body = body
        self.hasBody = hasBody
    }

    private enum CodingKeys: String, CodingKey {
        case id, part, chapter, num, title, body
        case hasBody = "has_body"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // `id` and `title` are the record; anything else may be absent in a
        // hand-edited or older corpus without making the line unusable.
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        part = try container.decodeIfPresent(String.self, forKey: .part) ?? ""
        chapter = try container.decodeIfPresent(String.self, forKey: .chapter) ?? ""
        num = try container.decodeIfPresent(String.self, forKey: .num) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        hasBody = try container.decodeIfPresent(Bool.self, forKey: .hasBody) ?? !body.isEmpty
    }

    /// The body to draw, or `nil` when the record is a heading only (AE3).
    /// Never an empty paragraph, never invented text.
    public var displayBody: String? {
        guard hasBody else { return nil }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// `5.6 · Nguyên tắc sống · Chương 5 …`, with empty parts dropped so a
    /// chapterless record does not render a dangling separator.
    public var caption: String {
        [num, part, chapter]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// The local principle corpus, read from `corpus.jsonl` in the repo.
///
/// The file is gitignored (the translation is copyrighted), so a checkout
/// without it is normal rather than an error: the store loads empty and cards
/// are simply unavailable.
public struct CorpusStore: Sendable {
    /// Where the corpus lives, relative to the repo root.
    public static let relativePath = ".claude/skills/ask-ray/references/corpus.jsonl"

    public let records: [PrincipleRecord]
    private let byID: [String: PrincipleRecord]
    private let byNum: [String: [PrincipleRecord]]

    private static let logger = Logger(subsystem: PrincipleInfo.bundleIdentifier, category: "CorpusStore")

    public init(records: [PrincipleRecord]) {
        var byID: [String: PrincipleRecord] = [:]
        var byNum: [String: [PrincipleRecord]] = [:]
        var kept: [PrincipleRecord] = []
        for record in records where !record.id.isEmpty {
            // First occurrence wins; a duplicated id would otherwise make the
            // same citation render differently depending on file order.
            guard byID[record.id] == nil else { continue }
            byID[record.id] = record
            byNum[record.num, default: []].append(record)
            kept.append(record)
        }
        self.records = kept
        self.byID = byID
        self.byNum = byNum
    }

    /// Loads the corpus belonging to `repoURL`. The repo path is injected the
    /// same way `SessionStore` takes it — never hardcoded.
    public init(repoURL: URL) {
        self.init(fileURL: Self.corpusURL(inRepo: repoURL))
    }

    public init(fileURL: URL) {
        self.init(records: Self.decodeRecords(at: fileURL))
    }

    public static func corpusURL(inRepo repoURL: URL) -> URL {
        relativePath.split(separator: "/").reduce(repoURL) { $0.appendingPathComponent(String($1)) }
    }

    // MARK: - Lookup

    public var isEmpty: Bool { records.isEmpty }
    public var count: Int { records.count }

    /// The primary index. `id` is the only unique key in the corpus (KTD3).
    public func principle(id: String) -> PrincipleRecord? { byID[id] }

    /// Resolves cited ids in the order they were cited. Ids the corpus does not
    /// know are dropped rather than faked into a card (AE2).
    public func principles(ids: [String]) -> [PrincipleRecord] { ids.compactMap { byID[$0] } }

    /// Secondary index, for manual lookup only. `num` is *not* a key: "2.1"
    /// exists in both parts of the book.
    public func principles(num: String) -> [PrincipleRecord] { byNum[num] ?? [] }

    // MARK: - Reading the file

    private static func decodeRecords(at fileURL: URL) -> [PrincipleRecord] {
        // One broken line must not cost the other 514 principles.
        guard let result = JSONLFile.decodeLines(at: fileURL, as: PrincipleRecord.self) else {
            logger.notice(
                "No readable corpus at \(fileURL.path, privacy: .public); principle cards are unavailable"
            )
            return []
        }
        if result.skipped > 0 {
            logger.error("Skipped \(result.skipped, privacy: .public) unreadable corpus line(s)")
        }
        return result.records
    }
}
