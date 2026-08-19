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
                    if ui.draft != nil {
                        NewTaskPane(journal: journal, ui: ui)
                    } else if let taskID = ui.selectedTaskID, journal.task(id: taskID) != nil {
                        TaskDetailPane(journal: journal, ui: ui, taskID: taskID)
                    } else {
                        BacklogPane(journal: journal, ui: ui)
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

    /// Apple Calendar's new event, not a row appearing in a list: a draft block
    /// shows up on the grid at the hour in the middle of it, an hour long, and
    /// this pane opens on its name. Nothing is in the journal yet (spec #22).
    private func newTask() {
        ui.startDraft(categoryID: journal.defaultCategoryID)
    }
}
