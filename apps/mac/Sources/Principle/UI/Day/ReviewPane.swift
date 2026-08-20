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
/// The Category's Bar, the evidence list and the Day note belong under this and
/// are #15; the space they take is left rather than filled with something else.
struct ReviewPane: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Review your day")
                .font(EdenFont.ui(12))
                .foregroundStyle(EdenColor.hex(0x77746F))

            if tracks.isEmpty {
                Text("Every category is hidden.")
                    .font(EdenFont.ui(12))
                    .foregroundStyle(EdenColor.n400)
                    .padding(.leading, EdenMetric.sidebarInset)
            } else {
                chart
            }
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
