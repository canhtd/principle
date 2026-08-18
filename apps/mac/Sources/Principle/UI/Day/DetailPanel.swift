import DesignSystem
import PrincipleCore
import SwiftUI

/// Column 3: ‹ Today › on top (decision 6), and under it either the task that
/// is selected or what the day could still take from the backlog.
///
/// The dots, "Order the day" and "Close day" belong here too — they are #8, and
/// deliberately not built yet.
struct DetailPanel: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState

    var body: some View {
        VStack(spacing: 0) {
            dateNavigation
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let taskID = ui.selectedTaskID, journal.task(id: taskID) != nil {
                        TaskDetailPane(journal: journal, ui: ui, taskID: taskID)
                    } else {
                        SuggestionsPane(journal: journal, ui: ui)
                    }
                }
                .padding(.horizontal, EdenMetric.sidebarPadding)
                .padding(.vertical, EdenMetric.libraryPaddingTop - 4)
            }
            .scrollIndicators(.never)
        }
    }

    /// ‹ Today › stays centred on the column whatever sits beside it, so the
    /// "+" is laid over the row rather than taking a cell in it.
    private var dateNavigation: some View {
        ZStack {
            HStack(spacing: 2) {
                EdenIconButton(systemImage: "chevron.left", help: "Previous day", size: 26) {
                    journal.shiftDay(by: -1)
                }
                Button("Today") { journal.showToday() }
                    .buttonStyle(EdenGhostButtonStyle())
                EdenIconButton(systemImage: "chevron.right", help: "Next day", size: 26) {
                    journal.shiftDay(by: 1)
                }
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                EdenIconButton(systemImage: "plus", help: "New task on this day", size: 26, action: newTask)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 9)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { EdenColor.black(6).frame(height: 1) }
    }

    /// The same path the grid's drag takes, minus the time: the task lands in
    /// the all-day strip and opens here with its title under the caret.
    private func newTask() {
        guard let id = journal.createTask() else { return }
        ui.select(taskID: id, focusingTitle: true)
    }
}

/// The backlog: what the day could still take on, in the two groups it is read
/// in — what must happen, then what would be nice to. Clicking one pulls it into
/// the all-day strip; when it runs is a separate decision from whether it is
/// happening.
///
/// A group with nothing in it is not drawn at all. An empty heading is a
/// promise the list is not keeping.
struct SuggestionsPane: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Backlog")
                .font(EdenFont.ui(12))
                .foregroundStyle(EdenColor.hex(0x77746F))

            if journal.suggestions.isEmpty {
                Text("Nothing in the backlog.")
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        row(task)
                    }
                }
                .padding(.horizontal, -EdenMetric.sidebarInset)
            }
            .padding(.top, isFirst ? 0 : 2)
        }
    }

    private func row(_ task: JournalTask) -> some View {
        SuggestionRow(
            title: task.title,
            color: DayPalette.color(journal.category(id: task.categoryID))
        ) {
            journal.pullIntoDay(taskID: task.id)
        }
    }
}

/// A backlog row: its category's tick, the title, and a `+ Today` that only
/// shows up under the pointer.
///
/// The tick is the category list's square rather than a dot, and it is not a
/// control: nothing in the backlog is done or not done yet, and a box that can
/// be ticked here would be offering the wrong answer to "what about this one?".
struct SuggestionRow: View {
    let title: String
    let color: Color
    let pull: () -> Void

    @State private var isHovering = false

    var body: some View {
        SidebarRow {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title).lineLimit(1)
            Spacer(minLength: 0)
            Text("+ Today")
                .font(EdenFont.ui(12))
                .foregroundStyle(EdenColor.n400)
                .opacity(isHovering ? 1 : 0)
        }
        .onHover { isHovering = $0 }
        .onTapGesture(perform: pull)
    }
}
