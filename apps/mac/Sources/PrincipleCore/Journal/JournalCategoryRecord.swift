import Foundation

/// One line of `journal/categories.jsonl`.
///
/// A rename, a recolour and a delete are all new lines: the last line about an
/// id is the one that counts. `name` and `color` are optional so a delete line
/// stays short, and so a hand-written line missing a field costs that field
/// rather than the whole category.
struct CategoryRecord: Codable {
    let id: UUID
    let name: String?
    let color: String?
    /// The Bar sentence, when this line is the one that sets it. Absent means
    /// "this line says nothing about the bar"; an empty string is how the bar is
    /// taken back, since absence is already spoken for.
    let bar: String?
    let updatedAt: Date
    let removed: Bool

    init(id: UUID, name: String?, color: String?, bar: String? = nil, updatedAt: Date, removed: Bool = false) {
        self.id = id
        self.name = name
        self.color = color
        self.bar = bar
        self.updatedAt = updatedAt
        self.removed = removed
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, bar, removed
        case color = "color_key"
        case updatedAt = "updated_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        bar = try container.decodeIfPresent(String.self, forKey: .bar)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
        removed = try container.decodeIfPresent(Bool.self, forKey: .removed) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(bar, forKey: .bar)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Written only when true, so a live category's line stays the plain shape.
        if removed { try container.encode(true, forKey: .removed) }
    }
}
