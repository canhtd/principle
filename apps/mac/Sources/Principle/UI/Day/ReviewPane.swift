import DesignSystem
import PrincipleCore
import SwiftUI

/// Column 3's other face: the day as one small chart, one vertical track per
/// Category (`docs/design/proto-review-B.html` v2).
///
/// The point of drawing it this way rather than as four rows is that it is the
/// shape Dalio draws — heights side by side, read at a glance. What each track
/// records is a judgement, not a count: nothing here is derived from the tasks,
/// and ticking one never moves a Dot.
///
/// Under the chart sit the picked track's Bar and what was ticked for it, and
/// under those the Day note — the second step of the review, in Danny's own
/// words (#15).
struct ReviewPane: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                PaneSectionLabel("Review your day")

                if tracks.isEmpty {
                    PaneNote("Every category is hidden.")
                } else {
                    chart
                    ReviewEvidence(journal: journal, ui: ui)
                }
            }
            .padding(.bottom, 20)

            // Always there, whatever the tracks are doing: a day with every
            // category hidden is still a day worth writing a line about.
            DayNoteField(journal: journal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The tracks stand on one baseline, so the hairline under them reads as a
    /// single axis rather than four separate rules.
    private var chart: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(tracks) { category in
                ReviewTrack(
                    journal: journal,
                    ui: ui,
                    category: category,
                    // The rightmost track has no room on its right, so its
                    // number sits on the dot's other side.
                    numberOnLeft: category.id == tracks.last?.id && tracks.count > 1
                )
            }
        }
        .padding(.top, 4)
    }

    /// What column 1 is showing. A track for a Category Danny has just unticked
    /// would be arguing with the tick he cleared (decision 3).
    private var tracks: [JournalCategory] { journal.reviewCategories }
}
