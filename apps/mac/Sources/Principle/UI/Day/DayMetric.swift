import DesignSystem
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

    /// Column 3. Column 1 is Eden's own sidebar width (`EdenMetric.sidebarWidth`).
    static let detailWidth: CGFloat = 320

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

    /// Below this the header takes the short date and drops the subtitle.
    static let narrowHeader: CGFloat = 1200
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
