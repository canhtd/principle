import DesignSystem
import PrincipleCore
import SwiftUI

/// Column 2 — the bare canvas, not a panel. The day itself: what has a time and
/// what does not.
struct DayColumn: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState
    let now: Date
    let isHeaderNarrow: Bool
    let showsSidebarToggle: Bool
    let showsDetailToggle: Bool

    var body: some View {
        VStack(spacing: 0) {
            DayHeader(
                journal: journal,
                ui: ui,
                isNarrow: isHeaderNarrow,
                showsSidebarToggle: showsSidebarToggle,
                showsDetailToggle: showsDetailToggle
            )
            if ui.axis == .day {
                AllDayStrip(journal: journal, ui: ui)
                HourGrid(journal: journal, ui: ui, now: now)
            } else {
                comingLater
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Week and Month are #9. The control is still shown, because it is how the
    /// app says it has a time axis at all — but it says plainly that there is
    /// nothing behind it yet rather than opening an empty grid.
    private var comingLater: some View {
        VStack(spacing: 6) {
            Text("\(ui.axis.title) view")
                .font(EdenFont.ui(15, .medium))
                .foregroundStyle(EdenColor.hex(0x77746F))
            Text("Coming later.")
                .font(EdenFont.ui(13))
                .foregroundStyle(EdenColor.n400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
