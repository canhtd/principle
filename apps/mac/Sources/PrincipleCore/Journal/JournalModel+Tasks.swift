import Foundation

/// Everything the Day screen does to one task.
extension JournalModel {
    // MARK: - Making one

    /// Dragging on empty grid, or the "+" in column 3's header. Comes back with
    /// the new id so the shell can open it in column 3 straight away — a block
    /// called "New task" is only useful if it can be renamed without hunting
    /// for it.
    ///
    /// A `nil` schedule is the one the "+" makes: it lands in the all-day strip,
    /// because a task typed into the day is a decision that it is happening,
    /// not yet a decision about when.
    @discardableResult
    public func createTask(at schedule: TaskSchedule? = nil, title: String = "New task") -> UUID? {
        var created: UUID?
        write { store in
            let task = try store.addTask(title: title, categoryID: self.defaultCategoryID, schedule: schedule)
            try store.plan(taskID: task.id, on: self.day)
            created = task.id
        }
        return created
    }

    /// Something that happened but was never on the list. It lands on today as
    /// a finished, untimed row — which is what makes it a dot
    /// (spec #13) without inventing a second kind of record.
    /// A task written in full before it existed — column 3's draft (spec #22)
    /// committing itself.
    ///
    /// One append, not four: the draft already knows its category, its
    /// priority, its rule and its time, and a task that arrives in the file as
    /// four successive edits reads like someone changed their mind three times.
    /// A blank title is not a task and writes nothing at all.
    @discardableResult
    public func createTask(
        title: String,
        categoryID: UUID?,
        priority: Priority,
        repeatRule: RepeatRule = .none,
        note: String = "",
        schedule: TaskSchedule?
    ) -> UUID? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var created: UUID?
        write { store in
            let task = try store.addTask(
                title: trimmed,
                categoryID: categoryID,
                priority: priority,
                repeatRule: repeatRule,
                note: note,
                schedule: schedule
            )
            // A repeating task arrives in its days by its rule; planning one on
            // a day is refused by the store, and rightly.
            if !repeatRule.isRepeating { try store.plan(taskID: task.id, on: self.day) }
            created = task.id
        }
        return created
    }

    @discardableResult
    public func logOutcome(title: String, categoryID: UUID?) -> UUID? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var created: UUID?
        write { store in
            let task = try store.addTask(title: trimmed, categoryID: categoryID)
            try store.plan(taskID: task.id, on: self.day)
            try store.setDone(true, taskID: task.id, on: self.day)
            created = task.id
        }
        return created
    }

    /// Column 3's suggestions: a click pulls the task into this day. It arrives
    /// without a time, in the all-day strip, because when it runs is a separate
    /// decision from whether it is happening at all.
    public func pullIntoDay(taskID: UUID) {
        write { try $0.plan(taskID: taskID, on: self.day) }
    }

    public func sendBackToBacklog(taskID: UUID) {
        write { try $0.sendBackToBacklog(taskID: taskID) }
    }

    public func deleteTask(id: UUID) {
        write { try $0.deleteTask(id: id) }
    }

    // MARK: - Editing one

    public func setDone(_ done: Bool, taskID: UUID) {
        write { try $0.setDone(done, taskID: taskID, on: self.day) }
    }

    public func setPriority(_ priority: Priority, taskID: UUID) {
        write { try $0.setPriority(priority, taskID: taskID) }
    }

    public func setCategory(_ categoryID: UUID?, taskID: UUID) {
        write { try $0.setCategory(categoryID, taskID: taskID) }
    }

    public func setTitle(_ title: String, taskID: UUID) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // An empty title would leave a block nothing can be read off; the field
        // keeps what was there until something is typed.
        guard !trimmed.isEmpty, trimmed != task(id: taskID)?.title else { return }
        write { try $0.setTitle(trimmed, taskID: taskID) }
    }

    public func setNote(_ note: String, taskID: UUID) {
        guard note != task(id: taskID)?.note else { return }
        write { try $0.setNote(note, taskID: taskID) }
    }

    public func setRepeatRule(_ rule: RepeatRule, taskID: UUID) {
        write { try $0.setRepeatRule(rule, taskID: taskID) }
    }

    /// Dragging a block, resizing it, dropping an all-day chip onto the grid,
    /// and picking a time in the detail all land here. `nil` sends the task back
    /// to the all-day strip.
    public func setSchedule(_ schedule: TaskSchedule?, taskID: UUID) {
        guard schedule != task(id: taskID)?.schedule else { return }
        write { try $0.setSchedule(schedule, taskID: taskID) }
    }

    /// What anything dropped on the grid gets: the time it was dropped at, and
    /// an hour, which is the length most things turn out to be.
    ///
    /// Two things can be dropped there, and the difference is one write. An
    /// all-day chip is already on this day and only wants a time. A backlog row
    /// is not on any day yet, and dropping it at 14:00 says both things at once
    /// — that it is happening today, and that it happens at two — so it joins
    /// the day in the same change. A repeating task is never planned: its days
    /// come from its rule, and only its time is up for grabs.
    public func schedule(taskID: UUID, startingAt minute: Int) {
        let joinsTheDay = task(id: taskID).map {
            !$0.repeatRule.isRepeating && $0.plannedDay != JournalDay(day, calendar: calendar)
        } ?? false
        let schedule = TaskSchedule(startMinute: minute)
        guard joinsTheDay || schedule != task(id: taskID)?.schedule else { return }
        write { store in
            if joinsTheDay { try store.plan(taskID: taskID, on: self.day) }
            try store.setSchedule(schedule, taskID: taskID)
        }
    }

    /// The category a new row starts with: the first one, so that a block
    /// dragged onto the grid — or a draft opened from column 3's "+" — is
    /// already coloured rather than grey. `nil` only on a journal that has no
    /// categories at all.
    public var defaultCategoryID: UUID? { categories.first?.id }
}
