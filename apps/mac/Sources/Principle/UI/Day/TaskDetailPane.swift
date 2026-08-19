import DesignSystem
import PrincipleCore
import SwiftUI

/// Everything about one task, in column 3 (spec #5): what it is called, what
/// kind it is, whether it must happen, when, how often it comes back, and
/// anything worth remembering about it.
struct TaskDetailPane: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState
    let taskID: UUID

    @State private var title = ""
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            back
            if let task = journal.task(id: taskID) {
                TaskField(label: "Title") {
                    TaskTextField(prompt: "Task title", text: $title) {
                        journal.setTitle(title, taskID: taskID)
                    }
                }
                TaskField(label: "Category") {
                    TaskCategoryPicker(categories: journal.categories, categoryID: categoryBinding(task))
                }
                TaskField(label: "Priority") { priorityToggle(task) }
                TaskField(label: "Time") {
                    TimeFields(schedule: task.schedule) { journal.setSchedule($0, taskID: taskID) }
                }
                TaskField(label: "Repeat") {
                    RepeatPicker(rule: task.repeatRule) { journal.setRepeatRule($0, taskID: taskID) }
                }
                TaskField(label: "Note") {
                    TaskTextField(prompt: "Anything worth remembering", text: $note) {
                        journal.setNote(note, taskID: taskID)
                    }
                }
                delete
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: load)
        .onChange(of: taskID) { _, _ in load() }
        // Typing is committed when the pane closes as well as on Enter, so a
        // note that was typed and never submitted is not quietly thrown away.
        .onDisappear {
            journal.setTitle(title, taskID: taskID)
            journal.setNote(note, taskID: taskID)
        }
    }

    private func load() {
        let task = journal.task(id: taskID)
        title = task?.title ?? ""
        note = task?.note ?? ""
    }

    private var back: some View {
        Button {
            journal.setTitle(title, taskID: taskID)
            journal.setNote(note, taskID: taskID)
            ui.select(taskID: nil)
        } label: {
            Label("Back", systemImage: "chevron.left")
                .font(EdenFont.ui(12.5))
        }
        .buttonStyle(EdenGhostButtonStyle())
        .padding(.leading, -14)
        .padding(.bottom, 4)
    }

    private var delete: some View {
        Button("Delete task") {
            journal.deleteTask(id: taskID)
            ui.select(taskID: nil)
        }
        .buttonStyle(EdenGhostButtonStyle())
        .padding(.leading, -14)
        .padding(.top, EdenMetric.sidebarPadding)
    }

    private func categoryBinding(_ task: JournalTask) -> Binding<UUID?> {
        Binding(
            get: { task.categoryID },
            set: { journal.setCategory($0, taskID: taskID) }
        )
    }

    private func priorityToggle(_ task: JournalTask) -> some View {
        DaySegmented(
            options: Priority.allCases,
            selection: task.priority,
            title: \.title
        ) { journal.setPriority($0, taskID: taskID) }
    }
}

extension Priority {
    /// The two words the whole app uses for a priority — the detail pane's
    /// toggle and the backlog's groups say the same thing, because they are
    /// about the same field.
    var title: String {
        switch self {
        case .must: "Must do"
        case .nice: "Like to do"
        }
    }
}
