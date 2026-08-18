import DesignSystem
import PrincipleCore
import SwiftUI

/// One task on the grid: filled in its category's colour, strong for a Must and
/// a tint for a Nice-to (spec #5 rev 2).
///
/// Three gestures live on it and they must not fight. The bottom 6 pt resize
/// the block, the rest of it moves the block, and a press that never moves
/// opens the task in column 3 — which is why the tap is decided at the end of
/// the drag rather than by a separate `onTapGesture` that would race it.
struct TaskBlockView: View {
    let row: PlannedTask
    let schedule: TaskSchedule?
    let slot: DayGridLayout.Slot
    let laneWidth: CGFloat
    let isSelected: Bool
    let toggleDone: () -> Void
    let select: () -> Void
    let move: (CGFloat) -> Void
    let resize: (CGFloat) -> Void
    let commit: () -> Void

    var body: some View {
        if let schedule {
            let fill = TaskFill(row)
            let height = DayMetric.height(ofMinutes: schedule.durationMinutes)
            let width = max(0, laneWidth * slot.widthFraction - 8)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    TickBox(isOn: row.isDone, color: fill.foreground, action: toggleDone)
                    Text(row.title)
                        .font(EdenFont.ui(13, .medium))
                        .strikethrough(row.isDone)
                        .lineLimit(1)
                }
                if height >= DayMetric.timeLineThreshold {
                    Text(schedule.rangeLabel)
                        .font(EdenFont.ui(11))
                        .opacity(0.72)
                        .padding(.leading, 21)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(fill.foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(fill.background, in: .rect(cornerRadius: EdenRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: EdenRadius.sm, style: .continuous)
                    .strokeBorder(fill.border)
            }
            // Inside the block, never around it: the ring used to be drawn a
            // point outside its bounds, and `.clipped()` — which is what keeps a
            // long title from spilling out of a short block — took the outer
            // half of it off, corners first. `strokeBorder` insets by half the
            // line width on its own, so the whole ring lands on canvas that
            // belongs to the block.
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: EdenRadius.sm, style: .continuous)
                        .strokeBorder(EdenColor.primary80, lineWidth: 2)
                }
            }
            .opacity(row.isDone ? 0.55 : 1)
            .clipped()
            .contentShape(.rect)
            .gesture(moveGesture)
            .overlay(alignment: .bottom) { resizeHandle }
            .offset(
                x: laneWidth * slot.offsetFraction + 4,
                y: DayMetric.y(ofMinute: schedule.startMinute)
            )
        }
    }

    /// A press that never moved is a click: it opens the task rather than
    /// writing the same time back to disk.
    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard abs(value.translation.height) > 3 else { return }
                move(value.translation.height)
            }
            .onEnded { value in
                if abs(value.translation.height) <= 3 {
                    select()
                } else {
                    commit()
                }
            }
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: DayMetric.resizeHandleHeight)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { resize($0.translation.height) }
                    .onEnded { _ in commit() }
            )
            .onHover { hovering in
                if hovering { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
    }
}
