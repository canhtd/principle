import DesignSystem
import PrincipleCore
import SwiftUI

/// The backlog: what the day could still take on, in the two groups it is read
/// in — what must happen, then what would be nice to (decision 21).
///
/// A group with nothing in it is not drawn at all. An empty heading is a promise
/// the list is not keeping.
struct BacklogPane: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Backlog")
                .font(EdenFont.ui(12))
                .foregroundStyle(EdenColor.hex(0x77746F))

            if let line = emptyLine {
                Text(line)
                    .font(EdenFont.ui(12))
                    .foregroundStyle(EdenColor.n400)
                    .padding(.leading, EdenMetric.sidebarInset)
            } else {
                let must = journal.backlogTasks(priority: .must)
                group("Must do", tasks: must, isFirst: true)
                // Whichever group is drawn first sits straight under the header;
                // only a group with one above it opens a gap.
                group("Like to do", tasks: journal.backlogTasks(priority: .nice), isFirst: must.isEmpty)
            }

            LaterSection()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Nothing to show has two causes, and they want different words: a backlog
    /// that is genuinely clear, and one whose every row is behind an unticked
    /// category. The second is a filter to undo, not a list to fill.
    private var emptyLine: String? {
        guard journal.visibleSuggestions.isEmpty else { return nil }
        return journal.suggestions.isEmpty
            ? "Nothing in the backlog."
            : "Nothing in the categories you are showing."
    }

    /// The prototype's `.grph`: 11.5 pt in the faintest neutral, one step
    /// quieter than the `Backlog` header above it, and in sentence case —
    /// nothing on this screen shouts in capitals.
    @ViewBuilder
    private func group(_ label: String, tasks: [JournalTask], isFirst: Bool) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(EdenFont.ui(11.5))
                    .foregroundStyle(EdenColor.n400)
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        BacklogRow(journal: journal, ui: ui, task: task)
                    }
                }
                .padding(.horizontal, -EdenMetric.sidebarInset)
            }
            .padding(.top, isFirst ? 0 : 2)
        }
    }
}

/// A backlog row: its category's tick, the title, and — under the pointer alone
/// — the two things it can do without leaving the list.
///
/// The tick is the category list's square rather than a dot, and it is not a
/// control: nothing in the backlog is done or not done yet, and a box that could
/// be ticked here would be answering the wrong question about it.
///
/// Clicking the row opens the task in this same column, the way clicking a block
/// does. Pulling it into the day is `+ Today`, and dragging it onto the grid
/// gives it a time on the way in.
struct BacklogRow: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState
    let task: JournalTask

    @State private var isHovering = false

    var body: some View {
        SidebarRow {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(DayPalette.color(journal.category(id: task.categoryID)))
                .frame(width: 9, height: 9)
            Text(task.title).lineLimit(1)
            Spacer(minLength: 0)
            // Both controls keep their slot while they are invisible, so the
            // title does not jump sideways as the pointer crosses the row.
            Button("+ Today") { journal.pullIntoDay(taskID: task.id) }
                .buttonStyle(.plain)
                .font(EdenFont.ui(12))
                .foregroundStyle(EdenColor.n400)
                .opacity(isHovering ? 1 : 0)
                .allowsHitTesting(isHovering)
                .help("Put this on the day you are looking at")
            RowEllipsisMenu(isShowing: isHovering, help: "Task options") { menu }
        }
        .onHover { isHovering = $0 }
        .onTapGesture { ui.select(taskID: task.id) }
        .contextMenu { menu }
        // Dropped on the hour grid it joins the day *and* takes that time.
        .draggable(task.id.uuidString) {
            Text(task.title)
                .font(EdenFont.ui(12))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(EdenColor.card, in: .capsule)
        }
    }

    /// Everything the row can do without opening the task — the same list
    /// right-clicking gives.
    @ViewBuilder
    private var menu: some View {
        Button("Add to Today") { journal.pullIntoDay(taskID: task.id) }
        Button("Open") { ui.select(taskID: task.id) }
        Divider()
        Button("Move to \(other.title)") { journal.setPriority(other, taskID: task.id) }
        Menu("Change category") {
            Button("None") { journal.setCategory(nil, taskID: task.id) }
            ForEach(journal.categories) { category in
                Button {
                    journal.setCategory(category.id, taskID: task.id)
                } label: {
                    Image(nsImage: DayPalette.swatch(
                        DayPalette.color(category),
                        isCurrent: task.categoryID == category.id
                    ))
                    Text(category.name)
                }
            }
        }
        Divider()
        // No confirmation: `tasks.jsonl` is append-only, so the row is still in
        // the file — the same bargain the detail pane's Delete task makes.
        Button("Delete task") {
            journal.deleteTask(id: task.id)
            if ui.selectedTaskID == task.id { ui.select(taskID: nil) }
        }
    }

    /// The priority the task is *not* — a menu offering the one it already has
    /// would be a no-op wearing a label.
    private var other: Priority { task.priority == .must ? .nice : .must }
}
