import Foundation
import os

/// The append-only JSONL files the Journal keeps under `<repo>/journal/`.
///
/// Same bargain the favourites list makes (KTD6): every change is a new line
/// and the current state is the replay of all of them, so the app and a
/// terminal session can both write without clobbering each other, and a line
/// that cannot be read costs that line only.
enum JournalLog {
    private static let logger = Logger(subsystem: PrincipleInfo.bundleIdentifier, category: "Journal")

    /// Appends one record as a single line. `O_APPEND` inside ``AppendOnlyFile``
    /// is what keeps two writers from landing on the same offset.
    static func append(_ record: some Encodable, to fileURL: URL) throws {
        let line = try encoder.encode(record) + Data("\n".utf8)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try AppendOnlyFile.append(line, to: fileURL)
    }

    /// Every readable line, in file order. A missing file reads as no records —
    /// an empty journal and a journal not yet started look the same to a query.
    static func records<T: Decodable>(_ type: T.Type = T.self, at fileURL: URL) -> [T] {
        guard let result = JSONLFile.decodeLines(at: fileURL, as: T.self, decoder: decoder) else { return [] }
        if result.skipped > 0 {
            logger.error(
                "Skipped \(result.skipped, privacy: .public) unreadable line(s) in \(fileURL.lastPathComponent, privacy: .public)"
            )
        }
        return result.records
    }

    /// One line per record, keys sorted, slashes unescaped: these files sit in
    /// the repo to be read by eye and diffed, not only by the app.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
