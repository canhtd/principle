import DesignSystem
import PrincipleCore
import SwiftUI

/// The day, 00:00 to 24:00, at Apple Calendar's density.
///
/// The whole day is drawn rather than a working window: a run at 06:00 and a
/// dinner at 21:00 are both real, and a grid that hides them teaches you not to
/// trust it. It scrolls inside column 2 and opens on the morning.
struct HourGrid: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState
    let now: Date

    /// The drag in progress, if any. Held here rather than per block, because a
    /// drag that starts on a block and ends on empty canvas is still one drag.
    @State private var draft: GridDraft?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // The hours are a real stack rather than 25 offset overlays: an
                // `.offset` leaves a view's layout position at zero, and a
                // scroll view can only be sent to a position that layout knows
                // about. Blocks are still placed by offset, on top.
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        HourRow(hour: hour).id(HourAnchor.id(hour: hour))
                    }
                    EdenColor.black(7).frame(height: 1)
                }
                .overlay {
                    GeometryReader { geometry in
                        lane(width: max(0, geometry.size.width - DayMetric.gutter))
                            .offset(x: DayMetric.gutter)
                        if journal.isToday { nowLine }
                    }
                }
                .padding(.top, DayMetric.topInset)
            }
            .scrollIndicators(.automatic)
            .onAppear {
                // Opens on the morning, the way Calendar does, rather than on a
                // midnight nothing happens at.
                proxy.scrollTo(HourAnchor.id(hour: Int(DayMetric.firstVisibleHour)), anchor: .top)
            }
        }
    }

    /// One hour: the line it starts on and the number in the gutter.
    private struct HourRow: View {
        let hour: Int

        var body: some View {
            ZStack(alignment: .topLeading) {
                EdenColor.black(7).frame(height: 1)
                Text(String(format: "%02d", hour))
                    .font(EdenFont.ui(11))
                    .foregroundStyle(EdenColor.n400)
                    .frame(width: DayMetric.gutter - 10, alignment: .trailing)
                    .offset(y: -6)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: DayMetric.hourHeight)
        }
    }

    /// Everything right of the gutter: the blocks, the ghost a drag leaves, and
    /// the empty canvas a new task is dragged out of.
    private func lane(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            EdenColor.black(7).frame(width: 1)

            Color.clear
                .contentShape(.rect)
                .gesture(createGesture)

            let layout = DayGridLayout(journal.timed)
            ForEach(journal.timed) { row in
                TaskBlockView(
                    row: row,
                    schedule: schedule(for: row),
                    slot: layout.slot(for: row.taskID),
                    laneWidth: width,
                    isSelected: ui.selectedTaskID == row.taskID,
                    toggleDone: { journal.setDone(!row.isDone, taskID: row.taskID) },
                    select: { ui.select(taskID: row.taskID) },
                    move: { move(row, by: $0) },
                    resize: { resize(row, by: $0) },
                    commit: commit
                )
            }

            if let ghost = draft?.ghost {
                GhostBlock(schedule: ghost)
                    .frame(width: max(0, width - 8))
                    .offset(x: 4, y: DayMetric.y(ofMinute: ghost.startMinute))
            }
        }
        .frame(width: width, height: DayMetric.dayHeight, alignment: .topLeading)
        // An all-day chip dragged down here gets the time it was dropped at.
        .dropDestination(for: String.self) { items, location in
            guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
            journal.schedule(taskID: id, startingAt: TaskSchedule.snap(DayMetric.minute(atY: location.y)))
            return true
        }
    }

    private var nowLine: some View {
        let minute = Calendar.current.component(.hour, from: now) * 60
            + Calendar.current.component(.minute, from: now)
        return ZStack(alignment: .leading) {
            DayPalette.now.frame(height: 1.5)
            Circle().fill(DayPalette.now).frame(width: 8, height: 8)
        }
        .padding(.leading, DayMetric.gutter - 10)
        .offset(y: DayMetric.y(ofMinute: minute))
        .allowsHitTesting(false)
    }

    // MARK: - Dragging

    /// Dragging on empty canvas draws a new block out of it (decision 11: every
    /// edge lands on a quarter hour).
    private var createGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                draft = .creating(
                    from: TaskSchedule.snap(DayMetric.minute(atY: value.startLocation.y)),
                    to: TaskSchedule.snap(DayMetric.minute(atY: value.location.y))
                )
            }
            .onEnded { _ in
                if let schedule = draft?.ghost, let id = journal.createTask(at: schedule) {
                    // Straight into column 3: a block called "New task" is only
                    // useful if it can be named without hunting for it.
                    ui.select(taskID: id)
                }
                draft = nil
            }
    }

    private func move(_ row: PlannedTask, by offset: CGFloat) {
        guard let schedule = row.schedule else { return }
        let moved = schedule.starting(at: TaskSchedule.snap(schedule.startMinute + DayMetric.minute(atY: offset)))
        draft = .adjusting(taskID: row.taskID, schedule: moved)
    }

    private func resize(_ row: PlannedTask, by offset: CGFloat) {
        guard let schedule = row.schedule else { return }
        let resized = schedule.ending(at: TaskSchedule.snap(schedule.endMinute + DayMetric.minute(atY: offset)))
        draft = .adjusting(taskID: row.taskID, schedule: resized)
    }

    /// One write at the end of the drag, not one per frame: every intermediate
    /// position would otherwise be a line in `tasks.jsonl`.
    private func commit() {
        if case .adjusting(let taskID, let schedule) = draft {
            journal.setSchedule(schedule, taskID: taskID)
        }
        draft = nil
    }

    /// What a block should be drawn at right now — the drag in progress if it is
    /// the one being dragged, otherwise what is on disk.
    private func schedule(for row: PlannedTask) -> TaskSchedule? {
        if case .adjusting(let taskID, let schedule) = draft, taskID == row.taskID { return schedule }
        return row.schedule
    }
}

/// The two things a drag on the grid can be.
enum GridDraft {
    case creating(from: Int, to: Int)
    case adjusting(taskID: UUID, schedule: TaskSchedule)

    /// The dashed outline the drag leaves behind, or `nil` while a block is
    /// simply following the pointer.
    var ghost: TaskSchedule? {
        guard case .creating(let from, let to) = self else { return nil }
        return TaskSchedule(startMinute: min(from, to), durationMinutes: max(abs(to - from), TaskSchedule.slotMinutes))
    }
}

/// Anchors the scroll view can be sent to.
enum HourAnchor {
    static func id(hour: Int) -> String { "hour-\(hour)" }
}

/// The outline a create-drag leaves while the pointer is still down.
struct GhostBlock: View {
    let schedule: TaskSchedule

    var body: some View {
        RoundedRectangle(cornerRadius: EdenRadius.sm, style: .continuous)
            .fill(EdenColor.primary80.opacity(0.14))
            .overlay {
                RoundedRectangle(cornerRadius: EdenRadius.sm, style: .continuous)
                    .strokeBorder(EdenColor.primary80, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .frame(height: DayMetric.height(ofMinutes: schedule.durationMinutes))
            .allowsHitTesting(false)
    }
}
