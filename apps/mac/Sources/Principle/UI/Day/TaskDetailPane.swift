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
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            back
            if let task = journal.task(id: taskID) {
                field("Title") {
                    textField("Task title", text: $title) { journal.setTitle(title, taskID: taskID) }
                        .focused($titleFocused)
                }
                field("Category") { categoryPicker(task) }
                field("Priority") { priorityToggle(task) }
                field("Time") { TimePicker(schedule: task.schedule) { journal.setSchedule($0, taskID: taskID) } }
                field("Repeat") {
                    RepeatPicker(rule: task.repeatRule) { journal.setRepeatRule($0, taskID: taskID) }
                }
                field("Note") {
                    textField("Anything worth remembering", text: $note) { journal.setNote(note, taskID: taskID) }
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
        // A task the app just made opens ready to be named. Anything else opens
        // with no caret at all: the pane is being read.
        if ui.titleFocusTaskID == taskID {
            ui.titleFocusTaskID = nil
            titleFocused = true
        }
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

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(EdenFont.ui(11))
                .tracking(11 * 0.05)
                .foregroundStyle(EdenColor.hex(0x77746F))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func textField(_ prompt: String, text: Binding<String>, commit: @escaping () -> Void) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .font(EdenFont.ui(13))
            .onSubmit(commit)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(EdenColor.hex(0xF7F7F7), in: .rect(cornerRadius: EdenRadius.sm, style: .continuous))
            .edenBorder(EdenColor.black(10), radius: EdenRadius.sm)
    }

    private func categoryPicker(_ task: JournalTask) -> some View {
        Picker("Category", selection: categoryBinding(task)) {
            Text("None").tag(UUID?.none)
            ForEach(journal.categories) { category in
                Text(category.name).tag(UUID?.some(category.id))
            }
        }
        .labelsHidden()
        .font(EdenFont.ui(13))
    }

    private func categoryBinding(_ task: JournalTask) -> Binding<UUID?> {
        Binding(
            get: { task.categoryID },
            set: { journal.setCategory($0, taskID: taskID) }
        )
    }

    private func priorityToggle(_ task: JournalTask) -> some View {
        HStack(spacing: 0) {
            ForEach(Priority.allCases, id: \.self) { priority in
                let isOn = task.priority == priority
                Button { journal.setPriority(priority, taskID: taskID) } label: {
                    Text(priority.title)
                        .font(EdenFont.ui(12, isOn ? .medium : .regular))
                        .foregroundStyle(isOn ? EdenColor.primary : EdenColor.hex(0x77746F))
                        .padding(.horizontal, EdenMetric.sidebarPadding)
                        .padding(.vertical, 4)
                        .background(isOn ? EdenColor.primary5 : .clear)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(.rect(cornerRadius: EdenRadius.sm, style: .continuous))
        .edenBorder(EdenColor.black(10), radius: EdenRadius.sm)
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
