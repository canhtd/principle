import Foundation

/// What went wrong in a way the caller can act on.
public enum JournalError: Error, Equatable {
    case taskNotFound(UUID)
    /// Asked to plan a task whose days come from its repeat rule.
    case taskRepeats(UUID)
}

/// Writing and reading tasks. The store's own file is about categories and
/// paths; this is the task half.
extension JournalStore {
    public var tasksFileURL: URL { directoryURL.appendingPathComponent("tasks.jsonl") }

    // MARK: - Write

    @discardableResult
    public func addTask(
        title: String,
        categoryID: UUID? = nil,
        priority: Priority = .nice,
        repeatRule: RepeatRule = .none,
        note: String = "",
        id: UUID = UUID(),
        at date: Date = Date()
    ) throws -> JournalTask {
        let task = JournalTask(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryID: categoryID,
            priority: priority,
            repeatRule: repeatRule,
            note: note,
            createdAt: date
        )
        try save(task, at: date)
        return task
    }

    /// Persists a task as it now stands — the general edit. Read one, change the
    /// fields, hand it back.
    @discardableResult
    public func save(_ task: JournalTask, at date: Date = Date()) throws -> JournalTask {
        try JournalLog.append(TaskRecord(task, updatedAt: date), to: tasksFileURL)
        return task
    }

    /// Removes the task itself. Its past days keep whatever they recorded.
    public func deleteTask(id: UUID, at date: Date = Date()) throws {
        guard let task = storedTasks().first(where: { $0.id == id }) else { return }
        try JournalLog.append(TaskRecord(task, updatedAt: date, removed: true), to: tasksFileURL)
    }

    // MARK: - Read

    /// Every live task, oldest first. A task pointing at a deleted category
    /// comes back with no category at all: the file keeps the old id as
    /// history, but nothing downstream ever sees an id it cannot resolve.
    public func tasks() -> [JournalTask] {
        let liveCategories = Set(categories().map(\.id))
        return storedTasks().map { task in
            guard let categoryID = task.categoryID, !liveCategories.contains(categoryID) else { return task }
            var orphan = task
            orphan.categoryID = nil
            return orphan
        }
    }

    public func task(id: UUID) -> JournalTask? {
        tasks().first { $0.id == id }
    }

    /// The tasks exactly as the file has them, deleted categories and all.
    ///
    /// This is what an edit starts from, so that changing a task's priority
    /// cannot quietly drop the category id the file still remembers — an edit
    /// changes what it was asked to change and nothing else.
    func storedTasks() -> [JournalTask] {
        JournalLog.replay(
            JournalLog.records(TaskRecord.self, at: tasksFileURL),
            id: \.id,
            isRemoved: \.removed,
            // A task line carries the whole task, so the latest line is the task.
            merge: { record, _ in record.task }
        )
    }

    /// Reads a task, changes it, and writes it back — the shape every one-field
    /// edit shares.
    @discardableResult
    func updateTask(id: UUID, at now: Date, _ change: (inout JournalTask) throws -> Void) throws -> JournalTask {
        guard var task = storedTasks().first(where: { $0.id == id }) else { throw JournalError.taskNotFound(id) }
        try change(&task)
        return try save(task, at: now)
    }
}
