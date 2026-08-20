import DesignSystem
import PrincipleCore
import SwiftUI

/// Column 3: ‹ Today › on top (decision 6), and under it three sections —
/// the principle of the day, the pane, and the bookmarks (#18, spec #14 Rev 6).
///
/// The pane is one of four things: a task being written, the task that is
/// selected, the day being reviewed, or what the day could still take from the
/// backlog. It shows one at a time on purpose: each of them wants the whole
/// width, and the header's own word for what is up ("Review" / "Backlog") can
/// only stay true if there is one answer to give.
///
/// What is above and below it does not change with it. The principle opens the
/// column on every day and in every mode, and the bookmarks close it — the two
/// fixed ends are what make this a place Danny reads rather than a pane that
/// keeps rearranging itself.
struct DetailPanel: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState
    let favorites: FavoritesModel

    var body: some View {
        VStack(spacing: 0) {
            dateNavigation
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PrincipleOfTheDaySection(journal: journal, favorites: favorites, ui: ui)
                    pane
                    BookmarksSection(ui: ui, favorites: favorites)
                }
                .padding(.horizontal, EdenMetric.sidebarPadding)
                .padding(.vertical, EdenMetric.libraryPaddingTop - 4)
            }
            .scrollIndicators(.never)
        }
    }

    @ViewBuilder
    private var pane: some View {
        if ui.draft != nil {
            NewTaskPane(journal: journal, ui: ui)
        } else if let taskID = ui.selectedTaskID, journal.task(id: taskID) != nil {
            TaskDetailPane(journal: journal, ui: ui, taskID: taskID)
        } else if ui.isReviewing {
            ReviewPane(journal: journal, ui: ui)
        } else {
            BacklogPane(journal: journal, ui: ui)
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
                reviewToggle
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

    /// The way into the review, in the header's free left cell — always there
    /// rather than after five o'clock, because an older day is reviewed from
    /// the same spot and a control that only appears in the evening is one
    /// Danny has to find again. The same word is the way back.
    private var reviewToggle: some View {
        Button(ui.isReviewing ? "Backlog" : "Review") { ui.toggleReview() }
            .buttonStyle(EdenGhostButtonStyle())
            .help(ui.isReviewing ? "Back to the backlog" : "Review your day")
    }

    /// Apple Calendar's new event, not a row appearing in a list: a draft block
    /// shows up on the grid at the hour in the middle of it, an hour long, and
    /// this pane opens on its name. Nothing is in the journal yet (spec #22).
    private func newTask() {
        ui.startDraft(categoryID: journal.defaultCategoryID)
    }
}
