import Foundation
import Testing

@testable import PrincipleCore

/// A defaults domain nobody else owns — the shipping app's suite is the one
/// thing these must never write to.
private final class TempSuite {
    let name = "com.danny.principle.tests.\(UUID().uuidString)"

    var defaults: UserDefaults { UserDefaults(suiteName: name)! }

    deinit { UserDefaults().removePersistentDomain(forName: name) }
}

@Suite("Panel widths")
struct PanelWidthsTests {
    // MARK: - 1. The bounds (#18)

    @Test("Nothing stored opens at the spec's two widths")
    func defaultsAreTheSpecWidths() {
        let suite = TempSuite()
        let widths = PanelWidths(defaults: suite.defaults)

        #expect(widths.sidebar == PanelWidths.sidebarDefault)
        #expect(widths.detail == PanelWidths.detailDefault)
        // The numbers the ticket names, kept here so a silent edit to either
        // one fails rather than ships.
        #expect(PanelWidths.detailDefault == 420)
        #expect(PanelWidths.sidebarLimits == 196...420)
        #expect(PanelWidths.detailLimits == 300...620)
    }

    @Test("A width outside its bounds is clamped, not refused")
    func settersClampToTheBounds() {
        var widths = PanelWidths(sidebar: 900, detail: 40)

        #expect(widths.sidebar == 420)
        #expect(widths.detail == 300)

        widths.sidebar = 12
        widths.detail = 5_000
        #expect(widths.sidebar == 196)
        #expect(widths.detail == 620)

        widths.sidebar = 301
        widths.detail = 517
        #expect(widths.sidebar == 301)
        #expect(widths.detail == 517)
    }

    @Test("Room the window does not have caps a drag short of the upper bound")
    func clampRespectsTheRoomLeft() {
        // Plenty of room: the bound is what stops it.
        #expect(PanelWidths.clamp(700, to: PanelWidths.detailLimits, room: 900) == 620)
        // Less room than the bound: the room stops it first.
        #expect(PanelWidths.clamp(700, to: PanelWidths.detailLimits, room: 480) == 480)
        // Room under the minimum never squeezes a panel below its floor — at
        // that width the panel is a drawer, not a squashed column.
        #expect(PanelWidths.clamp(700, to: PanelWidths.detailLimits, room: 120) == 300)
        #expect(PanelWidths.clamp(200, to: PanelWidths.sidebarLimits, room: 1_000) == 200)
    }

    // MARK: - 2. Fitting a window that shrank

    @Test("A window too narrow for both panels takes it out of column 3 first")
    func fittingGivesRoomBackFromTheDetailFirst() {
        let wide = PanelWidths(sidebar: 420, detail: 620)

        // Room for both: nothing moves.
        #expect(wide.fitted(into: 1_040) == wide)
        // 60 short: column 3 gives all of it back, the sidebar keeps its width.
        #expect(wide.fitted(into: 980) == PanelWidths(sidebar: 420, detail: 560))
        // Column 3 is already at its floor, so the sidebar starts giving.
        #expect(wide.fitted(into: 700) == PanelWidths(sidebar: 400, detail: 300))
        // Under both minimums nothing shrinks further — the drawers take over.
        #expect(wide.fitted(into: 200) == PanelWidths(sidebar: 196, detail: 300))
    }

    @Test("Fitting never widens a panel the person made narrow")
    func fittingOnlyEverShrinks() {
        let narrow = PanelWidths(sidebar: 200, detail: 320)
        #expect(narrow.fitted(into: 4_000) == narrow)
    }

    // MARK: - 3. Across launches (#18)

    @Test("Both widths survive a relaunch")
    func widthsRoundTripThroughDefaults() {
        let suite = TempSuite()
        var widths = PanelWidths(defaults: suite.defaults)
        widths.sidebar = 388
        widths.detail = 517
        widths.save(to: suite.defaults)

        // What the next launch reads.
        let reopened = PanelWidths(defaults: suite.defaults)
        #expect(reopened.sidebar == 388)
        #expect(reopened.detail == 517)
    }

    @Test("A stored width outside today's bounds is clamped on the way in")
    func storedRubbishIsClampedOnRead() {
        let suite = TempSuite()
        suite.defaults.set(1_200, forKey: PanelWidths.Key.sidebar)
        suite.defaults.set(11, forKey: PanelWidths.Key.detail)

        let widths = PanelWidths(defaults: suite.defaults)
        #expect(widths.sidebar == 420)
        #expect(widths.detail == 300)
    }

    @Test("A zero or missing key falls back to the default rather than to nothing")
    func zeroReadsAsUnset() {
        let suite = TempSuite()
        // `double(forKey:)` answers 0 for a key that was never written and for
        // a string that is not a number — both mean "unset", never a 0 pt panel.
        suite.defaults.set("wide please", forKey: PanelWidths.Key.sidebar)

        let widths = PanelWidths(defaults: suite.defaults)
        #expect(widths.sidebar == PanelWidths.sidebarDefault)
        #expect(widths.detail == PanelWidths.detailDefault)
    }

    @Test("The app's own defaults are what an unset key falls back to")
    func fallbackIsHonouredAndClamped() {
        let suite = TempSuite()
        let shell = PanelWidths(sidebar: 260, detail: 480)

        let widths = PanelWidths(defaults: suite.defaults, fallback: shell)
        #expect(widths.sidebar == 260)
        #expect(widths.detail == 480)

        // A stored width still wins over the fallback.
        suite.defaults.set(340, forKey: PanelWidths.Key.sidebar)
        #expect(PanelWidths(defaults: suite.defaults, fallback: shell).sidebar == 340)
    }

    @Test("No defaults at all still gives a usable pair of widths")
    func nilDefaultsAreSurvivable() {
        let widths = PanelWidths(defaults: nil)
        #expect(widths.sidebar == PanelWidths.sidebarDefault)
        #expect(widths.detail == PanelWidths.detailDefault)
        // Saving nowhere is a no-op rather than a crash.
        widths.save(to: nil)
    }
}
