import CoreGraphics
import Foundation
import Testing

@testable import PrincipleCore

/// The seam the divider bug lived in (#18): the arithmetic between a stored pair
/// of widths and the row that is actually drawn.
///
/// Eden's canvas gap is 8 pt and the day's floor is 360 pt; both are the shell's
/// numbers, passed in, so these read the way the running app does.
@Suite("Panel layout")
struct PanelLayoutTests {
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

    // MARK: - 1. What is left to share

    @Test("The room is the window less the margins, the gaps and the day's floor")
    func roomCountsEveryGap() {
        // `Self.gap` and `Self.dayMinimum` rather than the bare 8 and 360 they
        // hold, and not for readability: `#expect` takes each side of the `==`
        // apart to report it, and a right-hand side written only in integer
        // literals is typed on its own, where it defaults to `Int`. `1008 as
        // Int` never equals `1008.0 as CGFloat`, so the assertion fails while
        // printing two numbers that look identical. One CGFloat in the
        // expression settles the type of the whole of it.
        //
        // Two panels docked: two canvas margins and two divider gaps.
        #expect(layout(width: 1_400).room == 1_400 - Self.gap * 4 - Self.dayMinimum)
        // One docked, one a drawer: one gap fewer.
        #expect(layout(width: 1_000, docksDetail: false).room == 1_000 - Self.gap * 3 - Self.dayMinimum)
        #expect(
            layout(width: 880, docksSidebar: false, docksDetail: false).room
                == 880 - Self.gap * 2 - Self.dayMinimum
        )
    }

    @Test("At the width column 3 first docks, the defaults leave the day 388 pt")
    func theDayKeepsItsFloorAtTheBreakpoint() {
        // The number `DayMetric.dayColumnMinimum`'s comment claims. 360 is the
        // floor; what the defaults actually leave at 1100 is 28 pt more.
        #expect(layout(width: 1_100).dayWidth == 388)
        #expect(layout(width: 1_100).shown == PanelWidths(sidebar: 260, detail: 420))
    }

    // MARK: - 2. Drawn narrower, never overwritten

    @Test("A window too narrow for both stored widths draws them fitted")
    func shownFitsWithoutOverwriting() {
        let tight = layout(width: 1_200, sidebar: 420, detail: 620)

        #expect(tight.room == 808)
        // Column 3 gives the room back first.
        #expect(tight.shown == PanelWidths(sidebar: 420, detail: 388))
        // …and the stored pair is untouched by the fitting.
        #expect(tight.widths == PanelWidths(sidebar: 420, detail: 620))
    }

    @Test("Widen the window and the widths that were chosen come back")
    func shownReturnsWhenTheRoomDoes() {
        let widths = PanelWidths(sidebar: 420, detail: 620)
        let tight = layout(width: 1_200, sidebar: widths.sidebar, detail: widths.detail)
        let roomy = layout(width: 1_600, sidebar: widths.sidebar, detail: widths.detail)

        #expect(tight.shown.detail == 388)
        #expect(roomy.shown == widths)
    }

    @Test("A drawer overlays the day rather than taking width from it")
    func onlyDockedPanelsAreHeldToTheRoom() {
        // 900 pt: column 1 docks, column 3 is a drawer at whatever it was last
        // dragged to — the room does not touch it.
        let narrow = layout(width: 900, sidebar: 420, detail: 620, docksDetail: false)

        #expect(narrow.room == 516)
        #expect(narrow.shown.detail == 620)
        #expect(narrow.shown.sidebar == 420)
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
