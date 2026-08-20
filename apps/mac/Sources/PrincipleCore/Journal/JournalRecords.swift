import Foundation

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
    let schedule: TaskSchedule?
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
        schedule = task.schedule
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
            schedule: schedule,
            plannedDay: plannedDay,
            isDone: done,
            createdAt: createdAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, priority, note, done, removed
        case categoryID = "category_id"
        case repeatRule = "repeat"
        case startMinute = "start_minute"
        case durationMinutes = "duration_minutes"
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
        // The two time fields are written flat rather than as a nested object,
        // so a line stays one readable row in `tasks.jsonl`; a line with no
        // start is an untimed task, whatever it says about a duration.
        if let start = try container.decodeIfPresent(Int.self, forKey: .startMinute) {
            let length = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
            schedule = TaskSchedule(startMinute: start, durationMinutes: length ?? TaskSchedule.defaultDuration)
        } else {
            schedule = nil
        }
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
        if let schedule {
            try container.encode(schedule.startMinute, forKey: .startMinute)
            try container.encode(schedule.durationMinutes, forKey: .durationMinutes)
        }
        try container.encodeIfPresent(plannedDay, forKey: .plannedDay)
        if done { try container.encode(true, forKey: .done) }
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        if removed { try container.encode(true, forKey: .removed) }
    }
}

/// One line of `journal/occurrences.jsonl`: a repeating task on one day.
///
/// This is what "materialised" means — the habit stops being a rule and becomes
/// a row that day can tick. Written once per task and day; ticking it appends
/// another line for the same pair, and the last one counts.
struct OccurrenceRecord: Codable {
    let taskID: UUID
    let day: JournalDay
    let done: Bool
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case day, done
        case taskID = "task_id"
        case updatedAt = "updated_at"
    }

    init(taskID: UUID, day: JournalDay, done: Bool, updatedAt: Date) {
        self.taskID = taskID
        self.day = day
        self.done = done
        self.updatedAt = updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskID = try container.decode(UUID.self, forKey: .taskID)
        day = try container.decode(JournalDay.self, forKey: .day)
        done = try container.decodeIfPresent(Bool.self, forKey: .done) ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(taskID, forKey: .taskID)
        try container.encode(day, forKey: .day)
        if done { try container.encode(true, forKey: .done) }
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
