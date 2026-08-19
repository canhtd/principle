import DesignSystem
import PrincipleCore
import SwiftUI

/// Column 3 while a task is being written (spec #22).
///
/// The same fields the detail pane has, over a draft that is not in the journal
/// — see ``TaskDraft``. The rules for what becomes a task are the ones a
/// document has: Enter or Save keeps it, Cancel and Escape throw it away, and
/// walking off keeps whatever has a name and discards what does not.
struct NewTaskPane: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState

    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New task")
                .font(EdenFont.ui(12))
                .foregroundStyle(EdenColor.hex(0x77746F))
                .padding(.bottom, 4)

            TaskField(label: "Title") {
                TaskTextField(prompt: TaskDraft.placeholder, text: draft.title, commit: commit)
                    .focused($titleFocused)
            }
            TaskField(label: "Category") {
                TaskCategoryPicker(categories: journal.categories, categoryID: draft.categoryID)
            }
            TaskField(label: "Priority") {
                DaySegmented(options: Priority.allCases, selection: draft.wrappedValue.priority, title: \.title) {
                    draft.priority.wrappedValue = $0
                }
            }
            TaskField(label: "Time") {
                TimeFields(schedule: draft.wrappedValue.schedule) { draft.schedule.wrappedValue = $0 }
            }
            TaskField(label: "Repeat") {
                RepeatPicker(rule: draft.wrappedValue.repeatRule) { draft.repeatRule.wrappedValue = $0 }
            }
            TaskField(label: "Note") {
                TaskTextField(prompt: "Anything worth remembering", text: draft.note)
            }
            buttons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { titleFocused = true }
        // Walking off — clicking a block, opening another day — is not a way to
        // lose what you have typed, and not a way to acquire a task you never
        // named either.
        .onDisappear(perform: commit)
    }

    private var buttons: some View {
        HStack(spacing: EdenMetric.sidebarInset) {
            Button("Save", action: commit)
                .buttonStyle(EdenPillButtonStyle())
                .disabled(!draft.wrappedValue.isNamed)
            Button("Cancel") { ui.draft = nil }
                .buttonStyle(EdenGhostButtonStyle())
        }
        .padding(.top, EdenMetric.sidebarPadding)
    }

    /// The draft as something the fields can write into. It lives on the shell's
    /// state so that the grid can draw the block from the same value.
    ///
    /// The setter refuses to write once the draft is gone. A field being torn
    /// down writes its value back on the way out, and a plain setter turned that
    /// parting shot into a **new** empty draft — save the task and an untitled
    /// pane opened behind it, every time.
    private var draft: Binding<TaskDraft> {
        Binding(
            get: { ui.draft ?? TaskDraft() },
            set: { if ui.draft != nil { ui.draft = $0 } }
        )
    }

    /// Keeps the draft if it has a name, throws it away if it does not — and
    /// either way this is the only place in the flow that writes a line.
    private func commit() {
        guard let pending = ui.draft else { return }
        ui.draft = nil
        guard pending.isNamed else { return }
        let id = journal.createTask(
            title: pending.title,
            categoryID: pending.categoryID,
            priority: pending.priority,
            repeatRule: pending.repeatRule,
            note: pending.note,
            schedule: pending.schedule
        )
        // The new task stays open, the way Calendar leaves a new event
        // selected — the next thing you do to it is usually more editing.
        ui.select(taskID: id)
    }
}
