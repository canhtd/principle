import DesignSystem
import PrincipleCore
import SwiftUI

/// What sits under the tracks: the picked Category's Bar, then the tasks Danny
/// ticked for it that day (`docs/design/proto-review-B.html` v2).
///
/// Evidence only, and it says so by doing nothing: no height is derived from a
/// tick, and ticking one moves no Dot (stories 10 and 11). It is here to be
/// remembered by while the judgement is made, and for no other reason.
struct ReviewEvidence: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let category = picked {
                if let bar = category.bar { sentence(bar) }
                ticked(for: category)
            } else {
                // Nothing picked yet: one line, not an empty box.
                hint("Pick a category to see what you ticked for it \(dayWord).")
            }
        }
        .padding(.top, 14)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The track the pane is talking about — the one last touched. A category
    /// unticked or deleted since it was picked is no longer one of the tracks,
    /// and the pane goes back to asking for one rather than talking about a
    /// column that is not there.
    private var picked: JournalCategory? {
        journal.reviewCategories.first { $0.id == ui.reviewCategoryID }
    }

    /// The Bar, in full under the chart for the picked track — the tooltip on
    /// the track itself is the quiet version of the same sentence.
    private func sentence(_ bar: String) -> some View {
        Text(bar)
            .font(EdenFont.ui(11.5))
            .lineSpacing(11.5 * 0.45)
            .foregroundStyle(EdenColor.n400)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func ticked(for category: JournalCategory) -> some View {
        let rows = journal.evidence(for: category.id)
        if rows.isEmpty {
            hint("Nothing ticked for \(category.name) \(dayWord).")
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(EdenFont.ui(9, .medium))
                            .foregroundStyle(EdenColor.n400)
                        Text(row.title)
                            .font(EdenFont.ui(11.5))
                            .lineSpacing(11.5 * 0.4)
                            .foregroundStyle(EdenColor.hex(0x77746F))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(EdenFont.ui(12))
            .foregroundStyle(EdenColor.n400)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "today" only when it is: the pane is opened on older days as often as on
    /// this one, and a line that says "today" on 16 August is a small lie.
    private var dayWord: String { journal.isToday ? "today" : "on this day" }
}
