import Foundation

/// A task as it stands *on one day* — one row of Today.
///
/// Separate from ``JournalTask`` because "done" is a different fact for the two
/// kinds of row: a one-off is done once and for all, while a habit is done on
/// Monday and still waiting on Tuesday. The row carries the answer for its own
/// day, so the UI never has to know which kind it is holding.
public struct PlannedTask: Identifiable, Equatable, Sendable {
    public let taskID: UUID
    public let day: JournalDay
    public let title: String
    /// Resolved, not an id: a row that survived its category's deletion has
    /// `nil` here rather than an id pointing at nothing.
    public let category: JournalCategory?
    public let priority: Priority
    public let note: String
    /// Where the row sits on the grid, or `nil` for a row in the all-day strip.
    public let schedule: TaskSchedule?
    public let isDone: Bool
    /// True for a row that arrived by a repeat rule rather than by being pulled in.
    public let isRepeating: Bool

    /// Unique within a day, which is the only list a row appears in.
    public var id: UUID { taskID }

    public init(
        taskID: UUID,
        day: JournalDay,
        title: String,
        category: JournalCategory?,
        priority: Priority,
        note: String,
        schedule: TaskSchedule? = nil,
        isDone: Bool,
        isRepeating: Bool
    ) {
        self.taskID = taskID
        self.day = day
        self.title = title
        self.category = category
        self.priority = priority
        self.note = note
        self.schedule = schedule
        self.isDone = isDone
        self.isRepeating = isRepeating
    }
}

/// One day, split the way Today is drawn: Must on top, Nice to below (spec #2).
public struct DaySections: Equatable, Sendable {
    public let day: JournalDay
    public let must: [PlannedTask]
    public let nice: [PlannedTask]

    public init(day: JournalDay, must: [PlannedTask], nice: [PlannedTask]) {
        self.day = day
        self.must = must
        self.nice = nice
    }

    /// Both sections in the order they are drawn.
    public var all: [PlannedTask] { must + nice }

    /// The rows the hour grid draws, earliest first — the order overlap
    /// resolution needs, and the order a human reads a day in.
    public var timed: [PlannedTask] {
        all.compactMap { row in row.schedule.map { (row: row, at: $0) } }
            .sorted { ($0.at.startMinute, $0.at.durationMinutes) < ($1.at.startMinute, $1.at.durationMinutes) }
            .map(\.row)
    }

    /// The rows the all-day strip draws, in the order they were created.
    public var untimed: [PlannedTask] { all.filter { $0.schedule == nil } }
}
