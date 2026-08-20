import Foundation

/// One line of `journal/reviews.jsonl`: what one Category's Dot stood at on one
/// day, or that it was taken back.
///
/// Same bargain as the other journal files — a new line rather than a rewrite,
/// and the last line about a (day, category) pair is the one that counts. The
/// pair is the identity here, not a record id: there is only ever one Dot per
/// Category per day (ADR 0001), so a second id would be a second way to say the
/// same thing and a way for the two to disagree.
struct ReviewRecord: Codable {
    let day: JournalDay
    let categoryID: UUID
    /// Absent on a `removed` line, which is the whole of "unset": clearing a Dot
    /// deletes it rather than writing a zero.
    let height: Int?
    /// Denormalised at write time so the Dot keeps its Category's last name and
    /// colour after the Category itself is deleted.
    let categoryName: String?
    let colorKey: String?
    let updatedAt: Date
    let removed: Bool

    init(
        day: JournalDay,
        categoryID: UUID,
        height: Int?,
        categoryName: String?,
        colorKey: String?,
        updatedAt: Date,
        removed: Bool = false
    ) {
        self.day = day
        self.categoryID = categoryID
        self.height = height
        self.categoryName = categoryName
        self.colorKey = colorKey
        self.updatedAt = updatedAt
        self.removed = removed
    }

    private enum CodingKeys: String, CodingKey {
        case day, height, removed
        case categoryID = "category_id"
        case categoryName = "category_name"
        case colorKey = "color_key"
        case updatedAt = "updated_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // The day and the category are what make a line mean anything; a line
        // missing either is not about a Dot at all.
        day = try container.decode(JournalDay.self, forKey: .day)
        categoryID = try container.decode(UUID.self, forKey: .categoryID)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        colorKey = try container.decodeIfPresent(String.self, forKey: .colorKey)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
        removed = try container.decodeIfPresent(Bool.self, forKey: .removed) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(categoryID, forKey: .categoryID)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(categoryName, forKey: .categoryName)
        try container.encodeIfPresent(colorKey, forKey: .colorKey)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Written only when true, so a set Dot's line stays the plain shape.
        if removed { try container.encode(true, forKey: .removed) }
    }
}
