import Foundation

/// The edits the task detail makes (spec #5): one field at a time, so that
/// changing the note cannot quietly rewrite the repeat rule beside it.
extension JournalStore {
    @discardableResult
    public func setTitle(_ title: String, taskID: UUID, at now: Date = Date()) throws -> JournalTask {
        try updateTask(id: taskID, at: now) {
            $0.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    @discardableResult
    public func setNote(_ note: String, taskID: UUID, at now: Date = Date()) throws -> JournalTask {
        try updateTask(id: taskID, at: now) { $0.note = note }
    }

    /// Changes how often a task comes back.
    ///
    /// A task that starts repeating loses its planned day: its days come from
    /// the rule from now on (which is why ``plan(taskID:on:at:)`` refuses a
    /// repeating task), and a day left written on it would be a field that
    /// means nothing — and that would come back the moment the rule is switched
    /// off again, putting the task on a day nobody chose.
    ///
    /// The schedule is *not* touched: what time a habit runs at is the same
    /// question whether it runs once or every weekday.
    @discardableResult
    public func setRepeatRule(_ rule: RepeatRule, taskID: UUID, at now: Date = Date()) throws -> JournalTask {
        try updateTask(id: taskID, at: now) { task in
            task.repeatRule = rule
            if rule.isRepeating { task.plannedDay = nil }
        }
    }

    /// Puts a task on the grid, moves it, or — with `nil` — takes it back off
    /// into the all-day strip.
    ///
    /// One call for all three because they are one field. Dragging a block,
    /// resizing it, dropping an all-day chip onto the grid and picking a time in
    /// the detail all land here, and all arrive already snapped by
    /// ``TaskSchedule``.
    @discardableResult
    public func setSchedule(_ schedule: TaskSchedule?, taskID: UUID, at now: Date = Date()) throws -> JournalTask {
        try updateTask(id: taskID, at: now) { $0.schedule = schedule }
    }
}
