import CoreGraphics
import Foundation

/// Where the two side panels and the day land in a window of a given width, and
/// where a drag on either divider lands (#18).
///
/// The shell owns the numbers — Eden's canvas gap, the day's floor — and this
/// owns what to do with them. It is in the library rather than beside the view
/// for the reason ``PanelWidths`` is: a divider with a dead zone in it is
/// arithmetic gone wrong, and arithmetic is worth a test rather than a hand on a
/// trackpad. The dead zone was real — a drag that began at the *stored* width
/// while the divider was drawn at the *fitted* one ignored the first 233 pt of
/// the hand's travel in a 1200 pt window.
public struct PanelLayout: Equatable, Sendable {
    /// Which of the two dividers a drag is on.
    public enum Edge: Sendable, Equatable {
        case sidebar
        case detail
    }

    public let windowWidth: CGFloat
    public let widths: PanelWidths
    /// The canvas gap between two columns. The divider *is* that gap.
    public let gap: CGFloat
    /// What column 2 keeps for itself however wide the panels are dragged.
    public let dayMinimum: CGFloat
    public let docksSidebar: Bool
    public let docksDetail: Bool

    public init(
        windowWidth: CGFloat,
        widths: PanelWidths,
        gap: CGFloat,
        dayMinimum: CGFloat,
        docksSidebar: Bool,
        docksDetail: Bool
    ) {
        self.windowWidth = windowWidth
        self.widths = widths
        self.gap = gap
        self.dayMinimum = dayMinimum
        self.docksSidebar = docksSidebar
        self.docksDetail = docksDetail
    }

    /// The room the docked panels may share, once the canvas has had its
    /// margins, each divider its gap, and column 2 its floor.
    public var room: CGFloat {
        let gaps = (docksSidebar ? 1 : 0) + (docksDetail ? 1 : 0)
        return windowWidth - gap * CGFloat(2 + gaps) - dayMinimum
    }

    /// The widths the panels are actually *drawn* at.
    ///
    /// A window that shrank under the two stored widths draws them narrower — it
    /// does not overwrite them. Widen the window again and the widths Danny
    /// chose come back, which is what every Mac app does with a split.
    public var shown: PanelWidths {
        guard docksSidebar, docksDetail else {
            // One of the two is a drawer: it overlays the day rather than
            // taking width from it, so only the docked one is held to the room.
            return PanelWidths(
                sidebar: docksSidebar
                    ? PanelWidths.clamp(widths.sidebar, to: PanelWidths.sidebarLimits, room: room)
                    : widths.sidebar,
                detail: docksDetail
                    ? PanelWidths.clamp(widths.detail, to: PanelWidths.detailLimits, room: room)
                    : widths.detail
            )
        }
        return widths.fitted(into: room)
    }

    /// What column 2 is left with — the width its header has to fit in, which is
    /// its own column rather than the window (#18).
    public var dayWidth: CGFloat {
        let shown = shown
        return room + dayMinimum
            - (docksSidebar ? shown.sidebar : 0)
            - (docksDetail ? shown.detail : 0)
    }

    /// The width a drag starts from: the one the divider is *drawn* at, never
    /// the stored one. They differ whenever the window is too narrow for both
    /// stored widths, and starting from the stored one is exactly the dead zone
    /// this type exists to keep out.
    func dragStart(_ edge: Edge) -> CGFloat {
        let shown = shown
        switch edge {
        case .sidebar: return shown.sidebar
        case .detail: return shown.detail
        }
    }

    /// One drag, from the mouse going down to the mouse coming up.
    ///
    /// It exists to hold the layout *still*. Every width this reports is
    /// measured against the row as it stood when the hand pressed down, never
    /// against the row the drag has been redrawing underneath itself — and it
    /// is a type rather than a convention because a convention is exactly what
    /// the last version got wrong.
    ///
    /// What went wrong: the sidebar's ceiling is the room column 3 leaves, and
    /// column 3 is re-fitted wider every time the sidebar narrows. Recomputed
    /// per frame, each frame's output became the next frame's ceiling, so the
    /// sidebar ratcheted down and could not come back — and what it had
    /// ratcheted to is what got written to disk. Held to the frame it started
    /// from, a drag out and back lands exactly where it began.
    public struct Drag: Equatable, Sendable {
        /// The row as it stood when the hand went down. Frozen on purpose.
        public let layout: PanelLayout
        public let edge: Edge
        /// The width the divider was *drawn* at, which is where the hand took
        /// hold of it.
        public let start: CGFloat

        public init(_ layout: PanelLayout, edge: Edge) {
            self.layout = layout
            self.edge = edge
            self.start = layout.dragStart(edge)
        }

        /// Where the divider is now, `dx` points from where it was grabbed.
        public func width(movedBy dx: CGFloat) -> CGFloat {
            layout.dragged(edge, from: start, by: dx)
        }

        /// The stored pair the drag began from — what to put back when the hand
        /// comes up having gone nowhere, so memory and disk still agree.
        public var widthsAtStart: PanelWidths { layout.widths }
    }

    /// Takes hold of one divider: everything the gesture needs, frozen now.
    public func drag(_ edge: Edge) -> Drag { Drag(self, edge: edge) }

    /// Where a divider that began at `start` has been dragged to, `dx` points
    /// sideways from where the hand pressed down.
    ///
    /// Held to the panel's own bounds and to the room the other panel leaves —
    /// neither may take the day below its floor. Call it through ``Drag``
    /// rather than directly: a caller that re-reads this off a layout rebuilt
    /// mid-gesture is the ratchet described there.
    func dragged(_ edge: Edge, from start: CGFloat, by dx: CGFloat) -> CGFloat {
        let shown = shown
        switch edge {
        case .sidebar:
            return PanelWidths.clamp(
                start + dx,
                to: PanelWidths.sidebarLimits,
                room: docksDetail ? room - shown.detail : room
            )
        case .detail:
            // The divider is on column 3's *left*, so the pointer moving left is
            // the column getting wider.
            return PanelWidths.clamp(
                start - dx,
                to: PanelWidths.detailLimits,
                room: docksSidebar ? room - shown.sidebar : room
            )
        }
    }
}
