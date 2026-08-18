import Foundation

/// Planning a day, and reading it back by section.
extension JournalStore {
    // MARK: - Planning

    /// Pulls a backlog task into a day (spec #8). Planning is one field, so a
    /// task pulled into the wrong day is moved by planning it again.
    ///
    /// A repeating task is refused: its days come from its rule, which is why
    /// the backlog never offers one — and a planned day written on it would be
    /// a field that quietly means nothing.
    @discardableResult
    public func plan(taskID: UUID, on date: Date, at now: Date = Date()) throws -> JournalTask {
        try updateTask(id: taskID, at: now) { task in
            guard !task.repeatRule.isRepeating else { throw JournalError.taskRepeats(taskID) }
            task.plannedDay = JournalDay(date, calendar: calendar)
        }
    }

    /// Re-tags a row, or takes its tag off — the third hover control (spec #4),
    /// and the move a task needs after its category is deleted.
    @discardableResult
    public func setCategory(_ categoryID: UUID?, taskID: UUID, at now: Date = Date()) throws -> JournalTask {
        try updateTask(id: taskID, at: now) { $0.categoryID = categoryID }
    }

    /// Sends a task back to the backlog: it stops belonging to any day, and
    /// keeps everything else it had.
    @discardableResult
    public func sendBackToBacklog(taskID: UUID, at now: Date = Date()) throws -> JournalTask {
        try updateTask(id: taskID, at: now) { $0.plannedDay = nil }
    }

    /// Moves a row between the Must and Nice-to sections (spec #4).
    @discardableResult
    public func setPriority(_ priority: Priority, taskID: UUID, at now: Date = Date()) throws -> JournalTask {
        try updateTask(id: taskID, at: now) { $0.priority = priority }
    }

    /// Ticks or unticks a row on one day.
    ///
    /// The day is what tells the two kinds of row apart: a one-off is done once
    /// and leaves the backlog for good, while a habit is done on that day only —
    /// ticking Monday's run must leave Tuesday's still waiting.
    public func setDone(_ done: Bool, taskID: UUID, on date: Date, at now: Date = Date()) throws {
        guard let task = task(id: taskID) else { throw JournalError.taskNotFound(taskID) }
        guard task.repeatRule.isRepeating else {
            try updateTask(id: taskID, at: now) { $0.isDone = done }
            return
        }
        try setOccurrenceDone(done, taskID: taskID, on: JournalDay(date, calendar: calendar), at: now)
    }

    // MARK: - Reading a day

    /// The day's rows, split into Must and Nice to.
    ///
    /// Throws because reading a day is also what writes its repeating rows down
    /// (see ``materialize(on:)``) — opening Today is the moment a habit becomes
    /// a real, tickable row.
    public func today(_ date: Date) throws -> DaySections {
        let day = JournalDay(date, calendar: calendar)
        let rows = try plannedTasks(on: date)
        return DaySections(
            day: day,
            must: rows.filter { $0.priority == .must },
            nice: rows.filter { $0.priority == .nice }
        )
    }

    /// Every row of a day, in the order the tasks were created and before the
    /// split into sections.
    ///
    /// Reading a day is also what writes its repeating rows down, so a habit
    /// becomes tickable the moment the day is looked at, and stays exactly one
    /// row however many times that happens.
    public func plannedTasks(on date: Date) throws -> [PlannedTask] {
        let day = JournalDay(date, calendar: calendar)
        try materialize(on: date)
        let doneByTask = doneByTask(on: day)
        let categoriesByID = Dictionary(categories().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return tasks().compactMap { task in
            let isDone: Bool
            if task.repeatRule.isRepeating {
                // A habit is on this day only if the day holds a row for it —
                // which is what keeps a rule changed later out of a past day.
                guard let done = doneByTask[task.id] else { return nil }
                isDone = done
            } else {
                guard task.plannedDay == day else { return nil }
                isDone = task.isDone
            }
            return PlannedTask(
                taskID: task.id,
                day: day,
                title: task.title,
                category: task.categoryID.flatMap { categoriesByID[$0] },
                priority: task.priority,
                note: task.note,
                schedule: task.schedule,
                isDone: isDone,
                isRepeating: task.repeatRule.isRepeating
            )
        }
    }
}
