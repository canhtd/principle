import DesignSystem
import PrincipleCore
import SwiftUI

/// Tasks with no time yet, as chips above the grid.
///
/// Same fill as a block (``TaskFill``), so dragging one onto the grid changes
/// where it is and nothing else about how it looks. Dropping is the grid's half
/// of the deal — see ``HourGrid``.
struct AllDayStrip: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("all-day")
                .font(EdenFont.ui(11))
                .foregroundStyle(EdenColor.n400)
                .frame(width: DayMetric.gutter - 8, alignment: .trailing)
                .padding(.top, 9)
                .padding(.trailing, 8)

            if journal.untimed.isEmpty {
                Text("Nothing without a time.")
                    .font(EdenFont.ui(12))
                    .foregroundStyle(EdenColor.n400)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                WrapLayout {
                    ForEach(journal.untimed) { row in
                        chip(row)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: 40)
        .background(EdenColor.canvas)
        .overlay(alignment: .top) { EdenColor.black(10).frame(height: 1) }
        .overlay(alignment: .bottom) { EdenColor.black(10).frame(height: 1) }
    }

    private func chip(_ row: PlannedTask) -> some View {
        let fill = TaskFill(row)
        return HStack(spacing: 6) {
            TickBox(isOn: row.isDone, color: fill.foreground) {
                journal.setDone(!row.isDone, taskID: row.taskID)
            }
            Text(row.title)
                .font(EdenFont.ui(12))
                .strikethrough(row.isDone)
                .lineLimit(1)
        }
        .foregroundStyle(fill.foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .frame(maxWidth: 250, alignment: .leading)
        .fixedSize()
        .background(fill.background, in: .capsule)
        .overlay(Capsule().strokeBorder(fill.border))
        .opacity(row.isDone ? 0.55 : 1)
        .contentShape(.capsule)
        .onTapGesture { ui.select(taskID: row.taskID) }
        // Dropping it on the grid is what gives it a time.
        .draggable(row.taskID.uuidString) {
            Text(row.title)
                .font(EdenFont.ui(12))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(fill.background, in: .capsule)
        }
    }
}
