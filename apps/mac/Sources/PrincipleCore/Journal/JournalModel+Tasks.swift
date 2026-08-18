import Foundation

/// Everything the Day screen does to one task.
extension JournalModel {
    // MARK: - Making one

    /// Dragging on empty grid. Comes back with the new id so the shell can open
    /// it in column 3 straight away — a block called "New task" is only useful
    /// if it can be renamed without hunting for it.
    @discardableResult
    public func createTask(at schedule: TaskSchedule, title: String = "New task") -> UUID? {
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

    /// What an all-day chip gets when it is dropped on the grid: the time it was
    /// dropped at, and an hour, which is the length most things turn out to be.
    public func schedule(taskID: UUID, startingAt minute: Int) {
        setSchedule(TaskSchedule(startMinute: minute), taskID: taskID)
    }

    /// The category a new row starts with: the first one, so that a block
    /// dragged onto the grid is already colored rather than grey. `nil` only on
    /// a journal that has no categories at all.
    var defaultCategoryID: UUID? { categories.first?.id }
}
