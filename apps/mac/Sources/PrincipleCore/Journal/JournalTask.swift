import Foundation

/// Must, or nice to have. The two sections Today is split into (spec #2), and
/// the only priority the app has — there is no third level and no number.
public enum Priority: String, CaseIterable, Codable, Sendable {
    case must
    case nice
}

/// One thing to do — in the backlog until it is pulled into a day, or a habit
/// that arrives on its days by itself.
///
/// `plannedDay` and `isDone` describe a one-off task. A repeating task ignores
/// both: it is planned by its rule, and its done state belongs to the day it was
/// done on (see ``TaskOccurrence``), because ticking Monday's run must not tick
/// Tuesday's.
public struct JournalTask: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    /// `nil` once the category it pointed at is deleted: the task survives and
    /// waits to be re-tagged.
    public var categoryID: UUID?
    public var priority: Priority
    public var repeatRule: RepeatRule
    public var note: String
    /// Where the task sits on the day's grid, or `nil` for a task with no time
    /// yet — the all-day strip. A repeating task keeps one schedule for all of
    /// its days: a habit at 07:00 is at 07:00 every day it comes back.
    public var schedule: TaskSchedule?
    public var plannedDay: JournalDay?
    public var isDone: Bool
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        categoryID: UUID? = nil,
        priority: Priority = .nice,
        repeatRule: RepeatRule = .none,
        note: String = "",
        schedule: TaskSchedule? = nil,
        plannedDay: JournalDay? = nil,
        isDone: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.categoryID = categoryID
        self.priority = priority
        self.repeatRule = repeatRule
        self.note = note
        self.schedule = schedule
        self.plannedDay = plannedDay
        self.isDone = isDone
        self.createdAt = createdAt
    }
}
