import DesignSystem
import PrincipleCore
import SwiftUI

/// Column 3's first section (#18): the day's principle, above whatever pane is
/// up, on every day and in every mode.
///
/// It used to live behind the sidebar's second face, where it was only there if
/// you went looking for it. A principle you have to click twice to see is one
/// you do not read — so it opens the column instead, which is the one place on
/// this screen the eye already goes.
struct PrincipleOfTheDaySection: View {
    @Bindable var journal: JournalModel
    let favorites: FavoritesModel
    @Bindable var ui: DayShellState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            PaneSectionLabel("Principle of the day")
            if let principle = principleOfTheDay {
                PrincipleCardSmall(record: principle, favorites: favorites, ui: ui)
            } else {
                PaneNote("No corpus in this repo yet.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Rotates deterministically by date through the corpus — the same day gives
    /// the same principle, without anything being stored.
    private var principleOfTheDay: PrincipleRecord? {
        PrincipleOfTheDay.principle(
            on: JournalDay(journal.day, calendar: Calendar.current),
            in: favorites.corpus
        )
    }
}
