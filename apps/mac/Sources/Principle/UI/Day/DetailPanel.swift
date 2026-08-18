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

    private var dateNavigation: some View {
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
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 9)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { EdenColor.black(6).frame(height: 1) }
    }
}

/// What the day could still take on. Clicking one pulls it into the all-day
/// strip — when it runs is a separate decision from whether it is happening.
struct SuggestionsPane: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Suggested from backlog")
                .font(EdenFont.ui(12))
                .foregroundStyle(EdenColor.hex(0x77746F))

            if journal.suggestions.isEmpty {
                Text("Backlog is empty.")
                    .font(EdenFont.ui(12))
                    .foregroundStyle(EdenColor.n400)
                    .padding(.leading, EdenMetric.sidebarInset)
            } else {
                ForEach(journal.suggestions) { task in
                    row(task)
                }
                .padding(.horizontal, -EdenMetric.sidebarInset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// A backlog row: a dot in its category's colour, the title, and a `+ Today`
/// that only shows up under the pointer.
struct SuggestionRow: View {
    let title: String
    let color: Color
    let pull: () -> Void

    @State private var isHovering = false

    var body: some View {
        SidebarRow {
            Circle().fill(color).frame(width: 7, height: 7)
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
