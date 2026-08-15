import Foundation

/// Reading side of the two JSONL files the app owns: the corpus (KTD3) and the
/// favourites list (KTD6).
///
/// Both are hand-editable — a terminal session appends to favourites, the corpus
/// is generated — so one broken line must cost that line only. Skipped lines are
/// counted and handed back rather than logged here: each store says what a lost
/// line means in its own words.
enum JSONLFile {
    /// Every decodable line, in file order, plus how many were unreadable.
    /// `nil` when the file itself cannot be read, which is a different thing
    /// from a file that decoded to nothing.
    static func decodeLines<T: Decodable>(
        at fileURL: URL,
        as type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) -> (records: [T], skipped: Int)? {
        guard let data = try? Data(contentsOf: fileURL), let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        var records: [T] = []
        var skipped = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let record = try? decoder.decode(T.self, from: Data(trimmed.utf8)) else {
                skipped += 1
                continue
            }
            records.append(record)
        }
        return (records, skipped)
    }
}
