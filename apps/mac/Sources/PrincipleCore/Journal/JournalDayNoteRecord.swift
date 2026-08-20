import Foundation

/// One line of `journal/notes.jsonl`: what Danny wrote about a whole day.
///
/// The day is the identity — one note per day, the way there is one Dot per
/// Category per day — so there is no record id to disagree with it. Same
/// bargain as the other journal files: a new line rather than a rewrite, and
/// the last line about a day is the one that counts.
struct DayNoteRecord: Codable {
    let day: JournalDay
    /// Absent on a `removed` line, which is the whole of "no note": clearing the
    /// field deletes the note rather than storing an empty string.
    let text: String?
    let updatedAt: Date
    let removed: Bool

    init(day: JournalDay, text: String?, updatedAt: Date, removed: Bool = false) {
        self.day = day
        self.text = text
        self.updatedAt = updatedAt
        self.removed = removed
    }

    private enum CodingKeys: String, CodingKey {
        case day, text, removed
        case updatedAt = "updated_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Without a day the line is not about any day, which is all a note is.
        day = try container.decode(JournalDay.self, forKey: .day)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
        removed = try container.decodeIfPresent(Bool.self, forKey: .removed) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Written only when true, so a written note's line stays the plain shape.
        if removed { try container.encode(true, forKey: .removed) }
    }
}
