import CoreGraphics
import Foundation
import Testing

@testable import PrincipleCore

/// Dragging one divider: where the drag starts from, where it lands, and what
/// it must not do to the pair on disk on the way (#18 and its two reviews).
///
/// Split from ``PanelLayoutTests`` — same numbers, same helper — because the
/// drag is where both blocking bugs of this ticket lived and it earns a file.
@Suite("Panel drag")
struct PanelDragTests {
    private static let gap: CGFloat = 8
    private static let dayMinimum: CGFloat = 360

    private func layout(
        width: CGFloat,
        sidebar: CGFloat = PanelWidths.sidebarDefault,
        detail: CGFloat = PanelWidths.detailDefault,
        docksSidebar: Bool = true,
        docksDetail: Bool = true
    ) -> PanelLayout {
        PanelLayout(
            windowWidth: width,
            widths: PanelWidths(sidebar: sidebar, detail: detail),
            gap: Self.gap,
            dayMinimum: Self.dayMinimum,
            docksSidebar: docksSidebar,
            docksDetail: docksDetail
        )
    }

    // MARK: - 3. The drag (the dead zone, #18 review)

    @Test("A drag starts from the width the divider is drawn at, not the stored one")
    func dragStartsWhereTheDividerIs() {
        let tight = layout(width: 1_200, sidebar: 420, detail: 620)

        // The bug: starting from 620 while the divider sat at 388 ate the first
        // 232 pt of every drag.
        #expect(tight.dragStart(.detail) == 388)
        #expect(tight.dragStart(.detail) != tight.widths.detail)
        #expect(tight.dragStart(.sidebar) == 420)
    }

    @Test("The first point of travel moves the panel — there is no dead zone")
    func aSinglePointMovesIt() {
        let tight = layout(width: 1_200, sidebar: 420, detail: 620)
        let start = tight.dragStart(.detail)

        // Column 3's divider is on its left: the pointer moving right narrows it.
        #expect(tight.dragged(.detail, from: start, by: 1) == start - 1)
        #expect(tight.dragged(.detail, from: start, by: 40) == start - 40)

        let roomy = layout(width: 1_600, sidebar: 260, detail: 420)
        let sidebarStart = roomy.dragStart(.sidebar)
        #expect(roomy.dragged(.sidebar, from: sidebarStart, by: 1) == sidebarStart + 1)
        #expect(roomy.dragged(.sidebar, from: sidebarStart, by: -1) == sidebarStart - 1)
    }

    @Test("A press that never moved lands exactly where it started")
    func aClickChangesNothing() {
        for width in [1_200, 1_600] as [CGFloat] {
            let shell = layout(width: width, sidebar: 420, detail: 620)
            for edge in [PanelLayout.Edge.sidebar, .detail] {
                let start = shell.dragStart(edge)
                #expect(shell.dragged(edge, from: start, by: 0) == start)
            }
        }
    }

    // MARK: - 3a. The drag holds the row still (#18 re-review)

    /// The frames a hand makes going 50 pt left and coming back: the exact
    /// sequence the ratchet was found with.
    private static let outAndBack: [CGFloat] = [-10, -30, -50, -30, 0]

    @Test("A drag out and back lands exactly where it started")
    func theSidebarComesBackToWhereItStarted() {
        // 1200 pt with both widths stored at more than fits: room is 808, so
        // the pair is DRAWN (260, 548) while (260, 620) is what is on disk.
        // This is the configuration the sidebar used to ratchet in.
        let shell = layout(width: 1_200, sidebar: 260, detail: 620)
        let drag = shell.drag(.sidebar)

        #expect(drag.start == 260)
        #expect(shell.shown == PanelWidths(sidebar: 260, detail: 548))

        var width = drag.start
        for dx in Self.outAndBack {
            width = drag.width(movedBy: dx)
        }
        #expect(width == drag.start)

        // Every frame in between tracked the hand rather than sticking.
        #expect(drag.width(movedBy: -10) == 250)
        #expect(drag.width(movedBy: -50) == 210)
        #expect(drag.width(movedBy: -30) == 230)
    }

    @Test("Reading the layout back mid-drag is what ratcheted it")
    func aLayoutRebuiltEachFrameDrifts() {
        // Why ``PanelLayout/Drag`` freezes the row, kept as a test because the
        // bug is invisible in the arithmetic and obvious here. The sidebar's
        // ceiling is the room column 3 leaves; column 3 is re-fitted wider
        // every time the sidebar narrows; so a layout rebuilt from the width
        // the drag has already produced hands the next frame a lower ceiling
        // than the last, and the hand cannot bring the panel back.
        var widths = PanelWidths(sidebar: 260, detail: 620)
        let start = layout(width: 1_200, sidebar: widths.sidebar, detail: widths.detail).dragStart(.sidebar)

        for dx in Self.outAndBack {
            let live = layout(width: 1_200, sidebar: widths.sidebar, detail: widths.detail)
            widths.sidebar = live.dragged(.sidebar, from: start, by: dx)
        }

        // It never came home — and this is the number that used to be saved,
        // overwriting the 260 that was on disk.
        #expect(widths.sidebar < start)
        #expect(widths.sidebar == 210)
    }

    @Test("A drag stops at the spec's bounds")
    func draggingClampsToTheBounds() {
        let roomy = layout(width: 2_000, sidebar: 260, detail: 420)

        #expect(roomy.dragged(.sidebar, from: 260, by: 4_000) == 420)
        #expect(roomy.dragged(.sidebar, from: 260, by: -4_000) == 196)
        #expect(roomy.dragged(.detail, from: 420, by: -4_000) == 620)
        #expect(roomy.dragged(.detail, from: 420, by: 4_000) == 300)
    }

    @Test("A drag stops at the room the other panel leaves, before its own bound")
    func draggingClampsToTheRoomLeft() {
        // 1200 pt, sidebar at 420: 808 of room, 388 of it left for column 3.
        let tight = layout(width: 1_200, sidebar: 420, detail: 388)

        #expect(tight.dragged(.detail, from: 388, by: -400) == 388)
        // Narrow the sidebar and column 3 can have the difference.
        let narrower = layout(width: 1_200, sidebar: 260, detail: 388)
        #expect(narrower.dragged(.detail, from: 388, by: -400) == 548)
    }

    @Test("Neither panel can drag the day below its floor")
    func theDayKeepsItsFloorThroughAnyDrag() {
        let shell = layout(width: 1_200, sidebar: 420, detail: 620)
        let dragged = PanelWidths(
            sidebar: shell.dragged(.sidebar, from: shell.dragStart(.sidebar), by: 4_000),
            detail: shell.dragged(.detail, from: shell.dragStart(.detail), by: -4_000)
        )
        let after = layout(width: 1_200, sidebar: dragged.sidebar, detail: dragged.detail)

        #expect(after.dayWidth >= Self.dayMinimum)
    }
}
