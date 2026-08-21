import DesignSystem
import PrincipleCore
import SwiftUI

/// The geometry that is this screen's rather than the design system's.
///
/// `DesignSystem` owns what every app of Danny's shares — panel widths, row
/// heights, radii. An hour is 52 points because that is the density Apple
/// Calendar reads at, which is a fact about *this* screen and belongs here, not
/// in a package VessaStudio also depends on.
enum DayMetric {
    /// Points per hour on the grid. Apple Calendar's density: a 30-minute block
    /// is still tall enough to hold its title.
    static let hourHeight: CGFloat = 52
    /// The hour-label gutter down the left of the grid.
    static let gutter: CGFloat = 56
    static let dayHeight = hourHeight * 24

    /// Where the two side panels open before anybody has dragged them (#18).
    /// Both are remembered from launch to launch, and the bounds they drag
    /// between belong to ``PanelWidths`` — the library, where they are tested.
    static let defaultWidths = PanelWidths(
        // Eden's own sidebar width. `PanelWidths` repeats the number for the
        // library's sake; this line is what keeps the two from drifting.
        sidebar: EdenMetric.sidebarWidth,
        detail: PanelWidths.detailDefault
    )

    // MARK: The dividers (#18)

    /// What column 2 keeps for itself however wide the panels are dragged. The
    /// day is the point of the screen; a grid squeezed to a gutter is not.
    ///
    /// 360 rather than a rounder number because of the breakpoint below it: at
    /// 1100 pt, the width where column 3 first docks, the canvas margins, the
    /// two divider gaps and the two default widths (4 × 8 + 260 + 420) leave the
    /// day 388 pt. A floor greedier than that would make the app open a squeezed
    /// column 3 on a laptop screen; 360 sits just under it, and the 28 pt of
    /// slack goes to the day.
    static let dayColumnMinimum: CGFloat = 360
    /// The grab area, a little wider than the 8 pt gap it fills — two points of
    /// overhang on each side (``PanelDivider``).
    static let dividerGrab: CGFloat = 12
    /// How tall the bookmarks may grow at the foot of column 3 while Ask Ray is
    /// docked in it: about five rows and their heading. Past that they scroll,
    /// rather than pushing the thread off the screen (``AskRayColumn``).
    static let chatColumnBookmarks: CGFloat = 190

    /// Where the grid opens: the morning, like Calendar, rather than midnight.
    static let firstVisibleHour: CGFloat = 6
    /// Room above midnight for the `00` label, which is drawn above its line.
    static let topInset: CGFloat = 8

    /// The shortest block that can still show its title — anything smaller is
    /// drawn as a bar and read from the detail pane.
    static let minimumBlockHeight: CGFloat = 16
    /// A block taller than this has room for its time under the title.
    static let timeLineThreshold: CGFloat = 34
    /// The grab strip along a block's bottom edge.
    static let resizeHandleHeight: CGFloat = 6

    // MARK: Breakpoints (decision 10)

    /// Below this *column 2* takes the short date and drops the subtitle.
    ///
    /// The column's width, not the window's (#18): the panels beside it are
    /// draggable now, so a wide window with a wide sidebar leaves exactly the
    /// header a narrow window used to. 640 is where the long date — "Wednesday,
    /// 30 September" — stops clearing the centred Day / Week / Month control.
    static let narrowHeaderColumn: CGFloat = 640
    /// Below this column 3 becomes a drawer.
    static let detailDrawer: CGFloat = 1100
    /// Below this column 1 does too.
    static let sidebarDrawer: CGFloat = 900

    // MARK: The floating chat

    static let chatWidth: CGFloat = 380
    static let chatHeight: CGFloat = 520
    /// A short window gets a shorter panel rather than one running off the top.
    static let chatShortHeight: CGFloat = 420
    static let chatShortWindow: CGFloat = 700
    /// The bubble sits on the window's margin, flush with the panel inset.
    static let chatMargin: CGFloat = 20
    static let bubbleSize: CGFloat = 44

    // MARK: Geometry

    /// Where a minute of the day falls on the grid.
    static func y(ofMinute minute: Int) -> CGFloat {
        CGFloat(minute) / 60 * hourHeight
    }

    /// Which minute a point on the grid is, unsnapped.
    static func minute(atY y: CGFloat) -> Int {
        Int((y / hourHeight * 60).rounded())
    }

    /// How tall a block of `duration` minutes is drawn, leaving the hairline of
    /// canvas that keeps two back-to-back blocks from reading as one.
    static func height(ofMinutes duration: Int) -> CGFloat {
        max(minimumBlockHeight, y(ofMinute: duration) - 2)
    }
}
