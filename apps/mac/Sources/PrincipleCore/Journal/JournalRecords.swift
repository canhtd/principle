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
    let updatedAt: Date
    let removed: Bool

    init(id: UUID, name: String?, color: String?, updatedAt: Date, removed: Bool = false) {
        self.id = id
        self.name = name
        self.color = color
        self.updatedAt = updatedAt
        self.removed = removed
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, color, removed
        case updatedAt = "updated_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
        removed = try container.decodeIfPresent(Bool.self, forKey: .removed) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Written only when true, so a live category's line stays the plain shape.
        if removed { try container.encode(true, forKey: .removed) }
    }
}

/// One line of `journal/tasks.jsonl`: the whole task as it stands after the
/// change, not the change itself.
///
/// Whole-state lines cost a few bytes and buy two things — a line can be read on
/// its own without replaying the file first, and a lost line costs one version
/// of a task rather than a field that never comes back.
struct TaskRecord: Codable {
    let id: UUID
    let title: String
    let categoryID: UUID?
    let priority: Priority
    let repeatRule: RepeatRule
    let note: String
    let plannedDay: JournalDay?
    let done: Bool
    let createdAt: Date
    let updatedAt: Date
    let removed: Bool

    init(_ task: JournalTask, updatedAt: Date, removed: Bool = false) {
        id = task.id
        title = task.title
        categoryID = task.categoryID
        priority = task.priority
        repeatRule = task.repeatRule
        note = task.note
        plannedDay = task.plannedDay
        done = task.isDone
        createdAt = task.createdAt
        self.updatedAt = updatedAt
        self.removed = removed
    }

    var task: JournalTask {
        JournalTask(
            id: id,
            title: title,
            categoryID: categoryID,
            priority: priority,
            repeatRule: repeatRule,
            note: note,
            plannedDay: plannedDay,
            isDone: done,
            createdAt: createdAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, priority, note, done, removed
        case categoryID = "category_id"
        case repeatRule = "repeat"
        case plannedDay = "planned_day"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Only the id and the title make a line worth keeping; everything else
        // has an obvious empty value, and a hand-written line may well omit it.
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        priority = try container.decodeIfPresent(Priority.self, forKey: .priority) ?? .nice
        repeatRule = try container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule) ?? .none
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        plannedDay = try container.decodeIfPresent(JournalDay.self, forKey: .plannedDay)
        done = try container.decodeIfPresent(Bool.self, forKey: .done) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
        removed = try container.decodeIfPresent(Bool.self, forKey: .removed) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(categoryID, forKey: .categoryID)
        try container.encode(priority, forKey: .priority)
        try container.encode(repeatRule, forKey: .repeatRule)
        // Absent rather than empty: a task with no note writes no note.
        if !note.isEmpty { try container.encode(note, forKey: .note) }
        try container.encodeIfPresent(plannedDay, forKey: .plannedDay)
        if done { try container.encode(true, forKey: .done) }
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        if removed { try container.encode(true, forKey: .removed) }
    }
}
