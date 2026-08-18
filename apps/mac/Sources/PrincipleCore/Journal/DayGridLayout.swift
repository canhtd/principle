import Foundation

/// Where each block sits sideways when two of them want the same hour.
///
/// Apple Calendar's rule, and the one people already read without being taught:
/// blocks that overlap share the width, and a block that overlaps nothing keeps
/// all of it. The unit is the *cluster* — a run of blocks connected by overlap —
/// because a column count taken over the whole day would make one busy morning
/// squeeze the entire afternoon.
///
/// Geometry only: no view, no points, no pixels. The grid multiplies these by
/// whatever width it has.
public struct DayGridLayout: Equatable, Sendable {
    /// Which column of its cluster a block is in, counting from the left.
    public struct Slot: Equatable, Sendable {
        public let column: Int
        /// How many columns its cluster ended up needing.
        public let columns: Int

        public init(column: Int, columns: Int) {
            self.column = column
            self.columns = columns
        }

        /// Fraction of the lane's width this block starts at.
        public var offsetFraction: Double { Double(column) / Double(columns) }
        public var widthFraction: Double { 1 / Double(columns) }
    }

    private let slots: [UUID: Slot]

    /// Blocks may arrive in any order; they are read in time order regardless.
    public init(_ rows: [PlannedTask]) {
        // Earliest first, and the longer of two that start together first —
        // which puts the block that spans the morning against the left edge,
        // where Calendar puts it and where the eye goes looking for it.
        let placed = rows.compactMap { row in row.schedule.map { (id: row.taskID, at: $0) } }
            .sorted {
                $0.at.startMinute != $1.at.startMinute
                    ? $0.at.startMinute < $1.at.startMinute
                    : $0.at.durationMinutes > $1.at.durationMinutes
            }

        var slots: [UUID: Slot] = [:]
        var cluster: [(id: UUID, column: Int)] = []
        /// When each open column becomes free again.
        var columnEnds: [Int] = []

        func closeCluster() {
            for member in cluster {
                slots[member.id] = Slot(column: member.column, columns: columnEnds.count)
            }
            cluster = []
            columnEnds = []
        }

        for block in placed {
            // A block starting at or after every open column's end belongs to a
            // new cluster: nothing it could share width with is still running.
            if let latest = columnEnds.max(), block.at.startMinute >= latest { closeCluster() }
            // Leftmost column that is free by the time this block starts, so a
            // gap in the middle of a cluster is reused rather than widening it.
            let column = columnEnds.firstIndex { $0 <= block.at.startMinute } ?? columnEnds.count
            if column == columnEnds.count { columnEnds.append(0) }
            columnEnds[column] = block.at.endMinute
            cluster.append((id: block.id, column: column))
        }
        closeCluster()

        self.slots = slots
    }

    /// Where a block goes. A row the layout never saw — one with no time — gets
    /// the whole width rather than nothing, so a caller that mixes the two lists
    /// draws something rather than collapsing it.
    public func slot(for taskID: UUID) -> Slot {
        slots[taskID] ?? Slot(column: 0, columns: 1)
    }
}
