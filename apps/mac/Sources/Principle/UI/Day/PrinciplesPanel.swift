import DesignSystem
import PrincipleCore
import SwiftUI

/// The bookmark face of column 1 (decision 4): the principle of the day on top,
/// then the favourited ones grouped by which book they are from.
///
/// All three group labels are the same Eden section header in sentence case —
/// the uppercase small caps belong to the card's own `LIFE PRINCIPLE 5.3` label,
/// and having both would be two kinds of heading doing one job.
///
/// Not an inbox and not a backlog — the backlog appears only as column 3's
/// "Suggested from backlog".
struct PrinciplesPanel: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState
    let favorites: FavoritesModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SidebarSectionHeader(title: "Principle of the day")
                if let principle = principleOfTheDay {
                    PrincipleCardSmall(record: principle, favorites: favorites, ui: ui)
                        .padding(.horizontal, EdenMetric.sidebarPadding)
                        .padding(.bottom, 4)
                } else {
                    note("No corpus in this repo yet.")
                }

                group("Life principles", records: favourites(kind: "life"))
                group("Work principles", records: favourites(kind: "work"))
                if favorites.isEmpty {
                    note("No favourites yet. Bookmark a principle to keep it here.")
                }
            }
            .padding(.bottom, EdenMetric.sidebarPadding)
        }
        .scrollIndicators(.never)
        .onAppear(perform: favorites.refresh)
    }

    @ViewBuilder
    private func group(_ label: String, records: [PrincipleRecord]) -> some View {
        if !records.isEmpty {
            SidebarSectionHeader(title: label)
            VStack(spacing: 2) {
                ForEach(records) { record in
                    principleRow(record)
                }
            }
            .padding(.horizontal, EdenMetric.sidebarPadding)
        }
    }

    private func principleRow(_ record: PrincipleRecord) -> some View {
        SidebarRow(isSelected: ui.openPrincipleID == record.id) {
            Text(record.num)
                .font(EdenFont.ui(12).monospacedDigit())
                .foregroundStyle(EdenColor.n400)
            Text(record.title)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .onTapGesture { ui.openPrincipleID = record.id }
        .principleExcerpt(record: record, favorites: favorites, ui: ui)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(EdenFont.ui(12))
            .foregroundStyle(EdenColor.n400)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, EdenMetric.sidebarPadding + EdenMetric.sidebarInset)
            .padding(.vertical, 6)
    }

    /// Rotates deterministically by date through the corpus — the same day gives
    /// the same principle, without anything being stored.
    private var principleOfTheDay: PrincipleRecord? {
        PrincipleOfTheDay.principle(
            on: JournalDay(journal.day, calendar: Calendar.current),
            in: favorites.corpus
        )
    }

    /// Saved principles from one of the two books, newest save first. An id the
    /// corpus cannot resolve produces no row — the app never invents one.
    private func favourites(kind: String) -> [PrincipleRecord] {
        favorites.records.filter { $0.id.hasPrefix("\(kind):") }
    }
}
